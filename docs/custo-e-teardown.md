# Custo estimado e teardown

Documento de referencia operacional para o ambiente unico (`producao`) da Fase 3.

## Recursos que geram cobranca

| Recurso | Estimativa mensal (us-east-1) | Observacao |
| --- | --- | --- |
| EKS control plane | ~USD 73 | Fixo por cluster |
| EC2 nodes (2x t3.small) | ~USD 30–60 | Escala ate 4 nodes via Cluster Autoscaler |
| NAT Gateway | ~USD 32 + trafego | Single NAT (custo vs HA multi-AZ) |
| RDS (repo database) | ~USD 15–25 | db.t3.micro single-AZ |
| API Gateway + NLB | ~USD 20–40 | Depende de volume de requisicoes |
| Lambda + SQS/SNS | ~USD 1–5 | Uso academico baixo |
| ECR + S3 artefatos | ~USD 1–3 | Lifecycle limita imagens antigas |
| CloudWatch Logs | ~USD 5–15 | Retencao configurada por servico |
| Secrets Manager | ~USD 1 | Por secret ativo |

**Total estimado:** USD 180–250/mes com carga academica moderada. Valores variam com trafego, duracao de nodes extras e retencao de logs.

## Preservar antes de destruir

1. Exportar outputs SSM ou anotar ARNs usados por integracao externa (SendGrid, dominio).
2. Backup final do RDS (`tech-challenge-infra-database`) se houver dados a manter.
3. Confirmar que nenhum deploy concorrente esta em execucao (concurrency groups dos workflows).

## Ordem de teardown (inversa ao provisionamento)

Execute **somente** via `workflow_dispatch` com action `destroy` em cada repositorio — nunca por push.

| Ordem | Repositorio | Acao |
| --- | --- | --- |
| 1 | `tech-challenge` | Remover workloads (`kubectl delete namespace oficina`) ou deixar o cluster vazio |
| 2 | `tech-challenge-serverless` | Nenhum destroy Terraform; Functions sao removidas com infra-kubernetes |
| 3 | `tech-challenge-infra-database` | `workflow_dispatch` destroy |
| 4 | `tech-challenge-infra-kubernetes` | `workflow_dispatch` destroy (EKS, VPC, ECR, Lambda, mensageria) |

Apos destroy do kubernetes, o bucket de state S3 e a tabela DynamoDB de lock **permanecem** (pre-requisitos externos). Remova-os manualmente somente se nao houver mais nenhum ambiente.

## Acesso operacional ao cluster

Credenciais nunca sao versionadas. Use:

```bash
aws eks update-kubeconfig --region us-east-1 --name tech-challenge-producao-eks
```

Requer IAM com permissao `eks:DescribeCluster` e entrada no `aws-auth`/access entry do cluster.
