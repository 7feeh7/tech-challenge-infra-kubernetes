# Rotas e rede (E07)

Entrada publica unica: o API Gateway (HTTP API) encaminha cada prefixo ao servico dono dele pelo VPC Link, que chega ao NLB interno. Cada servico tem **um listener TCP no NLB**, **um target group `instance`** e **uma NodePort**. O mapa fica em `terraform/rotas.tf` (`local.servicos_borda`), que e a fonte unica de portas e rotas.

## Mapa servico, listener, NodePort e rotas

| Servico | Listener do NLB | NodePort | Rotas no API Gateway |
| --- | --- | --- | --- |
| OS | `80` | `30080` | `ANY /v1/{proxy+}`, `OPTIONS /v1/{proxy+}`, `GET /health`, `GET /docs`, `GET /docs/{proxy+}` |
| Billing | `8081` | `30081` | `ANY /v1/orcamentos`, `ANY /v1/orcamentos/{proxy+}`, `ANY /v1/cobrancas`, `ANY /v1/cobrancas/{proxy+}`, `ANY /v1/pendencias-estorno`, `ANY /v1/pendencias-estorno/{proxy+}`, `POST /v1/webhooks/mercado-pago` |
| Execution | `8082` | `30082` | `ANY /v1/tarefas`, `ANY /v1/tarefas/{proxy+}` |
| auth-cpf (Lambda) | sem listener | sem NodePort | `POST /auth/cpf`, `OPTIONS /auth/cpf` |

- **Portas dos listeners novas:** `8081` e `8082` acompanham o fim da NodePort (30081, 30082), nao colidem com o `:80` do OS e nao exigem porta privilegiada.
- **Precedencia:** o API Gateway escolhe a rota mais especifica. `ANY /v1/orcamentos` e `ANY /v1/orcamentos/{proxy+}` vencem `ANY /v1/{proxy+}`, que continua levando o restante de `/v1/*` para o OS.
- **Webhook do Mercado Pago:** rota exata `POST /v1/webhooks/mercado-pago`, sem JWT. A protecao e a assinatura do Mercado Pago, validada pelo Billing.
- **`/internal` nunca e roteado.** Nenhuma rota do API Gateway publico aponta para `/internal/*`. Billing e Execution chamam o OS pelo `ClusterIP`; a `auth-cpf` chama pelo NLB (secao abaixo).
- **Rotas ativas desde o primeiro `apply`:** ate o servico ser implantado, o health check do target group falha e a rota responde erro de integracao.
- **Health check:** HTTP `/health` na NodePort do servico (Billing e Execution expoem `/health` e `/health/ready` na raiz, fora do prefixo global).
- **NLB sem security group (D6.4):** o NLB existente e mantido. Nada do OS muda: listener `:80`, target group `eks_nodes`, anexo ao ASG e rotas permanecem com os mesmos enderecos no state.

## Recursos por servico (Billing e Execution)

| Recurso | Arquivo |
| --- | --- |
| `aws_lb_target_group.servico`, `aws_lb_listener.servico`, `aws_autoscaling_attachment.servico` | `terraform/api-gateway.tf` |
| `aws_apigatewayv2_integration.servico` (`HTTP_PROXY`, mesmo VPC Link, aponta para o listener do servico), `aws_apigatewayv2_route.servico` | `terraform/api-gateway.tf` |
| `aws_security_group_rule.eks_nodes_nodeport_servico_ingress` (NodePort, origem na faixa da VPC) | `terraform/security-groups.tf` |

O nome do target group tem limite de 32 caracteres: `tech-challenge-producao-bill-tg` e `tech-challenge-producao-exec-tg` (campo `sufixo_target_group` do mapa).

## O que os servicos precisam expor

Para o target group ficar saudavel, o `Service` de cada servico precisa ser `type: NodePort` com `nodePort` fixo igual ao do mapa (Billing `30081`, Execution `30082`) e responder `GET /health` com 200 na porta do pod. Com `type: ClusterIP`, o health check falha e as rotas respondem erro de integracao.

## Saida da `auth-cpf`

A Function esta na VPC (subnets privadas) e so tem duas saidas no security group `lambda`:

| Destino | Porta | Para que |
| --- | --- | --- |
| Subnets privadas da VPC (onde vive o NLB) | TCP `80` (listener do OS) | `GET {OS_SERVICE_BASE_URL}/internal/clientes?cpf=` |
| `0.0.0.0/0` | TCP `443` | Secrets Manager e DynamoDB (rate limit) via NAT Gateway, sem VPC endpoints por custo |

- O NLB nao tem security group, entao a saida usa a CIDR das subnets em que ele vive (`module.vpc.private_subnets_cidr_blocks`), nao uma referencia a SG.
- A saida `5432` para o RDS foi removida: a `auth-cpf` nao acessa mais o banco.
- `OS_SERVICE_BASE_URL` vale `http://<dns do NLB>:80`, montado em `terraform/lambda.tf` a partir de `aws_lb.eks_internal.dns_name` e da porta do OS no mapa. Nao ha variavel de desligamento: sem a URL a Lambda responde 500.
- `JWT_ISSUER = tech-challenge-auth` e `JWT_AUDIENCE = tech-challenge-api` (defaults de `variables.tf`).

> O ingress `PostgreSQL from Lambda` do `aws_security_group.rds_access` e o export `lambda_security_group_id` (consumido pelo `infra-database`) continuam existindo, mas ficaram sem efeito: o SG `lambda` nao tem mais saida para a porta 5432. Remover os dois e uma melhoria opcional, que exige mudanca coordenada no `infra-database`.

### Rate limit por CPF

A role da `auth-cpf` (`-lambda-role`) precisa gravar na tabela `tech-challenge-producao-auth-cpf-rate`. Duas pecas, ambas so com a operacao que o codigo usa (`UpdateItem` em `cpf-rate-limit.service.ts` do `tech-challenge-serverless`):

| Peca | Onde | Conteudo |
| --- | --- | --- |
| Policy da role | `terraform/auth-security.tf` (`lambda_auth_rate_limit`) | `dynamodb:UpdateItem` no ARN exato da tabela, sem indice nem curinga |
| Teto da *boundary* workload | `terraform/bootstrap/permissions-boundaries.tf` (statement `DynamoDbAuthCpfRate`) | `dynamodb:UpdateItem` no ARN exato `table/<prefixo>-auth-cpf-rate`, separado de `DynamoDbExecution` |

A tabela usa criptografia com chave gerenciada pela AWS (sem CMK), entao a role nao precisa de permissao KMS. Como a *boundary* esta no root `terraform/bootstrap/`, ela precisa ser aplicada (runbook 1.3) antes do `apply` do stack principal; sem isso a policy da role fica sem efeito.

## Exports SSM

Prefixo `/tech-challenge/producao/infra/`. Os novos desta etapa:

| Parametro | Valor | Consumidor |
| --- | --- | --- |
| `api_gateway_id` | ID do HTTP API | troubleshooting e smoke da implantacao |
| `eks_node_group_asg_name` | ASG do node group gerenciado | troubleshooting (alvos dos target groups) |
| `eks_oidc_provider_arn` | ARN do provedor OIDC do EKS | troubleshooting e futuras IRSAs |

O NLB ja e coberto por `eks_nlb_dns_name`. Nenhum repositorio le esses tres parametros hoje. Todo parametro novo precisa entrar tambem em `infra_stack_ssm_parameter_names` de `terraform/bootstrap/github_infra_kubernetes_policy.tf`, senao o `apply` da CI recebe `AccessDenied`.

### Filas por convencao

As filas `os-in`, `billing-in`, `execution-in` e as DLQs **nao sao criadas aqui**: cada servico cria a sua e publica os parametros no proprio stack. Este repositorio so garante os ARNs das filas nas policies das IRSAs (`terraform/locals_iam.tf`, `sqs_queue_arns`), pela convencao de nome `<projeto>-<ambiente>-<servico>-in` e `...-in-dlq`.

| Parametro | Publicado por |
| --- | --- |
| `os_in_queue_url`, `os_in_dlq_url` | `tech-challenge` (E41) |
| `billing_in_queue_url`, `billing_in_queue_arn`, `billing_ecr_repository_url`, `mercado_pago_secret_arn` | `tech-challenge-billing` |
| `execution_in_queue_url`, `execution_in_queue_arn`, `execution_in_dlq_url`, `execution_ecr_repository_url` | `tech-challenge-execution` |

Nao duplique esses nomes em `terraform/ssm.tf`: dois `aws_ssm_parameter` com o mesmo nome em stacks diferentes disputam o mesmo recurso.
