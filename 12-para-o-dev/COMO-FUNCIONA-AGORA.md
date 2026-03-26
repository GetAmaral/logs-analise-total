# COMO O SISTEMA DE LOGS FUNCIONA AGORA — Guia para o Dev

**Data:** 2026-03-26
**Status:** Sistema de logs completo e funcionando em produção

---

## 1. VISÃO GERAL

Cada mensagem que chega no WhatsApp gera um **trace_id** único que acompanha a mensagem por **todos os workflows**. A tabela `execution_log` no Supabase DB2 (principal) captura cada etapa.

```
User manda "registra 50 reais farmacia"
    │
    ▼
  tr_1774537144866_v7b7tmd1
    │
    ├── message_received    (main)      → "registra 50 reais farmacia"
    ├── message_routed      (main)      → premium
    ├── classification      (premium)   → branch: criar_gasto
    ├── ai_response         (premium)   → "Registrei R$50 em Saúde!"
    ├── action_executed     (premium)   → registrar_gasto → {nome, valor, categoria}
    └── gasto.created       (financeiro)→ registro no banco
```

**Todas as rows têm o mesmo `trace_id`.** Uma query mostra a jornada inteira.

---

## 2. BANCO DE DADOS

### Conexão

```javascript
// JÁ EXISTE no app.js — usar supabaseDB2 para TUDO novo
const supabaseDB2 = createClient(
    'https://ldbdtakddxznfridsarn.supabase.co',
    'SERVICE_ROLE_KEY'
);
```

### Tabela: `execution_log`

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `id` | UUID | PK auto-gerado |
| `trace_id` | TEXT | **ID único por mensagem** — mesmo valor em todas as etapas |
| `interaction_id` | UUID | NÃO USAR — cada row gera UUID diferente (legado) |
| `user_phone` | TEXT | Telefone WhatsApp |
| `user_id` | TEXT | UUID do user no profiles |
| `user_plan` | TEXT | premium/free |
| `user_message` | TEXT | Mensagem que o user mandou |
| `message_type` | TEXT | text/audio/image/document/interactive |
| `transcription_text` | TEXT | Transcrição de áudio (Whisper) |
| `summary_text` | TEXT | Resumo de áudio (GPT-4.1-mini) |
| `extracted_data` | JSONB | Texto extraído de imagem/PDF (Mistral OCR) |
| `branch` | TEXT | Classificação: criar_gasto, criar_evento_agenda, padrao, etc. |
| `ai_message` | TEXT | Resposta da IA ao user |
| `ai_action` | TEXT | Ação que a IA decidiu: registrar_gasto, criar_evento, padrao |
| `ai_tools_called` | JSONB | Tools chamadas (params da ação) |
| `ai_full_response` | JSONB | JSON completo do parsed_output |
| `action_type` | TEXT | Tipo de ação executada |
| `action_input` | JSONB | Dados enviados ao webhook (nome, valor, categoria...) |
| `action_output` | JSONB | Resposta do webhook |
| `action_success` | BOOLEAN | true/false — detecta erros reais |
| `error_message` | TEXT | Mensagem de erro (quando action_success=false) |
| `source_workflow` | TEXT | main/premium/financeiro/calendar/lembretes/report/service_msg |
| `event_type` | TEXT | Tipo de evento (ver lista abaixo) |
| `status` | TEXT | completed/error |
| `duration_ms` | INTEGER | Sempre null — **calcular no frontend** |
| `routed_to` | TEXT | premium (quando event_type = message_routed) |
| `created_at` | TIMESTAMPTZ | Timestamp |

### View: `v_exec_log_with_user`

Faz JOIN automático com `profiles` — traz nome e email do user.

```javascript
const { data } = await supabaseDB2
    .from('v_exec_log_with_user')
    .select('*')
    .eq('user_phone', phone)
    .order('created_at', { ascending: true });
```

Campos extras da view:
- `user_name` — nome do user (ou "Desconhecido")
- `user_email` — email
- `resolved_plan` — plano

---

## 3. TIPOS DE EVENTO (event_type)

| event_type | Quando | Campos preenchidos |
|-----------|--------|-------------------|
| `message_received` | Mensagem chegou no WhatsApp | user_phone, user_message, message_type |
| `message_routed` | Main enviou pro Premium | user_phone, user_id, user_plan, routed_to |
| `classification` | IA classificou a intenção | user_message, branch |
| `ai_response` | IA respondeu | ai_message, ai_action, ai_tools_called, ai_full_response |
| `action_executed` | Ação executada (gasto, evento, etc.) | action_type, action_input, action_success |
| `transcription` | Áudio transcrito ou imagem/PDF extraído | transcription_text OU extracted_data |
| `audio_summary` | Resumo de áudio | summary_text |

### Tipos de action_type

| action_type | Significado |
|------------|-------------|
| `registrar_gasto` | Registrou gasto |
| `criar_evento` | Criou evento na agenda |
| `evento_recorrente` | Criou evento recorrente |
| `padrao` | Conversa normal (sem ação) |
| `excluir_evento_botao` | Excluiu evento via botão |
| `excluir_financeiro_botao` | Excluiu gasto via botão |
| `excluir_recorrente_botao` | Excluiu recorrente via botão |
| `gasto.created` | Sub-workflow Financeiro criou gasto |
| `gasto.updated` | Sub-workflow Financeiro editou gasto |
| `gasto.deleted` | Sub-workflow Financeiro excluiu gasto |
| `evento.updated` | Sub-workflow Calendar editou evento |
| `evento.deleted` | Sub-workflow Calendar excluiu evento |
| `google.synced` | Sub-workflow Calendar sincronizou Google |
| `report.sent` | Sub-workflow Report enviou PDF |
| `reengagement.sent` | Sub-workflow Service enviou reengajamento |
| `onboarding.new_user` | Novo user no onboarding |
| `onboarding.stg_change` | Mudança de estágio onboarding |
| `onboarding.otp_verified` | OTP verificado com sucesso |
| `onboarding.otp_failed` | OTP incorreto/expirado |
| `plano.inativo` | User com plano expirado |

---

## 4. COMO AGRUPAR EM CONVERSAS (CHAT VIEW)

### Regra: agrupar por `trace_id`

Cada `trace_id` = 1 interação completa (mensagem do user → resposta da IA → ação).

```javascript
async function fetchConversation(phone) {
    const { data } = await supabaseDB2
        .from('v_exec_log_with_user')
        .select('*')
        .eq('user_phone', phone)
        .not('user_phone', 'is', null)
        .order('created_at', { ascending: true })
        .limit(500);

    return groupByTraceId(data);
}

function groupByTraceId(logs) {
    const groups = {};

    for (const log of logs) {
        const tid = log.trace_id || log.id; // fallback para logs sem trace
        if (!groups[tid]) {
            groups[tid] = {
                trace_id: tid,
                timestamp: log.created_at,
                user_phone: log.user_phone,
                user_name: log.user_name,
                events: [],
                // Consolidados:
                user_message: null,
                message_type: 'text',
                transcription: null,
                summary: null,
                extracted_data: null,
                branch: null,
                ai_message: null,
                ai_action: null,
                ai_tools: null,
                action_type: null,
                action_input: null,
                action_success: null,
                error_message: null,
                source_workflow: null
            };
        }

        const g = groups[tid];
        g.events.push(log);

        switch (log.event_type) {
            case 'message_received':
                g.user_message = log.user_message;
                g.message_type = log.message_type || 'text';
                g.timestamp = log.created_at;
                break;
            case 'message_routed':
                g.source_workflow = log.routed_to;
                break;
            case 'transcription':
                if (log.message_type === 'audio') g.transcription = log.transcription_text;
                if (log.message_type === 'image' || log.message_type === 'document') {
                    let ed = log.extracted_data;
                    if (typeof ed === 'string') try { ed = JSON.parse(ed); } catch(e) {}
                    g.extracted_data = ed;
                    g.message_type = log.message_type;
                }
                break;
            case 'audio_summary':
                g.summary = log.summary_text;
                break;
            case 'classification':
                g.branch = log.branch;
                break;
            case 'ai_response':
                g.ai_message = log.ai_message;
                g.ai_action = log.ai_action;
                g.ai_tools = log.ai_tools_called;
                break;
            case 'action_executed':
                g.action_type = log.action_type;
                g.action_input = log.action_input;
                g.action_success = log.action_success;
                g.error_message = log.error_message;
                g.source_workflow = log.source_workflow;
                break;
        }
    }

    // Calcular latência e converter para array
    return Object.values(groups).map(g => {
        const first = new Date(g.events[0].created_at).getTime();
        const last = new Date(g.events[g.events.length - 1].created_at).getTime();
        g.duration_ms = last - first;
        return g;
    });
}
```

---

## 5. COMO RENDERIZAR CADA INTERAÇÃO NO CHAT

Cada interação (agrupada por trace_id) vira **2 bolhas** no chat:

### Bolha do user (direita, azul #0057FF)

```javascript
function getUserBubbleContent(interaction) {
    switch (interaction.message_type) {
        case 'audio':
            return '🎤 Mensagem de áudio';
        case 'image':
            return '🖼️ Imagem enviada';
        case 'document':
            return '📄 Documento enviado';
        default:
            if (interaction.user_message === '[midia]') return '📎 Mídia';
            return interaction.user_message || '';
    }
}
```

### Bolha da IA (esquerda, glass dark)

```javascript
function getAiBubbleContent(interaction) {
    const parts = [];

    // Transcrição de áudio
    if (interaction.transcription) {
        parts.push({ type: 'transcription', text: interaction.transcription });
    }

    // OCR de imagem/PDF
    if (interaction.extracted_data) {
        const text = interaction.extracted_data.text || JSON.stringify(interaction.extracted_data);
        parts.push({
            type: 'ocr',
            label: interaction.message_type === 'image' ? '🖼️ Texto da imagem' : '📄 Texto do PDF',
            text: text
        });
    }

    // Resumo de áudio
    if (interaction.summary) {
        parts.push({ type: 'summary', text: interaction.summary });
    }

    // Resposta da IA
    if (interaction.ai_message) {
        parts.push({ type: 'ai_message', text: interaction.ai_message });
    }

    // Ação especial: relatório
    if (interaction.action_type === 'report.sent') {
        parts.push({ type: 'file', label: '📊 Relatório enviado', meta: 'PDF via WhatsApp' });
    }

    // Ação especial: exclusão
    if (interaction.action_type && interaction.action_type.includes('excluir')) {
        parts.push({ type: 'delete', text: interaction.ai_message || 'Item excluído' });
    }

    return parts;
}
```

### Badge expandível (modo Pro)

Abaixo da bolha da IA, mostrar badge com info da ação:

```javascript
function getActionBadge(interaction) {
    if (!interaction.branch && !interaction.action_type) return null;

    return {
        branch: interaction.branch,
        action: interaction.action_type,
        success: interaction.action_success !== false,
        error: interaction.error_message,
        duration: interaction.duration_ms > 0
            ? (interaction.duration_ms / 1000).toFixed(1) + 's'
            : null,
        workflow: interaction.source_workflow
    };
}
```

Ao clicar no badge, expandir inline mostrando `interaction.events` (todas as etapas numeradas ①②③④⑤).

---

## 6. COMO DETECTAR SUCESSO/FALHA

```javascript
function getStatus(interaction) {
    if (interaction.error_message) return 'error';
    if (interaction.action_success === false) return 'error';
    return 'success';
}
```

**`null` NÃO é falha.** Campos null são normais — cada etapa preenche campos diferentes.

---

## 7. SIDEBAR (lista de users)

```javascript
async function fetchUsers() {
    const { data } = await supabaseDB2
        .from('v_exec_log_with_user')
        .select('user_phone, user_name, user_message, resolved_plan, message_type, created_at')
        .not('user_phone', 'is', null)
        .order('created_at', { ascending: false })
        .limit(500);

    // Agrupar por phone — pegar o mais recente de cada
    const seen = new Map();
    data.forEach(item => {
        if (!seen.has(item.user_phone)) {
            seen.set(item.user_phone, item);
        }
    });
    return Array.from(seen.values());
}
```

Cada item na sidebar mostra:
- **Nome** (`user_name`)
- **Última mensagem** (`user_message` ou "🎤 Áudio" / "🖼️ Imagem" baseado em `message_type`)
- **Hora** (`created_at`)
- **Badge plano** (`resolved_plan`)

---

## 8. DETALHES DA INTERAÇÃO (ao clicar no badge ou no card)

Ao expandir, mostrar o fluxo completo numerado:

```javascript
function renderFlowDetail(interaction) {
    return interaction.events.map((event, i) => {
        const time = new Date(event.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });

        switch (event.event_type) {
            case 'message_received':
                return `① Recebida · ${event.message_type} · ${time}`;
            case 'message_routed':
                return `② Roteada → ${event.routed_to || 'premium'} · ${time}`;
            case 'transcription':
                return `③ Transcrição · ${time}`;
            case 'classification':
                return `④ Classificação: ${event.branch} · ${time}`;
            case 'ai_response':
                return `⑤ IA respondeu · ${time}`;
            case 'action_executed':
                const status = event.action_success === false ? '✗ erro' : '✓ ok';
                return `⑥ Ação: ${event.action_type} · ${status} · ${time}`;
        }
    });
}
```

E mostrar `action_input` formatado:

```javascript
function renderActionInput(interaction) {
    if (!interaction.action_input) return null;
    let input = interaction.action_input;
    if (typeof input === 'string') {
        try { input = JSON.parse(input); } catch(e) { return input; }
    }
    // Formatar como key: value
    return Object.entries(input)
        .filter(([k, v]) => v !== null && v !== '')
        .map(([k, v]) => `${k}: ${v}`)
        .join('\n');
}
```

---

## 9. TIPOS DE INTERAÇÃO ESPECIAIS

### Onboarding (user novo)

```
action_type = "onboarding.new_user"     → "Novo usuário"
action_type = "onboarding.stg_change"   → "Etapa do cadastro"
action_type = "onboarding.otp_verified" → "✅ Conta ativada"
action_type = "onboarding.otp_failed"   → "❌ Código inválido"
```

Mostrar na bolha da IA como sistema:
```
┌────────────────────────────────┐
│ 🔐 Onboarding                  │
│ Etapa: stg 2 → 3               │
│ Status: Código enviado          │
└────────────────────────────────┘
```

### Plano inativo

```
action_type = "plano.inativo" → bolha especial
```

```
┌────────────────────────────────┐
│ ⚠️ Plano expirado              │
│ User tentou usar mas plano     │
│ está inativo                   │
└────────────────────────────────┘
```

### Reengajamento (Service Message)

```
action_type = "reengagement.sent" → bolha do sistema
```

```
┌────────────────────────────────┐
│ 📩 Reengajamento               │
│ Mensagem automática enviada    │
│ (user inativo 24h)             │
└────────────────────────────────┘
```

---

## 10. QUERIES ÚTEIS

```javascript
// KPIs do dia
const { data } = await supabaseDB2.rpc('fn_exec_log_kpis', {
    p_start: new Date(new Date().setHours(0,0,0,0)).toISOString(),
    p_end: new Date().toISOString()
});

// Branch stats (donut chart)
const { data } = await supabaseDB2
    .from('v_exec_log_branch_stats')
    .select('*')
    .order('total', { ascending: false })
    .limit(10);

// Volume horário (line chart)
const { data } = await supabaseDB2
    .from('v_exec_log_hourly_volume')
    .select('*')
    .gte('hora', startDate.toISOString());

// Erros recentes
const { data } = await supabaseDB2
    .from('v_exec_log_recent_errors')
    .select('*')
    .limit(10);

// Trace completo de uma interação
const { data } = await supabaseDB2
    .from('execution_log')
    .select('*')
    .eq('trace_id', 'tr_xxxx')
    .order('created_at', { ascending: true });
```

---

## RESUMO

**Chave principal:** `trace_id` — agrupa por ele, não por `interaction_id`.

**Banco:** `supabaseDB2` → view `v_exec_log_with_user` (traz nome do user).

**Agrupamento:** `groupByTraceId()` — cada trace vira 1 interação com 2 bolhas no chat.

**Latência:** calcular no frontend: `último_evento.created_at - primeiro_evento.created_at`.

**Sucesso/falha:** só `error_message` ou `action_success=false`. Null = OK.

**Tipos especiais:** onboarding, plano inativo, reengajamento — bolhas de sistema diferenciadas.
