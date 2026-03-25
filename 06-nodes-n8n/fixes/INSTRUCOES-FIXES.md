# 3 FIXES URGENTES

## FIX 1 — Filtrar fantasmas no Main

**Workflow:** Main - Total Assistente
**Arquivo:** `01-FIX-filtro-fantasmas-main.json`

**O que fazer:**
1. Colar o node "É mensagem real?" no canvas
2. DESCONECTAR `trigger-whatsapp` → `Log: message_received`
3. Conectar: `trigger-whatsapp` → `É mensagem real?` → (saída TRUE) → `Log: message_received`
4. A saída FALSE não conecta em nada (descarta)

```
ANTES:
  trigger-whatsapp → Log: message_received (grava TUDO, 74% lixo)
                   → Check Message Age

DEPOIS:
  trigger-whatsapp → É mensagem real? → [TRUE] → Log: message_received
                   → Check Message Age (não mexer)
```

---

## FIX 2 — Reconectar ai_response ao Code in JavaScript

**Workflow:** Fix Conflito v2 (Premium)
**Arquivo:** `02-FIX-ai-response-reconectar.json`

**O que fazer:**
1. DELETAR o node `Log: ai_response1` (o que está conectado ao Aggregate11)
2. Colar o node `Log: ai_response (FIX)` no canvas
3. Conectar: `Code in JavaScript` → `Log: ai_response (FIX)` (branch paralela, junto com Switch2)

```
ANTES:
  Code in JavaScript → Switch2
                     → Aggregate11 → Log: ai_response1 (ERRADO, perde 87% das respostas)

DEPOIS:
  Code in JavaScript → Switch2
                     → Log: ai_response (FIX) (DIRETO, pega todas)
```

---

## FIX 3 — Conectar os 3 nodes de ação órfãos

**Workflow:** Fix Conflito v2 (Premium)
**Arquivo:** `03-FIX-acoes-orfas.json`

**O que fazer:**
1. Colar o node "Log: action (órfã)"
2. Duplicar com Ctrl+D (fazer 3 cópias)
3. Conectar cada cópia:

| Cópia | Conectar após | Ação que loga |
|-------|-------------|---------------|
| 1 | `HTTP - Create Tool` | registrar_gasto |
| 2 | `HTTP - Create Calendar Tool` | criar_evento |
| 3 | `HTTP - Create Calendar Tool4` | criar_evento |

Todos como branch paralela (saída adicional do node HTTP).

---

## Depois de aplicar os 3 fixes

Limpar os fantasmas antigos do banco:

```sql
DELETE FROM execution_log
WHERE event_type = 'message_received'
AND user_phone IS NULL;
```

Depois testar mandando uma mensagem e rodar:

```sql
SELECT event_type, user_phone, user_message, ai_message, action_type
FROM execution_log
WHERE user_phone IS NOT NULL
ORDER BY created_at DESC
LIMIT 20;
```
