# tech-challenge-infra-kubernetes

Infraestrutura de computação e borda da oficina mecânica na AWS: VPC, EKS, API Gateway, NLB interno, Lambdas, mensageria de notificação, segredos, observabilidade e parâmetros SSM. Projeto do Tech Challenge (FIAP).

Na **Fase 4** este repositório provisiona a base compartilhada que hospeda os três microsserviços (OS, Billing e Execution) em namespaces separados do mesmo cluster EKS. O ECR do OS é criado aqui; Billing e Execution criam no próprio repositório a fila SQS, o ECR e o banco, e o OS cria a fila `os-in`.

## Tecnologias

| Tecnologia                | Uso                                                    |
| ------------------------- | ------------------------------------------------------ |
| Terraform >= 1.5          | Toda a infraestrutura (estado remoto em S3 com lock)   |
| AWS (us-east-1)           | VPC, EKS, API Gateway, NLB, Lambda, SNS, SQS, SSM      |
| Kubernetes (EKS)          | Cluster, namespaces, IRSA, metrics-server e autoscaler |
| Datadog (provider e Helm) | Agent no cluster, dashboards e monitores               |
| GitHub Actions            | Validação em PR e deploy na `main`                     |

## Arquitetura

- **Cluster:** EKS (`eks.tf`) com os namespaces `oficina`, `billing` e `execution`, além de `administracao`, que abriga o Job administrativo do banco (`namespaces.tf`), IRSA por serviço (`irsa.tf`) e Cluster Autoscaler (`cluster-autoscaler.tf`). Não há `NetworkPolicy`: o isolamento entre serviços vem de namespace, IAM/IRSA e credenciais e banco próprios.
- **Borda:** API Gateway HTTP API com VPC Link para um NLB interno, com um listener e uma NodePort por serviço (`api-gateway.tf`, `rotas.tf`). `ANY /v1/{proxy+}` vai para o OS; `/v1/orcamentos*`, `/v1/cobrancas*`, `/v1/pendencias-estorno*` e `POST /v1/webhooks/mercado-pago` para o Billing; `/v1/tarefas*` para o Execution; `POST /auth/cpf` para a Lambda de autenticação. As rotas `/internal/*` não são expostas.
- **ECR:** repositório de imagens do OS (`ecr.tf`, URL exportada no SSM como `ecr_repository_url`).
- **Lambdas:** `auth-cpf` e `notificacao` são provisionadas aqui (`lambda.tf`); o código está em `tech-challenge-serverless`.
- **Mensageria de notificação:** o OS publica no tópico SNS `notificacao-status`, que alimenta a fila SQS `notificacao-status` (com DLQ) consumida pela Lambda de notificação, que envia o e-mail pelo Resend (`messaging.tf`). O SNS não participa da orquestração da SAGA.
- **SAGA:** as filas da SAGA (`os-in`, `billing-in`, `execution-in`) não ficam aqui. Cada serviço as cria no próprio `terraform/`.
- **Segredos e SSM:** chaves JWT, tokens entre serviços e segredo do Resend ficam no Secrets Manager (`secrets.tf`). Os parâmetros em `/tech-challenge/producao/infra/*` (`ssm.tf`) alimentam os demais repositórios.
- **Observabilidade:** Datadog Agent via `helm_release` (`datadog.tf`), dashboard e monitores da SAGA (`datadog-dashboard-saga.tf`, `datadog-monitors-saga.tf`), logs do API Gateway e das Lambdas e alarmes das filas de notificação no CloudWatch (`cloudwatch-alarms.tf`). O `correlationId` é propagado em HTTP e mensagens.

| Fora deste repositório                                 | Onde fica                       |
| ------------------------------------------------------ | ------------------------------- |
| Código das Lambdas                                     | `tech-challenge-serverless`     |
| RDS PostgreSQL (databases `oficina` e `billing`)       | `tech-challenge-infra-database` |
| Manifests e fila `os-in` do OS (o ECR do OS fica aqui) | `tech-challenge-oficina`        |
| Manifests, ECR, fila e banco do Billing                | `tech-challenge-billing`        |
| Manifests, ECR, fila e DynamoDB do Execution           | `tech-challenge-execution`      |

**Ordem de provisionamento:** infra-kubernetes (1º), infra-database, serverless e, por último, os serviços.

## Execução e desenvolvimento

Pré-requisitos: Terraform >= 1.5 e AWS CLI. O estado remoto exige bucket S3 e tabela DynamoDB de lock; o deploy usa o GitHub Environment `producao`, restrito à branch `main`.

Validação local, a mesma do CI (`pr-validation.yml`), sem tocar a AWS:

```bash
cd terraform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

O CI roda também TruffleHog, tfsec e Checkov (`.checkov.yml`).

Fluxo de deploy:

- `develop` e PR para a `main` só validam; nada toca a AWS.
- Na `main`, o `deploy.yml` roda `terraform plan` e `apply` quando há mudança em `terraform/**`.
- `destroy` só existe por `workflow_dispatch`, com confirmação explícita digitada. Ordem segura e custos em [`docs/custo-e-teardown.md`](docs/custo-e-teardown.md).
- Reverter é um commit de revert na `main`: o workflow aplica o estado anterior.

Configuração do CI (nomes, sem valores):

- Secrets do Environment `producao`: `AWS_DEPLOY_ROLE_ARN`, `TF_STATE_BUCKET`, `TF_STATE_LOCK_TABLE`, `LAMBDA_ARTIFACTS_BUCKET`, `RESEND_API_KEY`, `DATADOG_API_KEY` e `DATADOG_APP_KEY`.
- Variables do repositório: `OPERADOR_PRINCIPAL_ARN` e `RESEND_FROM_EMAIL`. Detalhes em [`docs/operador-permissoes-e-versao-eks.md`](docs/operador-permissoes-e-versao-eks.md).

O diretório `terraform/bootstrap/` cria o provedor OIDC do GitHub, as roles de CI de cada repositório e os permissions boundaries. O script `scripts/token-teste.mjs` emite um JWT RS256 de curta duração para validação isolada.

## Documentação

- Rotas, listeners e NodePorts por serviço: [`docs/rotas-e-rede.md`](docs/rotas-e-rede.md)
- Contratos SSM e Secrets Manager entre repositórios: [`docs/contratos-cross-repo.md`](docs/contratos-cross-repo.md)
- Observabilidade (Datadog): [`docs/observabilidade.md`](docs/observabilidade.md)
- Segredos JWT RS256 e fronteira de confiança: [`docs/segredos-rs256.md`](docs/segredos-rs256.md)
- Operador, permissões e versão do EKS: [`docs/operador-permissoes-e-versao-eks.md`](docs/operador-permissoes-e-versao-eks.md)
- Custo e teardown: [`docs/custo-e-teardown.md`](docs/custo-e-teardown.md)
- Contribuição: [`CONTRIBUTING.md`](CONTRIBUTING.md)

Repositórios relacionados, todos em `github.com/7feeh7/<repositório>`: `tech-challenge-oficina` (OS Service), `tech-challenge-billing`, `tech-challenge-execution`, `tech-challenge-infra-database` e `tech-challenge-serverless`.
