# Guia de Colagem dos Nodes — ctrl+c ctrl+v

**Dados verificados do N8N LIVE em 2026-03-25**

---

## Info confirmada do ambiente LIVE

| Item | Valor |
|------|-------|
| Supabase Credential ID | `1ENA7UIm6ILehilJ` ("Supabase account") |
| Supabase Credential (Main) | `kQkN5PrZm2GihQfS` ("Total Supabase") |
| Webhook Premium | `premium` (path: 12801cb9-3923-4517-bfbf-c24c54e613c2) |
| Standard | **NAO EXISTE MAIS no fluxo** — Main vai direto para Fix Conflito v2 |
| setar_user fields | `telefone`, `nome`, `id_user` |
| Switch2 branches | `padrao`, `registrar_gasto`, `criar_evento`, `evento_recorrente` |
| AI Agent → Code in JavaScript → Switch2 | Fluxo confirmado |

---

## Como colar cada node

### Metodo 1 — Copiar JSON do node (RECOMENDADO)

1. Abra o workflow no N8N
2. Clique em qualquer area vazia do canvas
3. Pressione `Ctrl+V` com o JSON do node copiado
4. O node aparece no canvas
5. Conecte na posicao indicada

### Metodo 2 — Adicionar manualmente

1. Clique `+` > Supabase > Create a Row
2. Selecione credential "Supabase account"
3. Tabela: `execution_log`
4. Copie os campos de cada arquivo JSON

---

## IMPORTANTE: continueOnFail = true

Todos os nodes de log tem `continueOnFail: true`. Isso significa que **se o log falhar, o workflow continua normalmente**. O log NUNCA quebra o fluxo principal.

---

## Ordem de colagem

### Main (3 nodes)

| # | Arquivo | Colar APOS | Conectar ANTES de |
|---|---------|-----------|-------------------|
| 1 | `main/01-log-message-received.json` | `trigger-whatsapp` | `Switch` (stg) — como branch paralela |
| 2 | `main/02-log-transcription.json` | `Transcribe a recording` | Nada (terminal) |
| 3 | `main/03-log-message-routed.json` | `setar_user` | `Premium User` — como branch paralela |

> NOTA Main: O credential no Main e "Total Supabase" (kQkN5PrZm2GihQfS).

### Fix Conflito v2 / Premium (5 nodes)

| # | Arquivo | Colar APOS | Conectar ANTES de |
|---|---------|-----------|-------------------|
| 1 | `premium/01-log-classification.json` | `Escolher Branch` | `AI Agent` — como branch paralela |
| 2 | `premium/02-log-ai-response.json` | `Code in JavaScript` | `Switch2` — como branch paralela |
| 3 | `premium/03-log-action-registrar-gasto.json` | `HTTP - Create Tool` (webhook gasto) | Nada (terminal, apos o HTTP) |
| 4 | `premium/04-log-action-criar-evento.json` | `HTTP - Create Calendar Tool` | Nada (terminal) |
| 5 | `premium/05-log-action-padrao.json` | `padrao` (set node) | Nada (terminal, no branch padrao) |
| 6 | `premium/06-log-action-evento-recorrente.json` | `HTTP - Create Calendar Tool3` | Nada (terminal) |

> NOTA Premium: O credential e "Supabase account" (1ENA7UIm6ILehilJ).

### Dica: Branch paralela

"Branch paralela" = conectar como OUTPUT ADICIONAL, nao substituir a conexao existente. O node de log roda em paralelo com o fluxo normal.

```
                    ┌─→ [Log: classification] (novo, paralelo)
Escolher Branch ──→ |
                    └─→ AI Agent (conexao existente, nao mexer)
```
