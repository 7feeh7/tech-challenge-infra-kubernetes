# Observabilidade (Datadog)

Monitores, metricas de log, pipeline de logs e dashboards da Saga da OS (E35, decisao D7.3). Tudo e Terraform deste repositorio e so existe quando `datadog_app_key` esta preenchida. Nenhuma ferramenta nova: o Billing e o Execution nao emitem metricas DogStatsD, e o Billing nao usa APM.

| Arquivo | Conteudo |
| --- | --- |
| `terraform/datadog-monitors.tf` | Monitores existentes; os de fila (`sqs_backlog`, `sqs_age`, `sqs_dlq`) por servico |
| `terraform/datadog-monitors-saga.tf` | Monitores novos da Saga da OS |
| `terraform/datadog-logs.tf` | Pipeline de logs e metricas de log do Billing |
| `terraform/datadog-dashboard-saga.tf` | Dashboard "Saga da OS" |
| `terraform/datadog-dashboards.tf` | Dashboards existentes (o de OS mostra os sete status com duracao) |

Todos os monitores notificam `var.datadog_alert_recipients`. Os limites sao variaveis `alarm_*` (`terraform/variables.tf`, exemplo em `terraform/terraform.tfvars.example`).

## Monitores de fila por servico

Um monitor de backlog, um de idade e um de DLQ para cada fila, com `for_each` em `local.filas_monitoradas`. As metricas `aws.sqs.*` vem da integracao AWS do Datadog (tag `queuename`), que nao e gerenciada neste repositorio: ela precisa coletar o namespace SQS da conta.

| Servico | Fila | DLQ |
| --- | --- | --- |
| notificacao | `<projeto>-<ambiente>-notificacao-status` | `...-notificacao-status-dlq` |
| os | `<projeto>-<ambiente>-os-in` | `...-os-in-dlq` |
| billing | `<projeto>-<ambiente>-billing-in` | `...-billing-in-dlq` |
| execution | `<projeto>-<ambiente>-execution-in` | `...-execution-in-dlq` |

| Monitor | Consulta | Limite (variavel, padrao) | Sem dado |
| --- | --- | --- | --- |
| Backlog SQS `<servico>` | `avg(last_5m)` de `aws.sqs.approximate_number_of_messages_visible` da fila | `alarm_sqs_backlog_count`, 100 (aviso em 50%) | nao alerta |
| Idade SQS `<servico>` | `avg(last_5m)` de `aws.sqs.approximate_age_of_oldest_message` da fila | `alarm_sqs_age_seconds`, 300 (aviso em 50%) | nao alerta |
| Mensagens na DLQ `<servico>` | `avg(last_5m)` de `aws.sqs.approximate_number_of_messages_visible` da DLQ | acima de 0 | nao alerta |

Os mesmos limites valem para os quatro servicos. O estado dos monitores da notificacao foi preservado com blocos `moved` em `terraform/moved.tf` (`[0]` para `["notificacao"]`).

## Monitores novos

Falha tecnica e resultado de negocio ficam separados: nenhum monitor conta recusa de pagamento, 4xx do Mercado Pago ou OS cancelada.

| Monitor | Tipo | Consulta | Limite (variavel, padrao) | Sem dado |
| --- | --- | --- | --- | --- |
| Outbox atrasada OS | tecnico | `max(last_5m)` de `oficina.outbox.idade_mais_antiga_segundos{environment}` | `alarm_outbox_idade_segundos`, 600 (aviso em 50%) | nao alerta: o gauge so sai com o publicador ligado |
| Falhas de publicacao da outbox OS | tecnico | `sum(last_10m)` de `oficina.outbox.publicacao_falha{environment}` | `alarm_outbox_publicacao_falha_count`, 5 (aviso em 50%) | nao alerta |
| Erros transitorios de consumo OS | tecnico | `sum(last_10m)` de `oficina.mensagem.erro_consumo{environment,tipo:transitorio}` | `alarm_consumo_erro_transitorio_count`, 10 (aviso em 50%) | nao alerta |
| Erros permanentes de consumo OS | tecnico | `sum(last_10m)` de `oficina.mensagem.erro_consumo{environment,tipo:permanente}` | `alarm_consumo_erro_permanente_count`, 0 | nao alerta |
| OS parada em `<status>` (sete monitores) | tecnico/negocio | `max(last_5m)` de `oficina.ordem_servico.idade_mais_antiga_segundos{environment,status:<status>}` | `alarm_os_parada_segundos` por status (tabela abaixo) | **alerta** apos `alarm_os_parada_sem_dado_minutos`, 15 |
| Situacao financeira indeterminada OS | negocio | `sum(last_30m)` de `oficina.situacao_financeira.indeterminada{environment}` | `alarm_situacao_financeira_indeterminada_count`, 0 | nao alerta |
| Situacao financeira indeterminada Billing situacao | negocio | `sum(last_30m)` de `billing.situacao_financeira_indeterminada{*}` | idem | nao alerta |
| Situacao financeira indeterminada Billing pendencia de estorno | negocio | `sum(last_30m)` de `billing.pendencia_estorno_aberta{*}` | idem | nao alerta |
| Situacao financeira indeterminada Billing operacao financeira | negocio | `sum(last_30m)` de `billing.operacao_financeira_indeterminada{*}` | idem | nao alerta |
| Falha tecnica no Mercado Pago | tecnico | `sum(last_10m)` de `billing.mercado_pago.falha_tecnica{*}` | `alarm_mercado_pago_falha_tecnica_count`, 5 (aviso em 50%) | nao alerta |

O monitor "Situacao financeira indeterminada" consulta metricas, nunca a busca de logs nem tabelas do banco. Sao quatro monitores, um por sinal, para a mensagem dizer qual pendencia disparou.

Limites de OS parada (`alarm_os_parada_segundos`; informe so os status que mudam):

| Status | Padrao | Motivo |
| --- | --- | --- |
| `EM_DIAGNOSTICO` | 86400 s (24 h) | Trabalho humano da oficina |
| `AGUARDANDO_APROVACAO` | 259200 s (3 dias) | Decisao do cliente |
| `AGUARDANDO_PAGAMENTO` | 5400 s (90 min) | Prazo total da reserva (75 min, D4.6) mais 15 min para a verificacao periodica e a consulta financeira |
| `AGUARDANDO_EXECUCAO` | 172800 s (2 dias) | Fila de execucao |
| `EM_EXECUCAO` | 259200 s (3 dias) | Trabalho humano da oficina |
| `EM_CANCELAMENTO` | 1800 s (30 min) | A compensacao e automatica; acima disso esta parada (D4.7) |
| `FINALIZADA` | 604800 s (7 dias) | Espera pela retirada |

Os padroes de `EM_DIAGNOSTICO`, `AGUARDANDO_APROVACAO`, `AGUARDANDO_EXECUCAO`, `EM_EXECUCAO` e `FINALIZADA` nao vem de uma decisao do projeto: ajuste ao ritmo real da oficina. Para a demonstracao com prazos curtos (reserva de 5 min), reduza `AGUARDANDO_PAGAMENTO` e `EM_CANCELAMENTO`.

## Metricas de log e pipeline (Billing)

O Billing grava cada sinal como JSON dentro do atributo `message` do log (`service:billing-api`); contrato em `docs/metricas-de-log.md` do `tech-challenge-billing`.

**Pipeline** `Billing - JSON do message` (`datadog_logs_custom_pipeline`): filtro `service:billing-api`; processador *grok parser* sobre `message` com a regra `%{data::json}`. Ele transforma o JSON em atributos para `@metric`, `@operacao` e `@motivo` existirem. Logs que nao sao JSON nao casam e ficam intactos. O pipeline entra no fim da ordem dos pipelines da conta (a ordem nao e gerenciada aqui). O JSON dos sinais tem lista fechada de campos no Billing (`metric`, `ordemServicoId`, `rodada`, `correlationId`, `operacaoId`, `cobrancaId`, `motivo`; no Mercado Pago, `metric`, `operacao`, `motivo` e `statusHttp`), sem atributo reservado (`service`, `status`, `message`, `level`), entao a extracao nao sobrescreve o filtro `service:billing-api` nem o status do log. Se outro pipeline anterior alterar o `message` desses logs, o parser deixa de casar: confira a ordem dos pipelines no roteiro abaixo.

**Metricas** (`datadog_logs_metric`, `compute` `count`, filtro `service:billing-api @metric:<nome>`):

| Metrica | `group_by` | Observacao |
| --- | --- | --- |
| `billing.situacao_financeira_indeterminada` | nenhum | O `motivo` pode ser texto livre do erro do gateway (alta cardinalidade) |
| `billing.operacao_financeira_indeterminada` | nenhum | `motivo` fixo (`tentativas_esgotadas`) |
| `billing.pendencia_estorno_aberta` | `motivo` | `reparo_iniciado` ou `operacao_indeterminada` |
| `billing.mercado_pago.falha_tecnica` | `operacao`, `motivo` | Operacoes e motivos em lista fechada |

Nunca se agrupa por `ordemServicoId`, `correlationId`, `operacaoId` ou `cobrancaId` (D7.1). As metricas nao tem a tag `environment`: o campo `environment` do log do Billing traz `NODE_ENV` (`production`), que nao e o ambiente do Terraform; os monitores usam `{*}`. Hoje so existe o ambiente `producao` (001-R1).

## Dashboards

**Saga da OS** (`datadog_dashboard.saga_os`, saida `datadog_dashboard_saga_os_url`):

| Grupo | Widgets |
| --- | --- |
| Fluxo por status | OS criadas por dia; idade da OS mais antiga por status; tempo medio por status (toplist); falhas de transicao |
| Outbox do OS | Pendentes; idade da mais antiga; falhas de publicacao |
| Consumo de mensagens do OS | Processadas e duplicadas (`resultado`); erros por `tipo` |
| Filas e DLQs por servico | DLQs; backlog; idade da mensagem mais antiga (quatro servicos) |
| Situacao financeira indeterminada e pendencias | OS; Billing situacao; pendencias de estorno por `motivo`; operacoes financeiras indeterminadas |
| Falhas tecnicas do Mercado Pago | Por `operacao`; por `motivo` |
| Compensacoes por motivo | Nota: sem metrica |

O dashboard "Tech Challenge - Ordens de Servico" (`datadog_dashboard.negocio`, o que ja tinha o tempo por status) passou de tres para os sete status de `STATUS_COM_DURACAO`.

## Limitacoes conhecidas

- **Compensacoes por motivo:** nenhum servico emite metrica de compensacao por motivo. O dashboard registra a lacuna em uma nota; nao ha metrica inventada.
- **`tempo_por_status`** so e emitida quando a OS sai do status; nao detecta OS presa. Para isso serve o gauge `idade_mais_antiga_segundos` e o monitor "OS parada".
- **`OS_IDADE_POR_STATUS_HABILITADO=true` e obrigatorio em producao** (ConfigMap do `oficina-api`, intervalo em `OS_IDADE_POR_STATUS_INTERVAL_MS`, padrao 60000). Sem ele o gauge some e os sete monitores "OS parada" alertam por ausencia de dado.
- **Falha da consulta de idade** descarta o ciclo sem emitir valor; por isso o monitor "OS parada" tem `notify_no_data`. Cada pod emite o gauge e a consulta agrega com `max`. Sem OS no status o valor e 0.
- **Pendencia de estorno (`ESTORNO_EM_ANDAMENTO`):** com os defeitos registrados para antes da E36, o sinal `billing.pendencia_estorno_aberta` so e alcancavel hoje no cancelamento de cobranca nao paga com Mercado Pago indeterminado. `billing.operacao_financeira_indeterminada` sai antes de `abrirPendencia` e pode existir sem pendencia.
- **Falha tecnica do Mercado Pago** conta por chamada HTTP com falha, inclusive em retentativas, e `token_ausente` por tentativa de operacao. Nao ha metrica de total de chamadas, entao o limite e uma contagem, nao uma taxa. `consultarOrder` com 4xx (401, 403, 429) nao emite sinal.
- **Gauges da outbox** so sao emitidos com o publicador ligado; o monitor de outbox atrasada nao alerta por ausencia de dado.
- **Mensagem enviada a DLQ pelo OS** nao tem metrica propria: use o monitor de DLQ (SQS) e `oficina.mensagem.erro_consumo{tipo:permanente}`.
- **Janelas:** as metricas `aws.sqs.*` chegam com atraso de alguns minutos pela integracao AWS.
- **Tentativas da outbox:** nao ha metrica do numero de `tentativas` por mensagem; a mensagem que falha sempre e coberta pelo monitor de `oficina.outbox.publicacao_falha`, junto com a idade da mais antiga.

## Roteiro de verificacao na implantacao (E37, Fase 11 do runbook)

Pre-requisitos: apply com `datadog_api_key` e `datadog_app_key`; chave de aplicacao com permissao de gerar metricas de log e gerenciar pipelines; OS com `OS_IDADE_POR_STATUS_HABILITADO=true`, publicador e consumidor ligados; Billing e Execution no ar. Guarde um print de cada passo.

1. **Ingestao das metricas do OS.** Em *Metrics > Summary*, procure cada nome exato e confira as tags `environment` e `service`, sem tag de identificador unico (sem `ordemServicoId`, `correlationId`, `eventId`): `oficina.outbox.pendentes`, `oficina.outbox.idade_mais_antiga_segundos`, `oficina.outbox.publicacao_falha`, `oficina.mensagem.processada` (`resultado:processada` e `resultado:duplicada`), `oficina.mensagem.erro_consumo` (`tipo:transitorio` e `tipo:permanente`), `oficina.ordem_servico.transicao_falha`, `oficina.situacao_financeira.indeterminada`, `oficina.ordem_servico.tempo_por_status` (tag `status`) e `oficina.ordem_servico.idade_mais_antiga_segundos` (tag `status` com os sete valores). Contadores e `tempo_por_status` so aparecem depois do primeiro evento; para `tempo_por_status` conclua uma OS ou faca uma transicao. No dashboard "Saga da OS", o grupo "Fluxo por status" mostra os sete status no gauge de idade.
2. **Pipeline e atributos do Billing.** Em *Logs > Pipelines*, confirme `Billing - JSON do message` habilitado. Em *Logs > Explorer*, a busca `service:billing-api @metric:*` devolve eventos com os atributos `@metric` e, quando houver, `@operacao` e `@motivo` no painel de atributos. Sem os atributos, o parser nao casou: confira o texto do `message`.
3. **Ingestao das metricas de log.** Em *Logs > Generate Metrics*, as quatro metricas `billing.*` existem. Em *Metrics > Summary*, procure `billing.situacao_financeira_indeterminada`, `billing.operacao_financeira_indeterminada`, `billing.pendencia_estorno_aberta` (tag `motivo`) e `billing.mercado_pago.falha_tecnica` (tags `operacao` e `motivo`). A metrica de log so conta eventos posteriores a sua criacao e so aparece depois do primeiro evento.
4. **Disparo de cada monitor com dado de teste.** Use o dado natural quando a cena o provoca; senao envie dado sintetico e registre o horario. Depois do teste, resolva ou aguarde a recuperacao dos monitores e remova mensagens de teste das filas.

   | Monitor | Dado de teste |
   | --- | --- |
   | DLQ por servico (OS, Billing, Execution, notificacao) | `aws sqs send-message --queue-url <url-da-dlq> --message-body teste-e37`; depois apague a mensagem (`receive-message` e `delete-message`) |
   | Backlog e idade SQS | Com o consumidor do servico parado (Billing escalado a zero, cena 4), o backlog e a idade sobem; ou reduza temporariamente `alarm_sqs_backlog_count` e `alarm_sqs_age_seconds` |
   | Outbox atrasada OS | Gauge sintetico acima do limite (comando abaixo), por exemplo `oficina.outbox.idade_mais_antiga_segundos:99999` |
   | Falhas de publicacao da outbox OS e erros de consumo | Contadores sinteticos acima do limite (por exemplo 6 de `oficina.outbox.publicacao_falha`, 11 de `erro_consumo` com `tipo:transitorio`, 1 com `tipo:permanente`) |
   | OS parada em `<status>` | Gauge sintetico `oficina.ordem_servico.idade_mais_antiga_segundos:9999999` com a tag `status:EM_CANCELAMENTO` (e os demais). Para o alerta por ausencia de dado, desligue `OS_IDADE_POR_STATUS_HABILITADO` e aguarde `alarm_os_parada_sem_dado_minutos` |
   | Situacao financeira indeterminada OS | Contador sintetico `oficina.situacao_financeira.indeterminada:1` ou OS com consulta financeira sem resposta (cena 4) |
   | Situacao financeira indeterminada Billing (tres sinais) | Linha de log sintetica de cada sinal (comando abaixo) |
   | Falha tecnica no Mercado Pago | Mais linhas sinteticas `billing.mercado_pago.falha_tecnica` do que `alarm_mercado_pago_falha_tecnica_count` em 10 min |

   Metrica sintetica pelo DogStatsD, de dentro de um pod do `oficina-api` (a variavel com o host do agente depende do manifesto; use o IP do node, `status.hostIP`, se `DD_AGENT_HOST` nao existir):

   ```sh
   kubectl -n oficina exec deploy/oficina-api -- node -e "require('dgram').createSocket('udp4').send(Buffer.from('oficina.ordem_servico.idade_mais_antiga_segundos:9999999|g|#environment:producao,service:oficina-api,status:EM_CANCELAMENTO'), 8125, process.env.DD_AGENT_HOST, () => process.exit())"
   ```

   Log sintetico do Billing, escrito na saida padrao do processo principal para o agente coletar (so os campos do contrato, sem identificadores):

   ```sh
   kubectl -n billing exec deploy/<deployment-do-billing> -- sh -c 'echo "{\"timestamp\":\"2026-01-01T00:00:00.000Z\",\"level\":\"warn\",\"service\":\"billing-api\",\"environment\":\"production\",\"message\":\"{\\\"metric\\\":\\\"billing.pendencia_estorno_aberta\\\",\\\"motivo\\\":\\\"reparo_iniciado\\\"}\"}" > /proc/1/fd/1'
   ```

   Troque o `metric` e o `motivo` para os outros sinais. Dados sinteticos aparecem nos graficos de producao: registre-os na evidencia.
5. **Evidencia da cena 5.** Print do dashboard "Saga da OS" e de um monitor em alerta (estado, consulta e notificacao recebida em `var.datadog_alert_recipients`).
