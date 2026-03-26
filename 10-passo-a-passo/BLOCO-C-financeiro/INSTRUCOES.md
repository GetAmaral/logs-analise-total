# Bloco C — Logs no Financeiro

**Workflow:** Financeiro - Total (eYWjnmvP8LQxY87g)

## ANTES: No Fix Conflito v2 (Premium)

Nos HTTP tool nodes que chamam o Financeiro, adicionar `trace_id` no body:

| Node no Premium | URL que chama | Adicionar campo no body |
|---|---|---|
| `registrar_financeiros` (httpRequestTool) | /webhook/registrar-gasto | `trace_id = {{ $('setar_user').item.json._trace_id }}` |
| `editar_financeiro` (httpRequestTool) | /webhook/editar-supabase | `trace_id = {{ $('setar_user').item.json._trace_id }}` |
| `excluir_financeiro` (httpRequestTool) | /webhook/excluir-supabase | `trace_id = {{ $('setar_user').item.json._trace_id }}` |

## NO FINANCEIRO: Colar os 3 nodes

| Arquivo | Conectar após | Saída paralela |
|---|---|---|
| `01-log-gasto-created.json` | O node que cria o gasto no Supabase (após setar_campos) | Sim |
| `02-log-gasto-updated.json` | `Update a row` (spent) | Sim |
| `03-log-gasto-deleted.json` | `Delete a row` (spent) | Sim |

Habilitar `continueOnFail` nos nodes `Update a row` e `Delete a row` do Financeiro.
