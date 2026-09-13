# tech-challenge-infra-kubernetes

Infraestrutura de computacao e borda da oficina mecanica: VPC, EKS, ECR, Functions (shell), bucket de artefatos e parametros SSM para integracao cross-repo.

## Responsabilidade

| Recurso | Descricao |
| --- | --- |
| VPC + subnets | Rede privada/publica para EKS, Lambda e RDS |
| EKS + metrics-server | Cluster Kubernetes da API NestJS |
| ECR | Registro de imagens Docker da aplicacao |
| Lambda (shell) | Functions provisionadas; codigo vem de `tech-challenge-serverless` |
| S3 | Artefatos ZIP das Functions |
| SSM | Exports consumidos pelos demais repositorios |

## Relacao com outros repositorios

| Repositorio | Integracao |
| --- | --- |
| `tech-challenge-infra-database` | Le VPC/subnets/SG via SSM; publica credenciais do RDS |
| `tech-challenge-serverless` | Faz upload de ZIP no S3 e atualiza codigo das Functions |
| `tech-challenge` | Le ECR/EKS via SSM no deploy; aplica manifests `k8s/` |

## Ordem de provisionamento

1. **tech-challenge-serverless** — build inicial (opcional antes do k8s)
2. **tech-challenge-infra-kubernetes** (este repo)
3. **tech-challenge-infra-database**
4. **tech-challenge** — deploy da aplicacao

## Estrutura

```text
terraform/          Modulos Terraform
.github/workflows/  pr-validation (develop/PR) + deploy (main only)
docs/               Contratos e ADR
```

## Pre-requisitos

- Terraform >= 1.5
- AWS CLI configurado
- Bucket S3 + DynamoDB para state remoto
- GitHub Environment `producao` (secrets de nuvem; deployment branch policy = `main` only)

> **Ambiente único (001-R1):** não existe ambiente de homologação provisionado. `develop` executa apenas validação.

## Contratos SSM exportados

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

Detalhes em [`docs/contratos-cross-repo.md`](docs/contratos-cross-repo.md).

## GitHub Secrets (Environment `producao`)

| Secret | Uso |
| --- | --- |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Deploy Terraform |
| `TF_STATE_BUCKET` | Backend S3 |
| `TF_STATE_LOCK_TABLE` | Lock DynamoDB |
| `JWT_SECRET` | Env da Lambda auth |
| `DB_SECRET_ARN` | Opcional; preenchido apos database |
| `LAMBDA_ARTIFACTS_BUCKET` | Nome do bucket S3 de artefatos |

`SONAR_TOKEN` e similares ficam no nivel de repositorio, se aplicavel.

## Branches e pipelines

| Branch | Workflow | Toca AWS |
| --- | --- | --- |
| `develop` | `pr-validation.yml` | **nao** |
| PR → `main` | `pr-validation.yml` | **nao** |
| `main` | `deploy.yml` | **sim** |

State S3 key: `tech-challenge-infra-kubernetes/producao/terraform.tfstate`

## Rollback

1. Reverta o commit no GitHub e faca merge na branch alvo.
2. O workflow `deploy.yml` aplicara o state anterior via Terraform.
3. Para destroy controlado, use `workflow_dispatch` com action `destroy`.

## Licenca

Projeto academico FIAP — uso interno da entrega.
