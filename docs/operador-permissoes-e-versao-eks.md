# Operador, permissoes de CI e versao do EKS

Complemento da E36 (revisao do runbook de implantacao). Nenhum valor real fica no repositorio: so nomes de variaveis.

## Operador do cluster

O operador (autor) administra o cluster e grava segredos com a propria credencial. O Terraform nao cria esse principal: o ARN entra pela variavel `operador_principal_arn` (sem valor padrao).

| Origem | Nome | Observacao |
| --- | --- | --- |
| GitHub Variable (nao secret) | `OPERADOR_PRINCIPAL_ARN` | Passada pelo `deploy.yml` em `plan` e `destroy` |
| Variavel Terraform | `operador_principal_arn` | ARN de usuario ou role IAM (`arn:aws:iam::<conta>:user/<nome>` ou `:role/<nome>`) |

Efeito em `terraform/eks.tf`:

- *access entry* `operador` com `AmazonEKSClusterAdminPolicy` em escopo de cluster;
- administrador da chave KMS do cluster, junto com a role de CI do `infra-kubernetes`.

Variable ausente ou fora do formato: o `plan` falha na validacao da variavel, antes de criar qualquer recurso, para nunca existir cluster sem operador. Nenhuma role de CI recebe `PutSecretValue` nos segredos de chave JWT, tokens e Mercado Pago; o operador grava esses valores. Por isso a credencial do bootstrap so deve ser revogada depois de 4.1 e 7.2 do runbook.

O codigo nao referencia mais `user/github-actions`, usuario que nenhum Terraform cria.

## Remetente do Resend

| Origem | Nome |
| --- | --- |
| GitHub Variable | `RESEND_FROM_EMAIL` |
| Variavel Terraform | `resend_from_email` (sem valor padrao) |

A validacao recusa valor ausente, e-mail malformado e o dominio de exemplo `seu-dominio.com`. O Resend exige dominio verificado no painel do Resend para enviar a qualquer destinatario; sem dominio, `onboarding@resend.dev` so entrega no e-mail do dono da conta.

## Backend de state e `s3:ListBucket`

O backend S3 do Terraform lista o prefixo de workspaces (`env:/`, valor padrao de `workspace_key_prefix`) em todo `init` e `plan`, mesmo sem workspaces. As roles de CI com state (OS, Billing, Execution, `infra-kubernetes` e `infra-database`) aceitam, alem de `<repositorio>/<ambiente>/`, os prefixos `env:/` e `env:/*` em `s3:ListBucket`. Leitura e escrita de objeto continuam restritas ao prefixo do proprio repositorio, e o state do bootstrap segue negado. Definido em `terraform/bootstrap/ci_terraform_state.tf`.

## Permissoes do CI do `infra-kubernetes`

Em `terraform/bootstrap/github_infra_kubernetes_policy.tf`, cada acao existe por causa de um recurso do root:

| Recurso do root | Acoes acrescentadas | Escopo |
| --- | --- | --- |
| `module.eks` (policy `ClusterEncryption`) | `iam:CreatePolicy`, `DeletePolicy`, `CreatePolicyVersion`, `DeletePolicyVersion`, `TagPolicy`, `UntagPolicy`, `ListPolicyTags`; `iam:AttachRolePolicy` e `DetachRolePolicy` | Policy `<cluster>-ClusterEncryption*`; anexo so na role do cluster, com a boundary plataforma e `iam:PolicyARN` da policy |
| `aws_s3_bucket` e filhos (`s3.tf`) | `CreateBucket`, `DeleteBucket`, versionamento, criptografia, *public access block*, tags e leituras do *refresh* do provider | ARN do bucket de artefatos |
| `aws_s3_object` (placeholders) | `GetObjectVersion`, `DeleteObjectVersion`, tags de objeto | Objetos do bucket de artefatos |
| `aws_dynamodb_table` | `DescribeTimeToLive`, `DescribeContinuousBackups`, `UpdateContinuousBackups` | Tabela de rate limit |
| `aws_ecr_repository` e lifecycle | `ListTagsForResource`, `GetLifecyclePolicy`, `DeleteLifecyclePolicy`, `UntagResource` | Repositorio do root |
| `aws_lambda_function` e permissao do API Gateway | `PutFunctionConcurrency`, `GetFunctionConcurrency`, `DeleteFunctionConcurrency`, `GetPolicy`, leituras de versoes, *code signing* e recursao | As duas funcoes do root |
| `aws_lambda_event_source_mapping` | `Create` e `UpdateEventSourceMapping` com condicao `lambda:FunctionArn` da funcao de notificacao; `Get` e `DeleteEventSourceMapping`; `ListEventSourceMappings` | `event-source-mapping:*` (o IAM exige `*` na listagem) |
| `aws_sns_topic_subscription` | `GetSubscriptionAttributes`, `SetSubscriptionAttributes`, `Unsubscribe` | ARN `<topico>:*` (o ARN da assinatura nao e o do topico) |

Acoes marcadas como provaveis (comportamento do provider AWS) devem ser confirmadas no primeiro `plan` e `apply` da E37; um `AccessDenied` no CloudTrail para a role `...-github-infra-k8s` lista o que faltar.

## Versao do Kubernetes (EKS)

- Versao: `1.37` (`kubernetes_version`). Suporte padrao ate 2027-12-01 e estendido ate 2028-12-01, segundo a documentacao publica do EKS (calendario de versoes). Confirmar antes de criar o cluster: `aws eks describe-cluster-versions`.
- O modulo `terraform-aws-modules/eks` (`~> 20.8`, lock em 20.37.2) repassa a versao ao `aws_eks_cluster` sem lista fixa de versoes.
- Nos: `ami_type = "AL2023_x86_64_STANDARD"`. O EKS nao publica AMI Amazon Linux 2 a partir do 1.34.
- *Add-ons*: o root nao declara `cluster_addons`; vpc-cni, kube-proxy e CoreDNS vem do EKS na versao padrao da minor.
- Cluster Autoscaler: chart `9.60.0` (`appVersion` 1.37.0), que casa com a minor do cluster. Ao trocar `kubernetes_version`, troque o chart por um cujo `appVersion` tenha a mesma minor.
- Chart de `eks.tf`: `metrics-server` `3.12.1`, sem dependencia da minor do Kubernetes.
- Politica de upgrade do cluster fica no padrao da AWS (`EXTENDED`): ao sair do suporte padrao, a AWS passa a cobrar o suporte estendido.
