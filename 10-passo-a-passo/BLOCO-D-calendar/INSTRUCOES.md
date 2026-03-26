# Bloco D — Calendar + Lembretes

## ANTES: No Premium (Fix Conflito v2)

Adicionar `trace_id` no body dos HTTP nodes que chamam estes sub-workflows:

| Node no Premium | Webhook destino | Adicionar |
|---|---|---|
| `HTTP - Create Calendar Tool` (e Tool2, Tool4, Tool6) | /webhook/5e0f5e77-... (criar) | `trace_id = {{ $('setar_user').item.json._trace_id }}` |
| `editar_evento` / `editar_eventos` / `editar_eventos1` | /webhook/editar-eventos | `trace_id = {{ $('setar_user').item.json._trace_id }}` |
| `excluir_evento` | /webhook/excluir-evento-total | `trace_id = {{ $('setar_user').item.json._trace_id }}` |
| `buscar_eventos` | /webhook/busca-total-evento | `trace_id = {{ $('setar_user').item.json._trace_id }}` |
| `criar_lembrete` | /webhook/criar-lembrete-total | `trace_id = {{ $('setar_user').item.json._trace_id }}` |
| `HTTP - Create Calendar Tool3` / `Tool5` | /webhook/criar-lembrete-recorrente-total | `trace_id = {{ $('setar_user').item.json._trace_id }}` |

## NO CALENDAR: Colar 4 nodes

| Arquivo | Conectar após |
|---|---|
| `01-log-evento-created.json` | `create_calendar_sup_google` e `create_calendar_sup_google1` (saída paralela) |
| `02-log-evento-updated.json` | `Update a row1` (calendar) (saída paralela) |
| `03-log-evento-deleted.json` | `delete_supabase` e `delete_supabase1` (saída paralela) |
| `04-log-google-synced.json` | `criar_evento_google1`, `editar_evento_google3`, `excluir_evento_google` (saída paralela, duplicar) |

Habilitar `continueOnFail` em: `Update a row1`, `delete_supabase`, `delete_supabase1`, `criar_evento_google1`, `editar_evento_google3`, `excluir_evento_google`.

## NO LEMBRETES: Reutilizar nodes

O Lembretes usa a mesma estrutura. Colar os mesmos nodes adaptando as referências dos webhooks:

| Arquivo | Conectar após no Lembretes |
|---|---|
| `01-log-evento-created.json` | Após nodes de CREATE em `calendar` (adaptar referência do webhook para `Criar Lembrete`) |
| `04-log-google-synced.json` | Após `criar_evento_google1` e `criar_evento_google_recorrente` |

Para o lembrete disparado (template WhatsApp), colar um node com `action_type = "lembrete.fired"` após os nodes `HTTP Request — send agenda template`.
