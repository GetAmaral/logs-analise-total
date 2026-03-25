# PLANO DE IMPLEMENTACAO — execution_log v2

**Data:** 2026-03-25
**Status:** AGUARDANDO VALIDACAO
**Autor:** Argus (auditor-real squad)

---

## CONTEXTO

**Problema:** 98 acoes de escrita nos workflows, apenas 8 logadas. 74 sem cobertura. Standard perde tudo em 1h.

**Solucao:** Tabela `execution_log` no Supabase + nodes INSERT nos workflows N8N.

**Duas premissas do usuario:**
1. **ZERO vazamento** de dados sensiveis (tokens, keys, credentials)
2. **Estrutura pensada para UI** — sera exibida no site existente (React + shadcn/ui + TailwindCSS) com visual Apple-style, clean e organizado

---

## SECAO A — PROTECAO DE DADOS (O QUE NUNCA LOGAR)

### Dados sensíveis identificados nos workflows:

| Dado Sensivel | Onde aparece | Risco |
|---------------|-------------|-------|
| Google `access_token` / `refresh_token` | Calendar, Lembretes (decrypt_token_json) | CRITICO |
| `google_calendar_secret_key_2024` | Calendar WebHooks (encrypt/decrypt) | CRITICO |
| `SUPABASE_SERVICE_ROLE_KEY` | Edge functions, headers | CRITICO |
| `GOOGLE_CLIENT_SECRET` | Edge functions OAuth | CRITICO |
| `HOTMART_HOTTOK` | Webhook de pagamento | CRITICO |
| WhatsApp `phoneNumberId` (744582292082931) | Todos os workflows | MEDIO |
| Evolution API host + instance `mordomo` | Premium, Standard, Report | MEDIO |
| `sessionToken` (64-char hex) | OTP verification | CRITICO |
| Bearer tokens nos headers HTTP | Calendar, Lembretes | CRITICO |

### Regra de ouro: O QUE LOGAR vs O QUE NAO LOGAR

```
LOGAR (payload util):                    NUNCA LOGAR:
  - nome_gasto, valor, categoria           - access_token, refresh_token
  - nome_evento, data_inicio, data_fim     - Bearer headers
  - branch (classificacao de intent)       - service_role keys
  - acao executada (nome)                  - API keys (Evolution, WhatsApp)
  - mensagem do usuario (texto)            - session tokens
  - resposta da IA (texto)                 - encryption keys
  - status da acao (success/fail)          - URLs com tokens inline
  - tipo de mensagem (text/audio/img)      - client secrets
  - erro (mensagem generica)              - IPs internos do servidor
```

### Como implementar a protecao:

**No N8N**, cada node de log usara campos EXPLICITOS (nao `$json` inteiro). Isso significa que NUNCA logamos o payload cru — apenas os campos selecionados.

**Exemplo ERRADO (vaza tudo):**
```
action_input = {{ JSON.stringify($json) }}  // PERIGO: pode ter tokens
```

**Exemplo CORRETO (campos explicitos):**
```
action_input = {{
  JSON.stringify({
    nome: $json.nome_gasto,
    valor: $json.valor_gasto,
    categoria: $json.categoria_gasto,
    tipo: $json.tipo_gasto
  })
}}
```

### Sanitizacao por workflow:

| Workflow | O que logar no action_input | O que EXCLUIR |
|----------|---------------------------|---------------|
| **Financeiro** | nome_gasto, valor, categoria, tipo, data | fk_user (ja temos user_id) |
| **Calendar** | event_name, start, end, desc, compromisso_tipo | session_event_id_google, tokens, google_calendar_secret |
| **Lembretes** | event_name, start, end, rrule, reminder | tokens OAuth, descriptografar_token payloads |
| **Report** | tipo_relatorio (semanal/mensal), periodo | PDF binary, media_id WhatsApp |
| **Premium** | acao, mensagem, tool name, parametros da tool | Redis keys, chat memory raw, tokens |
| **Standard** | acao, mensagem, tool name | idem Premium |
| **Service Msg** | tipo_mensagem (reengajamento) | phone raw (ja temos user_phone) |

---

## SECAO B — ESTRUTURA PENSADA PARA A UI

### Stack existente do site:

| Camada | Tecnologia |
|--------|-----------|
| Framework | React 18 + TypeScript |
| UI Components | shadcn/ui (Radix UI) |
| Styling | TailwindCSS |
| Tables | TanStack React Table |
| State | TanStack React Query |
| Charts | Recharts + Chart.js |
| Export | jspdf + xlsx |

### Componentes existentes que podemos REUTILIZAR:

- `AllTransactionsModal.tsx` — modal com filtros por periodo, tipo, categoria, busca, export PDF/Excel
- `TransactionsDataGrid.tsx` — tabela com sort, filter, paginacao, acoes
- `ActiveSessions.tsx` — cards de atividade com device type, timestamps
- `ReportsView.tsx` — KPIs, graficos, comparacoes

### Como o execution_log alimenta a UI:

A tabela `execution_log` sera a fonte de dados para uma nova pagina/secao no dashboard. Para isso, os campos precisam suportar:

#### 1. Timeline de atividade (estilo Apple Activity)

Cada interacao do usuario vira um **card** na timeline:

```
[icone] [tipo] [resumo]                    [timestamp]
  |
  |-- Classificacao: criar_gasto
  |-- IA respondeu: "Registrei seu gasto de R$45 em Alimentacao"
  |-- Acao: registrar_gasto -> sucesso
```

**Campos necessarios:** `event_type` (icone), `branch` (tag), `ai_message` (resumo), `action_success` (status badge), `created_at` (timestamp)

#### 2. Filtros (estilo shadcn Command)

| Filtro | Campo | Tipo UI |
|--------|-------|---------|
| Periodo | `created_at` | Date range picker |
| Workflow | `source_workflow` | Select/badges |
| Tipo de evento | `event_type` | Multi-select chips |
| Branch/intent | `branch` | Select |
| Status | `action_success` | Toggle (sucesso/falha/todos) |
| Busca texto | `user_message`, `ai_message` | Search input |

#### 3. KPIs / Cards de resumo (topo da pagina)

| KPI | Query |
|-----|-------|
| Total de interacoes hoje | `WHERE event_type = 'interaction_complete' AND created_at >= today` |
| Taxa de sucesso | `action_success = true / total action_executed` |
| Top intents | `GROUP BY branch ORDER BY count DESC LIMIT 5` |
| Erros recentes | `WHERE error_message IS NOT NULL ORDER BY created_at DESC LIMIT 5` |
| Split Premium vs Standard | `GROUP BY source_workflow WHERE source_workflow IN ('premium','standard')` |

#### 4. Graficos

| Grafico | Tipo | Dados |
|---------|------|-------|
| Volume por hora/dia | Area chart (Recharts) | `GROUP BY date_trunc('hour', created_at)` |
| Distribuicao de intents | Donut chart | `GROUP BY branch` |
| Sucesso vs falha | Stacked bar | `GROUP BY action_success, date` |
| Workflows mais ativos | Horizontal bar | `GROUP BY source_workflow` |

### Campos adicionados na tabela para suportar a UI:

Alem dos campos do plano original, adicionei:

| Campo novo | Tipo | Para que |
|-----------|------|---------|
| `session_id` | TEXT | Agrupar eventos da mesma sessao (gap > 30min = nova sessao) |
| `duration_ms` | INTEGER | Tempo de processamento (UI mostra "respondeu em 2.3s") |
| `user_plan` | TEXT | free/standard/premium — filtro direto sem JOIN |
| `interaction_id` | UUID | Agrupa TODOS os eventos de uma unica interacao (message_received → classification → ai_response → action_executed) |
| `whatsapp_timestamp` | TIMESTAMPTZ | Timestamp original do WhatsApp (nao o created_at do Supabase) |
| `status` | TEXT | pending / processing / completed / error — para UI mostrar badge de status |

---

## SECAO C — FASES DE IMPLEMENTACAO

### FASE 1 — Criar tabela no Supabase

**Onde:** Supabase SQL Editor
**Risco:** ZERO (tabela nova)

#### Passo 1.1 — Migration SQL

```sql
-- ================================================
-- EXECUTION_LOG v2 — Com suporte a UI
-- ================================================

CREATE TABLE IF NOT EXISTS execution_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

  -- Agrupamento
  interaction_id UUID DEFAULT gen_random_uuid(),
  session_id TEXT,

  -- Usuario (dados seguros — sem tokens/keys)
  user_phone TEXT,
  user_id TEXT,
  user_plan TEXT,

  -- Mensagem original
  user_message TEXT,
  message_type TEXT DEFAULT 'text',
  whatsapp_timestamp TIMESTAMPTZ,

  -- Audio
  transcription_text TEXT,
  summary_text TEXT,

  -- Classificacao
  branch TEXT,

  -- Resposta da IA (SANITIZADA — sem tokens)
  ai_message TEXT,
  ai_action TEXT,
  ai_tools_called JSONB,
  ai_full_response JSONB,

  -- Acao executada (SANITIZADA — campos explicitos, sem payloads crus)
  action_type TEXT,
  action_input JSONB,
  action_output JSONB,
  action_success BOOLEAN,

  -- Dados extraidos (PDF/imagem — texto apenas)
  extracted_data JSONB,

  -- Metadados
  source_workflow TEXT NOT NULL,
  event_type TEXT NOT NULL,
  status TEXT DEFAULT 'completed',
  routed_to TEXT,
  duration_ms INTEGER,

  -- Erro
  error_message TEXT,

  -- Timestamp
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### Passo 1.2 — Indices

```sql
CREATE INDEX idx_exec_log_phone ON execution_log(user_phone);
CREATE INDEX idx_exec_log_user_id ON execution_log(user_id);
CREATE INDEX idx_exec_log_event_type ON execution_log(event_type);
CREATE INDEX idx_exec_log_source ON execution_log(source_workflow);
CREATE INDEX idx_exec_log_created ON execution_log(created_at DESC);
CREATE INDEX idx_exec_log_branch ON execution_log(branch);
CREATE INDEX idx_exec_log_action_type ON execution_log(action_type);
CREATE INDEX idx_exec_log_status ON execution_log(status);
CREATE INDEX idx_exec_log_interaction ON execution_log(interaction_id);
CREATE INDEX idx_exec_log_session ON execution_log(session_id);
CREATE INDEX idx_exec_log_plan ON execution_log(user_plan);

-- Compostos (queries da UI)
CREATE INDEX idx_exec_log_phone_created ON execution_log(user_phone, created_at DESC);
CREATE INDEX idx_exec_log_phone_event ON execution_log(user_phone, event_type);
CREATE INDEX idx_exec_log_source_created ON execution_log(source_workflow, created_at DESC);
```

#### Passo 1.3 — RLS

```sql
ALTER TABLE execution_log ENABLE ROW LEVEL SECURITY;

-- Somente service_role pode ler/escrever (bypassa RLS)
-- Nenhuma policy para anon = deny all

COMMENT ON TABLE execution_log IS 'Log centralizado de execucao dos workflows N8N — dados sanitizados, sem tokens/keys';
```

#### Passo 1.4 — Views para a UI (queries pre-prontas)

```sql
-- View: resumo diario (KPI cards)
CREATE OR REPLACE VIEW v_exec_log_daily_summary AS
SELECT
  date_trunc('day', created_at) AS dia,
  source_workflow,
  event_type,
  count(*) AS total,
  count(*) FILTER (WHERE action_success = true) AS sucesso,
  count(*) FILTER (WHERE action_success = false) AS falha,
  count(*) FILTER (WHERE error_message IS NOT NULL) AS erros,
  avg(duration_ms) AS avg_duration_ms
FROM execution_log
GROUP BY 1, 2, 3;

-- View: distribuicao de intents
CREATE OR REPLACE VIEW v_exec_log_branch_stats AS
SELECT
  branch,
  source_workflow,
  count(*) AS total,
  count(*) FILTER (WHERE action_success = true) AS sucesso,
  count(*) FILTER (WHERE action_success = false) AS falha
FROM execution_log
WHERE branch IS NOT NULL
GROUP BY 1, 2;
```

#### Passo 1.5 — Testar

```sql
INSERT INTO execution_log (
  user_phone, user_id, user_plan,
  user_message, message_type, branch,
  ai_message, ai_action, action_success,
  source_workflow, event_type, status, duration_ms
) VALUES (
  '5543XXXXXXXX', 'test-user-id', 'premium',
  'registra um gasto de 45 reais em alimentacao',
  'text', 'criar_gasto',
  'Registrei seu gasto de R$45,00 em Alimentacao!',
  'registrar_gasto', true,
  'premium', 'interaction_complete', 'completed', 2340
);

SELECT * FROM execution_log;
SELECT * FROM v_exec_log_daily_summary;
SELECT * FROM v_exec_log_branch_stats;

-- Limpar
DELETE FROM execution_log WHERE user_id = 'test-user-id';
```

**CHECKPOINT 1: Tabela criada, views funcionando. Validar antes de Fase 2.**

---

### FASE 2 — Log no Main (onboarding + roteamento)

**Workflow:** Main - Total Assistente (9WDlyel5xRCLAvtH)
**Risco:** BAIXO

| # | Node a adicionar | Posicao | event_type | Campos logados |
|---|-----------------|---------|-----------|----------------|
| 2.1 | Log: message_received | Apos trigger, antes do Switch | `message_received` | user_phone, user_message, message_type, whatsapp_timestamp |
| 2.2 | Log: transcription | Apos "Transcribe a recording" | `transcription` | user_phone, transcription_text, message_type=audio |
| 2.3 | Log: audio_summary | Apos "Message a model" | `audio_summary` | user_phone, summary_text |
| 2.4 | Log: message_routed | Antes do HTTP POST para Premium/Standard | `message_routed` | user_phone, user_id, user_plan, routed_to |

**Regra de sanitizacao Main:**
- NO node 2.1: Logar APENAS `from` (phone) e `text.body` ou `type`. NUNCA logar o payload completo do webhook (contem metadata do WhatsApp Graph API).
- NO node 2.4: NUNCA incluir o body do HTTP POST (pode conter dados concatenados).

**CHECKPOINT 2: Enviar mensagem real, verificar 2-4 rows no execution_log.**

---

### FASE 3 — Log no Premium (Fix Conflito v2)

**Workflow:** User Premium - Total (tyJ3YAAtSg1UurFj)
**Risco:** MEDIO (workflow critico, mas so ADICIONAMOS nodes)

| # | Node a adicionar | Posicao | event_type | Campos logados |
|---|-----------------|---------|-----------|----------------|
| 3.1 | Log: classification | Apos "Escolher Branch" | `classification` | user_phone, user_id, user_plan, user_message, branch |
| 3.2 | Log: ai_response | Apos "Code in JavaScript" | `ai_response` | ai_message, ai_action, ai_tools_called, ai_full_response (SANITIZADO) |
| 3.3 | Log: action_executed | Apos cada webhook de acao | `action_executed` | action_type, action_input (SANITIZADO), action_success, duration_ms |
| 3.4 | Log: extracted_data | Apos OCR nodes | `transcription` | extracted_data (texto apenas), message_type=document/image |

**Regra de sanitizacao Premium — action_input por acao:**

| Acao | Campos SEGUROS para logar | EXCLUIR |
|------|--------------------------|---------|
| `registrar_gasto` | nome_gasto, valor_gasto, categoria_gasto, tipo_gasto, data_gasto | id_user (redundante) |
| `criar_evento` | nome_evento, descricao, data_inicio, data_fim | id_user (redundante) |
| `criar_lembrete` | nome, rrule, dtstart, timezone, until | id_user |
| `excluir_financeiro` | id_gasto (referencia apenas) | id_user |
| `excluir_evento` | event_id (referencia apenas) | id_user |
| `editar_evento` | sessao_id, campos_alterados | id_user |
| `gerar_relatorio` | tipo, startDate, endDate | id_user |

**Regra ai_full_response:** Logar o JSON parseado do "Code in JavaScript" (`parsed_output`), que contem `acao`, `mensagem`, `tool`. NUNCA logar `$json.output` cru (pode conter lixo de markdown).

**CHECKPOINT 3: Registrar gasto via WhatsApp Premium, verificar cadeia completa no log.**

---

### FASE 4 — Log no Standard

**Workflow:** User Standard - Total (c8gtSmh1BPzZXbJa)
**Risco:** BAIXO (hoje nao tem NADA)

Identico a Fase 3, com:
- `source_workflow = "standard"`
- `user_plan = "standard"` ou `"free"`
- Adaptar nomes de nodes (podem diferir do Premium)

**PRIORIDADE MAXIMA — hoje perde TUDO.**

**CHECKPOINT 4: Enviar mensagem como Standard, confirmar que agora aparece no log.**

---

### FASE 5 — Sub-workflows

| # | Workflow | Nodes a adicionar | Sanitizacao especial |
|---|----------|------------------|---------------------|
| 5.1 | Financeiro | Log apos UPDATE/DELETE em `spent` | Logar nome_gasto, valor. EXCLUIR fk_user |
| 5.2 | Calendar | Log apos CREATE/UPDATE/DELETE calendar + Google API | EXCLUIR tokens OAuth, google_calendar_secret_key. Logar event_name, tipo |
| 5.3 | Lembretes | Log apos CREATE calendar/google, UPDATE remembered | EXCLUIR descriptografar_token, refresh_access. Logar event_name, rrule |
| 5.4 | Report | Log apos envio PDF WhatsApp | EXCLUIR binary PDF, media_id. Logar tipo_relatorio, periodo |
| 5.5 | Service Msg | Log apos envio reengajamento | Logar tipo_mensagem. EXCLUIR template raw |

**CHECKPOINT 5: Testar cada um individualmente.**

---

### FASE 6 — Validacao + Preparacao para UI

#### 6.1 — Teste end-to-end

1. Texto Premium → verificar chain completa
2. Audio Premium → transcription + summary
3. Registrar gasto → classification + ai_response + action_executed
4. Criar evento → chain completa
5. Texto Standard → confirmar que loga
6. Verificar que nenhum workflow quebrou

#### 6.2 — Auditoria de seguranca

```sql
-- Verificar se algum token vazou nos logs
SELECT id, action_input::text, action_output::text, ai_full_response::text
FROM execution_log
WHERE
  action_input::text ILIKE '%token%'
  OR action_input::text ILIKE '%bearer%'
  OR action_input::text ILIKE '%secret%'
  OR action_output::text ILIKE '%token%'
  OR ai_full_response::text ILIKE '%key%';

-- Se retornar QUALQUER row = PARAR e corrigir
```

#### 6.3 — Queries que a UI vai usar

```sql
-- Timeline de um usuario (pagina principal)
SELECT
  id, interaction_id, event_type, source_workflow,
  user_message, ai_message, branch, action_type,
  action_success, status, duration_ms, created_at
FROM execution_log
WHERE user_phone = '{phone}'
ORDER BY created_at DESC
LIMIT 50;

-- KPIs do dia
SELECT
  count(*) FILTER (WHERE event_type = 'interaction_complete') AS interacoes,
  count(*) FILTER (WHERE action_success = true) AS acoes_sucesso,
  count(*) FILTER (WHERE action_success = false) AS acoes_falha,
  count(*) FILTER (WHERE error_message IS NOT NULL) AS erros,
  avg(duration_ms) FILTER (WHERE duration_ms IS NOT NULL) AS tempo_medio_ms
FROM execution_log
WHERE created_at >= CURRENT_DATE;

-- Top intents da semana
SELECT branch, count(*) AS total
FROM execution_log
WHERE branch IS NOT NULL AND created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY branch
ORDER BY total DESC
LIMIT 10;

-- Volume por hora (grafico area)
SELECT
  date_trunc('hour', created_at) AS hora,
  count(*) AS total
FROM execution_log
WHERE created_at >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY 1
ORDER BY 1;
```

**CHECKPOINT 6: Tudo validado, zero vazamento, pronto para construir a UI.**

---

### FASE 7 — Pagina no Dashboard (FUTURA)

Apos os dados fluindo, criar uma nova rota no `novo-site-testing`:

```
/dashboard/activity-log
```

**Componentes a construir (reutilizando shadcn existente):**

| Componente | Base existente | Funcao |
|-----------|---------------|--------|
| ActivityTimeline | Novo (cards empilhados) | Timeline vertical com cards por interacao |
| LogFilters | AllTransactionsModal (filtros) | Date range, workflow, event_type, branch, status |
| LogKPICards | ReportsView (KPIs) | 4-5 cards no topo com metricas |
| LogChart | CustomBarChart / Recharts | Volume, intents, sucesso/falha |
| LogDataTable | TransactionsDataGrid | Tabela detalhada com export |
| InteractionDetail | Sheet/Drawer (shadcn) | Detalhe completo de uma interacao |

**Visual Apple-style:**
- Cards com `rounded-2xl`, sombra suave, espacamento generoso
- Badges coloridos para status (verde=sucesso, vermelho=erro, amarelo=processing)
- Icones Lucide para cada event_type
- Dark mode nativo via TailwindCSS
- Animacoes suaves com `transition-all`
- Tipografia Inter/Roboto, hierarquia clara

> Esta fase sera trabalhada DEPOIS que os dados estiverem fluindo.

---

## RESUMO EXECUTIVO

| Fase | O que | Checkpoint |
|------|-------|-----------|
| **1** | Criar tabela + indices + views no Supabase | Tabela vazia funcionando |
| **2** | 4 nodes de log no Main | Mensagem aparece no log |
| **3** | 4 nodes de log no Premium | Chain completa no log |
| **4** | 3 nodes de log no Standard | Standard agora loga |
| **5** | ~10 nodes nos sub-workflows | Cada workflow logando |
| **6** | Validacao + auditoria de seguranca | Zero tokens vazados |
| **7** | Pagina no dashboard (futura) | Visual Apple-style |

**Principios inegociaveis:**
- CAMPOS EXPLICITOS — nunca `JSON.stringify($json)` completo
- ZERO tokens/keys/secrets nos logs
- Apenas ADICIONAR nodes, nunca alterar existentes
- Um workflow por vez, checkpoint entre cada fase

---

*Plano v2 gerado pelo squad auditor-real — Argus*
