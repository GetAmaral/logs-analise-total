# PASSO A PASSO — Fixes dos Logs

Faça na ordem. Um de cada vez.

---

## PASSO 1 — Filtrar fantasmas no Main

**Workflow:** Main - Total Assistente
**Arquivo:** `PASSO-01-filtro-fantasmas.json`

1. Copiar o conteúdo do JSON
2. Abrir o workflow Main no N8N
3. Clicar numa área vazia do canvas
4. `Ctrl+V` — o node "É mensagem real?" aparece
5. **Desconectar** a linha `trigger-whatsapp` → `Log: message_received`
6. Conectar: `trigger-whatsapp` → `É mensagem real?`
7. Conectar: `É mensagem real?` (saída **true/verde**) → `Log: message_received`
8. A saída false não conecta em nada
9. **Salvar**

```
ANTES:
  trigger-whatsapp ──→ Log: message_received
                   ──→ Check Message Age

DEPOIS:
  trigger-whatsapp ──→ É mensagem real? ──[TRUE]──→ Log: message_received
                   ──→ Check Message Age (não mexer)
```

---

## PASSO 2 — Reconectar ai_response no Premium

**Workflow:** Fix Conflito v2
**Arquivo:** `PASSO-02-ai-response-fix.json`

1. Abrir o workflow Fix Conflito v2 no N8N
2. **Deletar** o node `Log: ai_response1` (o que está conectado ao Aggregate11)
3. Clicar numa área vazia
4. `Ctrl+V` com o JSON — o node "Log: ai_response (FIX)" aparece
5. Conectar: `Code in JavaScript` → `Log: ai_response (FIX)` (branch paralela, junto com Switch2)
6. **Salvar**

```
ANTES:
  Code in JavaScript ──→ Switch2
  Aggregate11 ──→ Log: ai_response1 (ERRADO)

DEPOIS:
  Code in JavaScript ──→ Switch2
                     ──→ Log: ai_response (FIX) (DIRETO)
```

---

## PASSO 3 — Conectar ações órfãs no Premium

**Workflow:** Fix Conflito v2
**Arquivo:** `PASSO-03-acao-orfa.json`

1. Copiar o JSON
2. `Ctrl+V` no canvas — o node "Log: action (órfã)" aparece
3. Conectar como saída paralela de `HTTP - Create Tool`
4. **Duplicar** o node com `Ctrl+D`
5. Conectar a cópia como saída paralela de `HTTP - Create Calendar Tool`
6. **Duplicar** novamente com `Ctrl+D`
7. Conectar a cópia como saída paralela de `HTTP - Create Calendar Tool4`
8. **Salvar**

```
HTTP - Create Tool ──→ (fluxo existente)
                   ──→ Log: action (órfã)     ← NOVO

HTTP - Create Calendar Tool ──→ (fluxo existente)
                             ──→ Log: action (órfã)1  ← NOVO

HTTP - Create Calendar Tool4 ──→ (fluxo existente)
                              ──→ Log: action (órfã)2  ← NOVO
```

---

## PASSO 4 — Limpar fantasmas do banco

**Onde:** Supabase SQL Editor (DB2 principal)
**URL:** https://supabase.com/dashboard/project/ldbdtakddxznfridsarn/sql/new

Colar e executar:

```sql
DELETE FROM execution_log
WHERE event_type = 'message_received'
AND user_phone IS NULL;
```

---

## PASSO 5 — Testar

Mandar uma mensagem pelo WhatsApp e depois rodar:

```sql
SELECT event_type, user_phone, user_message, ai_message, action_type, action_success
FROM execution_log
WHERE user_phone IS NOT NULL
ORDER BY created_at DESC
LIMIT 10;
```

Deve mostrar a cadeia completa: message_received → message_routed → classification → ai_response → action_executed.
