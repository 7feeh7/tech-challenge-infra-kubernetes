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
| `lambda_artifacts_bucket` | serverless CI |

## Exports — infra-database

Prefixo: `/tech-challenge/producao/database/`

| Parametro | Consumidor |
| --- | --- |
| `db_secret_arn` | Lambda auth, tech-challenge CI |
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

Automacao existe em `develop` (validacao) e `main` (deploy). Apenas `main` provisiona. Ver [ADR-001](../../../tech-challenge/docs/adr/001-ambiente-unico-provisionado.md).
