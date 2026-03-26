# Bloco E — Report + Service Message

## ANTES: No Premium

Adicionar `trace_id` no body do tool `gerar_relatorio`:
- Name: `trace_id`
- Value: `={{ $('setar_user').item.json._trace_id }}`

## NO REPORT (S2QgrsN6uteyB04E)

| Arquivo | Conectar após |
|---|---|
| `01-log-report-sent.json` | Após CADA node de envio de PDF: `Enviar Arquivo WhatsApp Oficial3`, `Oficial4`, `enviar-whatsapp`, `enviar-whatsapp1` (duplicar 4x) |

Habilitar `continueOnFail` nos nodes de envio.

## NO SERVICE MESSAGE (GNdoIS2zxGBa4CW0)

| Arquivo | Conectar após |
|---|---|
| `02-log-reengagement-sent.json` | Após `HTTP Request — send flow with wa_id` (saída paralela) |

Habilitar `continueOnFail` no `HTTP Request — send flow with wa_id`.

Obs: Service Message não tem trace_id (é cron, não vem do user). O campo fica vazio.
