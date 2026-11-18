# Segredos RS256 e tokens por relacao (E08)

Conteineres no Secrets Manager provisionados pelo stack `terraform/` do `tech-challenge-infra-kubernetes`. **Nenhum valor sensivel e gravado pelo Terraform**; o autor preenche na implantacao (runbook fase 4.1).

## Conteineres

| Caminho (prefixo) | JSON esperado (`put-secret-value`) | Quem le (IAM) |
| --- | --- | --- |
| `tech-challenge/producao/jwt-private-*` | `{"privateKey":"<PEM RSA privada, \\n escapados>"}` | CI do OS, role de execucao `auth-cpf` |
| `tech-challenge/producao/jwt-public-*` | `{"publicKey":"<PEM publica>"}` | CI do OS, Billing e Execution |
| `tech-challenge/producao/token-billing-os-*` | `{"token":"<valor base64 ou hex>"}` | CI do Billing e do OS |
| `tech-challenge/producao/token-execution-os-*` | `{"token":"<valor>"}` | CI do Execution e do OS |
| `tech-challenge/producao/token-auth-cpf-os-*` | `{"token":"<valor>"}` | Role `auth-cpf` e CI do OS |

Chaves alternativas aceitas pelos pipelines atuais (ate E14/E34): `public_key`, `private_key`, token em string pura se o JSON nao tiver campo `token`.

## Parametros SSM publicados

Prefixo: `/tech-challenge/producao/infra/`

| Parametro | Finalidade | Consumidores (workflow / runtime) |
| --- | --- | --- |
| `jwt_secret_arn` | ARN da chave **privada** RS256 (nome legado para o OS) | `tech-challenge` deploy/migrate, `serverless` via env da Function |
| `jwt_public_secret_arn` | ARN da chave publica | `tech-challenge-billing` deploy/migrate |
| `token_billing_os_secret_arn` | Token `billing-os` | `tech-challenge-billing` deploy/migrate |
| `token_execution_os_secret_arn` | Token `execution-os` | `tech-challenge-execution` deploy (previsto E25) |
| `token_auth_cpf_os_secret_arn` | Token `auth-cpf-os` | Lambda `auth-cpf` (`AUTH_CPF_OS_TOKEN_ARN`); OS em E14 |

### Parametros consumidos pelo Billing fora do escopo da E08

| Parametro | Etapa responsavel |
| --- | --- |
| `/tech-challenge/producao/database/billing_db_secret_arn` | E09 (`tech-challenge-infra-database`) |
| `/tech-challenge/producao/infra/os_in_queue_url` | E41 (`tech-challenge`) |
| `/tech-challenge/producao/infra/mercado_pago_secret_arn` | Billing / E05 (contêiner no stack do Billing) |

## Gerar e gravar (runbook 4.1)

```bash
# Par RS256
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out jwt-priv.pem
openssl pkey -in jwt-priv.pem -pubout -out jwt-pub.pem

# Tokens por relacao (um comando por relacao)
openssl rand -base64 48   # billing-os
openssl rand -base64 48   # execution-os
openssl rand -base64 48   # auth-cpf-os

# Resolver ARNs via SSM (exemplo)
PREFIX=/tech-challenge/producao
PRIV_ARN=$(aws ssm get-parameter --name "${PREFIX}/infra/jwt_secret_arn" --query Parameter.Value --output text)
PUB_ARN=$(aws ssm get-parameter --name "${PREFIX}/infra/jwt_public_secret_arn" --query Parameter.Value --output text)

# Gravar (ajustar jq conforme o PEM)
jq -Rs '{privateKey: .}' jwt-priv.pem | aws secretsmanager put-secret-value --secret-id "$PRIV_ARN" --secret-string file:///dev/stdin
jq -Rs '{publicKey: .}' jwt-pub.pem | aws secretsmanager put-secret-value --secret-id "$PUB_ARN" --secret-string file:///dev/stdin

# Apagar arquivos locais depois
shred -u jwt-priv.pem jwt-pub.pem 2>/dev/null || rm -f jwt-priv.pem jwt-pub.pem
```

Repita `put-secret-value` para cada ARN `token_*` com `{"token":"<valor gerado>"}`.

## Token de teste (validacao isolada)

Script local (nao usa segredos do ambiente provisionado por padrao):

```bash
node scripts/token-teste.mjs --private-key jwt-priv.pem --issuer tech-challenge-auth --audience tech-challenge-api
```

Use uma chave descartavel; rotacione o par usado em producao em E39 se o teste tiver sido feito com chaves reais.

## IRSA

Nenhuma IRSA de aplicacao le Secrets Manager (D6.5). Somente pipelines (roles `github-*`) e a role de execucao da Lambda `auth-cpf`.

## CI do infra-kubernetes

A role de CI do `infra-kubernetes` so gerencia os conteineres de `jwt-*`, `token-*` e `sendgrid-*` (criar, descrever, etiquetar, excluir) e nao tem `GetSecretValue`, `PutSecretValue` nem `PutResourcePolicy` neles. Leitura e gravacao de valor ficam so no `sendgrid-*`, que o Terraform grava (`aws_secretsmanager_secret_version.sendgrid_api_key`).