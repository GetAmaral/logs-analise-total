# SISTEMA DE LOGS PROFISSIONAL — Total Assistente

**Data:** 2026-03-25
**Versão:** 1.0
**Base:** Análise dos 7 workflows N8N live + boas práticas OpenTelemetry + LGPD

---

## 1. ESTADO ATUAL vs PADRÃO PROFISSIONAL

### O que temos hoje

| Critério | Estado | Nota |
|----------|--------|------|
| Log de entrada (message_received) | ✅ Funciona | Mas 78% são fantasmas (sem filtro) |
| Log de roteamento (message_routed) | ✅ Funciona | routed_to fixo "premium" |
| Log de classificação (classification) | ✅ Funciona | Branch capturado |
| Log de resposta IA (ai_response) | ✅ Funciona (fix aplicado) | ai_message, ai_action, ai_tools |
| Log de ação (action_executed) | ✅ Funciona (fix aplicado) | action_input com payload real |
| Log de transcrição áudio | ✅ Funciona | transcription_text |
| Log de OCR imagem/PDF | ✅ Funciona | extracted_data |
| Log de exclusão por botão | ✅ Funciona | 3 tipos |
| **trace_id (rastreio ponta a ponta)** | ❌ Não existe | Cada row tem UUID diferente |
| **Captura de erros reais** | ❌ 0 erros capturados | Modo paralelo = sempre true |
| **Sub-workflows (5)** | ❌ Zero logs | Financeiro, Calendar, Lembretes, Report, Service |
| **Latência real** | ❌ duration_ms sempre null | Calculável no frontend por timestamps |
| **Retenção de dados** | ❌ Sem política | Cresce infinitamente |
| **Alertas** | ❌ Nenhum | Não sabe quando algo quebra |

### O que um sistema profissional precisa ter

Baseado em OpenTelemetry, SOC2 e LGPD:

1. **trace_id** — ID único que acompanha a mensagem do WhatsApp até a resposta final, passando por TODOS os workflows
2. **Eventos estruturados** — Cada etapa é um evento com nome padronizado, não texto livre
3. **Captura de erros com contexto** — O que falhou, onde, por quê, qual o impacto
4. **Cobertura 100%** — Todo workflow que processa dados do usuário deve logar
5. **Latência por etapa** — Saber quanto tempo cada passo leva
6. **Retenção definida** — Dados de log têm prazo de vida
7. **Zero PII nos logs** — Não logar conteúdo de mensagens, tokens, senhas

---

## 2. DECISÃO ARQUITETURAL

### O que NÃO vamos mudar

- Tabela `execution_log` no Supabase DB2 — **mantemos**
- Schema atual da tabela — **mantemos e expandimos**
- Nodes de log em paralelo nos workflows — **mantemos** (simplicidade > perfeição)
- Frontend calculando latência por timestamps — **mantemos**

### O que vamos adicionar

| Mudança | Por quê |
|---------|---------|
| Campo `trace_id` na tabela | Rastrear uma mensagem ponta a ponta |
| Code node no Main que gera trace_id | Propagar para todos os workflows |
| Passar trace_id no body do HTTP para Premium | Premium herda o trace_id do Main |
| Premium passa trace_id nos webhooks dos sub-workflows | Sub-workflows herdam |
| Logs nos 5 sub-workflows | Cobertura 100% |
| Filtro de fantasmas no Main | Eliminar 78% de lixo |
| Política de retenção (SQL cron) | Controlar crescimento |

---

## 3. SCHEMA ATUALIZADO

### 3.1 — Adicionar trace_id na tabela existente

```sql
-- EXECUTAR NO SUPABASE DB2 (ldbdtakddxznfridsarn)
-- SQL Editor: https://supabase.com/dashboard/project/ldbdtakddxznfridsarn/sql/new

-- Adicionar campo trace_id
ALTER TABLE execution_log ADD COLUMN IF NOT EXISTS trace_id TEXT;

-- Índice para trace_id (query principal de rastreamento)
CREATE INDEX IF NOT EXISTS idx_exec_log_trace ON execution_log(trace_id);

-- Índice composto para trace + tempo (reconstruir timeline)
CREATE INDEX IF NOT EXISTS idx_exec_log_trace_time ON execution_log(trace_id, created_at ASC);

-- Comentário
COMMENT ON COLUMN execution_log.trace_id IS 'ID único que rastreia uma mensagem do WhatsApp através de todos os workflows. Formato: tr_{timestamp_ms}_{random8}';
```

### 3.2 — View atualizada com trace_id

```sql
-- Recriar view com trace_id
CREATE OR REPLACE VIEW v_exec_log_with_user AS
SELECT
    el.*,
    COALESCE(p1.name, p2.name, 'Desconhecido') AS user_name,
    COALESCE(p1.email, p2.email) AS user_email,
    COALESCE(el.user_plan, p1.plan_type, p2.plan_type) AS resolved_plan
FROM execution_log el
LEFT JOIN profiles p1 ON el.user_phone = p1.phone
LEFT JOIN profiles p2 ON el.user_id = p2.id::text AND p1.id IS NULL;
```

### 3.3 — Política de retenção

```sql
-- Criar função de limpeza
CREATE OR REPLACE FUNCTION fn_exec_log_cleanup()
RETURNS void AS $$
BEGIN
    -- Deletar logs INFO com mais de 6 meses
    DELETE FROM execution_log
    WHERE created_at < NOW() - INTERVAL '6 months'
    AND (error_message IS NULL);

    -- Deletar logs ERROR com mais de 12 meses
    DELETE FROM execution_log
    WHERE created_at < NOW() - INTERVAL '12 months';

    -- Deletar fantasmas (sem phone) com mais de 7 dias
    DELETE FROM execution_log
    WHERE user_phone IS NULL
    AND event_type = 'message_received'
    AND created_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql;

-- Pode ser chamada manualmente ou via N8N Schedule Trigger
-- SELECT fn_exec_log_cleanup();
```

---

## 4. TRACE_ID — IMPLEMENTAÇÃO

### 4.1 — Code node no Main (gera trace_id)

Adicionar um Code node logo após o filtro "É mensagem real?" e ANTES de todos os logs.

**Nome:** `Gerar trace_id`
**Posição:** Entre "É mensagem real?" e "Log: message_received"

```javascript
// Gerar trace_id único para esta mensagem
const timestamp = Date.now();
const random = Math.random().toString(36).substring(2, 10);
const trace_id = 'tr_' + timestamp + '_' + random;

// Repassar todos os dados + trace_id
const items = $input.all();
return items.map(item => ({
    json: {
        ...item.json,
        _trace_id: trace_id
    }
}));
```

### 4.2 — Todos os Log nodes do Main recebem trace_id

Adicionar campo em cada log node do Main:
```
trace_id = {{ $json._trace_id || null }}
```

### 4.3 — Main passa trace_id para o Premium

No node `Premium User` (HTTP POST para o webhook do Fix Conflito), adicionar o trace_id no body:

No body do HTTP Request, adicionar campo:
```
trace_id = {{ $json._trace_id }}
```

### 4.4 — Premium recebe e propaga trace_id

No `setar_user` do Premium, adicionar campo:
```
_trace_id = {{ $('premium').item.json.body.trace_id || null }}
```

Todos os log nodes do Premium usam:
```
trace_id = {{ $('setar_user').item.json._trace_id || null }}
```

### 4.5 — Premium passa trace_id para sub-workflows

Cada HTTP Create Tool / Calendar Tool que chama sub-workflows, adicionar no body:
```
trace_id = {{ $('setar_user').item.json._trace_id }}
```

### 4.6 — Sub-workflows recebem trace_id

Cada sub-workflow pega do body do webhook:
```
_trace_id = {{ $json.body.trace_id || $json.trace_id || null }}
```

---

## 5. EVENTOS PADRONIZADOS

### Catálogo de eventos (nomes fixos, não texto livre)

| Evento | Categoria | Onde ocorre | O que captura |
|--------|-----------|------------|---------------|
| `message.received` | inbound | Main | phone, type, timestamp |
| `message.routed` | inbound | Main | phone, user_id, plan, destino |
| `audio.transcribed` | processing | Main + Premium | transcription_text |
| `image.extracted` | processing | Premium | extracted_data (OCR text) |
| `document.extracted` | processing | Premium | extracted_data (OCR text) |
| `intent.classified` | processing | Premium | branch, user_message |
| `ai.responded` | processing | Premium | ai_message, ai_action, ai_tools |
| `action.executed` | action | Premium | action_type, action_input, success |
| `button.pressed` | action | Premium | action_type (excluir_*), entity_id |
| `nudge.sent` | outbound | Premium | tipo (google_calendar) |
| `nudge.responded` | inbound | Premium | resposta (sim/nao) |
| `gasto.created` | data | Sub: Financeiro | nome, valor, categoria |
| `gasto.updated` | data | Sub: Financeiro | campos alterados |
| `gasto.deleted` | data | Sub: Financeiro | id_gasto |
| `evento.created` | data | Sub: Calendar | nome, inicio, fim |
| `evento.updated` | data | Sub: Calendar | campos alterados |
| `evento.deleted` | data | Sub: Calendar | event_id |
| `google.synced` | integration | Sub: Calendar | evento, operação (create/patch/delete) |
| `lembrete.created` | data | Sub: Lembretes | nome, data, recorrencia |
| `lembrete.fired` | outbound | Sub: Lembretes | enviou WhatsApp ao user |
| `report.generated` | processing | Sub: Report | tipo (semanal/mensal), periodo |
| `report.sent` | outbound | Sub: Report | enviou PDF WhatsApp |
| `reengagement.sent` | outbound | Sub: Service Msg | phone, tipo |

---

## 6. NODES PARA OS 5 SUB-WORKFLOWS

### 6.1 — Financeiro (eYWjnmvP8LQxY87g)

O workflow Financeiro tem 4 webhooks de entrada:
- `registrar-webhook` — registrar gasto
- `entrada1` — entrada financeira
- `excluir` — excluir gasto
- `entrada2` — outra entrada

**Ações que precisam de log:**

| Ação | Node Supabase/HTTP existente | event_type |
|------|---------------------------|-----------|
| Registrar gasto | Webhook de entrada | `gasto.created` |
| Atualizar gasto | `Update a row` (spent) | `gasto.updated` |
| Excluir gasto | `Delete a row` (spent) | `gasto.deleted` |
| Enviar resposta | HTTP Request5/6 (Evolution API) | `action.executed` |

**Node de log para Financeiro:**

```json
ARQUIVO: 11-plano-final/nodes/financeiro-log-gasto-created.json
```

### 6.2 — Calendar WebHooks (ZZbMdcuCKx0fM712)

4 webhooks:
- `Webhook-Calendar-Creator` — criar evento
- `Buscar eventos - Webhook` — buscar
- `Excluir eventos - Webhook` — excluir
- `Editar eventos - webhook` — editar

**Ações que precisam de log:**

| Ação | Node existente | event_type |
|------|---------------|-----------|
| Criar evento Supabase | CREATE (calendar) | `evento.created` |
| Editar evento Supabase | `Update a row1` (calendar) | `evento.updated` |
| Excluir evento Supabase | `delete_supabase` / `delete_supabase1` | `evento.deleted` |
| Criar evento Google | `criar_evento_google` / `criar_evento_google1` | `google.synced` |
| Editar evento Google | `editar_evento_google3` | `google.synced` |
| Excluir evento Google | `excluir_evento_google` | `google.synced` |

### 6.3 — Lembretes (sjDpjKqtwLk7ycki)

2 webhooks:
- `Criar Lembrete` — lembrete simples
- `Criar Lembrete Recorrente` — recorrente

**Ações que precisam de log:**

| Ação | Node existente | event_type |
|------|---------------|-----------|
| Criar lembrete Supabase | CREATE (calendar) | `lembrete.created` |
| Criar evento Google | `criar_evento_google1` / `criar_evento_google_recorrente` | `google.synced` |
| Marcar como lembrado | `Mark as Remembered` / `Mark as Remembered1` | `lembrete.fired` |
| Avançar recorrente | `Avançar Recorrente` | `lembrete.fired` |
| Enviar template WhatsApp | `HTTP Request — send agenda template` | `lembrete.fired` |

### 6.4 — Report (S2QgrsN6uteyB04E)

3 webhooks:
- `relatorio-semanal`
- `relatorio-mensal`
- `webhook-report`

**Ações que precisam de log:**

| Ação | Node existente | event_type |
|------|---------------|-----------|
| Gerar PDF | Gotenberg nodes | `report.generated` |
| Enviar PDF WhatsApp | `Enviar Arquivo WhatsApp Oficial3/4` | `report.sent` |
| Update recurrency_report | `Update a row` (6 nodes) | `action.executed` |

### 6.5 — Service Message 24h (GNdoIS2zxGBa4CW0)

Trigger: Schedule (cron)

**Ações que precisam de log:**

| Ação | Node existente | event_type |
|------|---------------|-----------|
| Enviar reengajamento | `HTTP Request — send flow with wa_id` | `reengagement.sent` |
| Marcar notificado | `Update a row` (message_log) | `action.executed` |

---

## 7. PLANO DE EXECUÇÃO — 6 BLOCOS

### Bloco A: Schema + trace_id (20 min)

| Passo | O que | Onde |
|-------|-------|------|
| A1 | Executar ALTER TABLE + índices | Supabase SQL Editor |
| A2 | Recriar view v_exec_log_with_user | Supabase SQL Editor |
| A3 | Criar fn_exec_log_cleanup | Supabase SQL Editor |
| A4 | Colar node "Gerar trace_id" no Main | N8N Main |
| A5 | Adicionar campo trace_id em todos os Log nodes do Main | N8N Main |
| A6 | Adicionar trace_id no body do "Premium User" HTTP | N8N Main |

### Bloco B: trace_id no Premium (15 min)

| Passo | O que | Onde |
|-------|-------|------|
| B1 | Adicionar _trace_id no setar_user | N8N Premium |
| B2 | Adicionar trace_id em todos os Log nodes do Premium (14 nodes) | N8N Premium |
| B3 | Adicionar trace_id no body dos HTTP Create Tool / Calendar Tool | N8N Premium |

### Bloco C: Financeiro (30 min)

| Passo | O que | Onde |
|-------|-------|------|
| C1 | Colar node "Log: gasto.created" após cada webhook de registro | N8N Financeiro |
| C2 | Colar node "Log: gasto.updated" após Update a row (spent) | N8N Financeiro |
| C3 | Colar node "Log: gasto.deleted" após Delete a row (spent) | N8N Financeiro |

### Bloco D: Calendar + Lembretes (45 min)

| Passo | O que | Onde |
|-------|-------|------|
| D1 | Colar logs de evento.created/updated/deleted | N8N Calendar |
| D2 | Colar logs de google.synced (create/patch/delete) | N8N Calendar |
| D3 | Colar logs de lembrete.created | N8N Lembretes |
| D4 | Colar logs de lembrete.fired (send template) | N8N Lembretes |

### Bloco E: Report + Service (20 min)

| Passo | O que | Onde |
|-------|-------|------|
| E1 | Colar logs de report.generated e report.sent | N8N Report |
| E2 | Colar logs de reengagement.sent | N8N Service Msg |

### Bloco F: Teste + Validação (15 min)

| Passo | O que | Onde |
|-------|-------|------|
| F1 | Enviar mensagem de texto | WhatsApp |
| F2 | Verificar trace_id propagado em toda a cadeia | SQL |
| F3 | Registrar gasto → verificar log no Financeiro | SQL |
| F4 | Criar evento → verificar log no Calendar | SQL |
| F5 | Query de validação final | SQL |

**Validação final:**
```sql
-- Uma mensagem deve ter trace_id em TODAS as rows
SELECT trace_id, event_type, source_workflow, created_at
FROM execution_log
WHERE trace_id = (
    SELECT trace_id FROM execution_log
    WHERE event_type = 'message_received'
    AND user_phone IS NOT NULL
    ORDER BY created_at DESC LIMIT 1
)
ORDER BY created_at ASC;
```

Deve retornar algo como:
```
tr_1711392000_k8j2m4n1 | message.received   | main      | 14:32:01
tr_1711392000_k8j2m4n1 | message.routed     | main      | 14:32:02
tr_1711392000_k8j2m4n1 | intent.classified  | premium   | 14:32:04
tr_1711392000_k8j2m4n1 | ai.responded       | premium   | 14:32:08
tr_1711392000_k8j2m4n1 | action.executed    | premium   | 14:32:09
tr_1711392000_k8j2m4n1 | gasto.created      | financeiro| 14:32:10
```

**Toda a cadeia com o MESMO trace_id.**

---

## 8. O QUE É POSSÍVEL vs O QUE NÃO É

### Possível e vamos fazer

| Funcionalidade | Viável? | Quando |
|---------------|---------|--------|
| trace_id ponta a ponta | ✅ Sim | Bloco A+B |
| Logs nos 5 sub-workflows | ✅ Sim | Blocos C+D+E |
| Cobertura 100% do fluxo principal | ✅ Sim | Após Bloco F |
| Latência calculada no frontend | ✅ Sim | Já funciona |
| Agrupamento de interações | ✅ Sim (via trace_id) | Após Bloco B |
| Retenção automática | ✅ Sim | Bloco A |
| Dashboard com KPIs | ✅ Sim | Frontend (dev) |
| Timeline estilo WhatsApp | ✅ Sim | Frontend (dev) |

### Possível mas NÃO vamos fazer agora

| Funcionalidade | Por que não agora |
|---------------|------------------|
| Captura de erros reais (modo série) | Requer reestruturar conexões de 20+ nodes — risco alto, ganho médio |
| Alertas automáticos | Precisa de infraestrutura (cron + notificação WhatsApp) — fase futura |
| Log de TODAS as mensagens WhatsApp enviadas | São 18+ nodes de envio — muito esforço para pouco insight |
| Hashing de phone (LGPD) | O sistema inteiro usa phone em plaintext — mudança sistêmica, não só logs |
| Particionamento por mês | Desnecessário no volume atual (<1000 rows/dia) |

### Não é possível

| Funcionalidade | Por quê |
|---------------|---------|
| Log do conteúdo real das mensagens no sub-workflow | Sub-workflows recebem apenas IDs/valores, não a mensagem original |
| Latência real por node N8N | N8N não expõe timing por node via API |
| Log de retries automáticos do N8N | N8N não dispara evento quando faz retry interno |

---

## 9. MÉTRICAS QUE O SISTEMA VAI FORNECER

Após implementação completa:

| Métrica | Query |
|---------|-------|
| Mensagens por dia/hora | `GROUP BY date_trunc('hour', created_at) WHERE event_type = 'message.received'` |
| Latência ponta a ponta | `MAX(created_at) - MIN(created_at) GROUP BY trace_id` |
| Taxa de sucesso de ações | `action_success = true / total WHERE event_type = 'action.executed'` |
| Top intents | `GROUP BY branch WHERE event_type = 'intent.classified'` |
| Gastos registrados por dia | `WHERE event_type = 'gasto.created' GROUP BY date` |
| Eventos criados por dia | `WHERE event_type = 'evento.created' GROUP BY date` |
| Relatórios enviados | `WHERE event_type = 'report.sent'` |
| Reengajamentos enviados | `WHERE event_type = 'reengagement.sent'` |
| Erros por workflow | `WHERE error_message IS NOT NULL GROUP BY source_workflow` |
| Usuários únicos ativos | `COUNT(DISTINCT user_phone) WHERE created_at >= today` |
| Trace completo de qualquer mensagem | `WHERE trace_id = 'tr_...' ORDER BY created_at ASC` |

---

*Plano validado contra: OpenTelemetry structured logging, SOC2 audit requirements, LGPD data minimization, distributed tracing patterns (Jaeger/Zipkin), PostgreSQL best practices.*

*Gerado por Argus (auditor-real squad) — 25/03/2026*
