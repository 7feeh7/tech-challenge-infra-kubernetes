# Contratos cross-repo

Integracao entre os quatro repositorios via **SSM Parameter Store** e **Secrets Manager**.

## Ambiente provisionado

Esta entrega opera **um unico ambiente** (`producao`). O prefixo SSM permanece parametrizado para permitir um segundo ambiente no futuro:

```
/tech-challenge/producao/infra/*
/tech-challenge/producao/database/*
```

Nenhum parametro de `homologacao` e escrito ou consumido.

## Ordem de provisionamento

```text
1. tech-challenge-infra-kubernetes   VPC, EKS, ECR, Lambda shell, S3, SSM infra/*
2. tech-challenge-infra-database     RDS, Secrets Manager, SSM database/*
3. tech-challenge-serverless         ZIP → S3 → update-function-code
4. tech-challenge                    Imagem → ECR → kubectl apply k8s/
```

Deploy ocorre **apenas** em push/merge em `main` de cada repositorio.

## Exports — infra-kubernetes

Prefixo: `/tech-challenge/producao/infra/`

| Parametro | Consumidor |
| --- | --- |
| `vpc_id` | infra-database |
| `private_subnet_ids` | infra-database |
| `lambda_security_group_id` | infra-database |
| `rds_access_security_group_id` | infra-database |
| `eks_cluster_name` | tech-challenge CI |
| `ecr_repository_url` | tech-challenge CI |
| `lambda_auth_function_name` | serverless CI, infra-database |
| `lambda_notificacao_function_name` | serverless CI |
| `lambda_artifacts_bucket` | serverless CI |
| `sns_notificacao_topic_arn` | tech-challenge CI |
| `api_notificacao_irsa_role_arn` | tech-challenge CI |
| `jwt_secret_arn` | OS CI (chave privada RS256), Lambda `auth-cpf` |
| `jwt_public_secret_arn` | Billing, Execution e OS CI |
| `token_billing_os_secret_arn` | Billing e OS CI |
| `token_execution_os_secret_arn` | Execution e OS CI |
| `token_auth_cpf_os_secret_arn` | Lambda `auth-cpf` e OS CI |
| `api_gateway_id` | troubleshooting e smoke da implantacao (E07) |
| `eks_nlb_dns_name` | Lambda `auth-cpf` (`OS_SERVICE_BASE_URL`, montada no proprio stack), troubleshooting |
| `eks_node_group_asg_name` | troubleshooting (E07) |
| `eks_oidc_provider_arn` | troubleshooting e futuras IRSAs (E07) |
| `resend_secret_arn` | troubleshooting |
| `sqs_notificacao_queue_url` | troubleshooting |
| `sqs_notificacao_dlq_url` | troubleshooting DLQ |

As filas `os-in`, `billing-in`, `execution-in` e as DLQs nao sao exports deste repositorio: cada servico publica os proprios parametros (`os_in_queue_url`, `billing_in_queue_url`, `execution_in_queue_url` e DLQs) em `/tech-challenge/producao/infra/`, pela convencao de nome `<projeto>-<ambiente>-<servico>-in`. Mapa de rotas, portas e a lista completa em [rotas-e-rede.md](rotas-e-rede.md).

## Exports — infra-database

Prefixo: `/tech-challenge/producao/database/`

| Parametro | Consumidor |
| --- | --- |
| `db_secret_arn` | tech-challenge CI (usuario `oficina`); a Lambda `auth-cpf` nao consome segredo PostgreSQL |
| `billing_db_secret_arn` | tech-challenge-billing CI (usuario `billing`) |
| `master_db_secret_arn` | so o workflow do Job administrativo (`db-admin-job.yml` do infra-database); nenhum microsservico, Lambda ou CI de aplicacao |
| `rds_endpoint` | troubleshooting |

## State Terraform

| Repositorio | State key (unico) |
| --- | --- |
| infra-kubernetes | `tech-challenge-infra-kubernetes/producao/terraform.tfstate` |
| infra-database | `tech-challenge-infra-database/producao/terraform.tfstate` |

Chaves de homologacao nao sao usadas. Se existirem no bucket, remova com `terraform destroy` + exclusao manual do state.

## Artefatos imutaveis

| Artefato | Formato |
| --- | --- |
| Imagem Docker | `{ecr_url}:{git_sha}` |
| ZIP Lambda | `s3://{bucket}/lambda-auth-cpf/{git_sha}.zip` |

## Desvio R-12

Automacao existe em `develop` (validacao) e `main` (deploy). Apenas `main` provisiona. Ver [ADR-001](../../../tech-challenge/docs/adrs/001-ambiente-unico-provisionado.md).
