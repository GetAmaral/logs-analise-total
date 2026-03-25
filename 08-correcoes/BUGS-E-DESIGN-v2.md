# BUGS + DESIGN v2 — Lista completa de correções

**Repo:** github.com/luizporto-ai/analise-total
**Data:** 2026-03-25
**Prioridade:** URGENTE

---

## BUG 1 — Mensagem da IA NÃO aparece no Activity Log

### Problema
A linha 710 do `app.js` faz:
```javascript
log.ai_message && e('div', { className: 'card-msg-ai' }, log.ai_message)
```

Mas os cards mostram CADA ROW da tabela individualmente. O `ai_message` só existe na row com `event_type = 'ai_response'`. As outras rows (message_received, classification, etc.) não têm `ai_message` — por isso não aparece.

### Solução
**NÃO mostrar cada row como um card.** Agrupar as rows em "interações". Cada interação = 1 mensagem do user + 1 resposta da IA.

**Trocar a query na função `fetchMessages` (linha 619-636):**

```javascript
async function fetchMessages(phone) {
    setLoadingMsgs(true);
    try {
        const { data, error } = await supabaseDB2
            .from('v_exec_log_with_user')
            .select('*')
            .eq('user_phone', phone)
            .order('created_at', { ascending: true })  // ← CORRIGIDO: ascending true
            .limit(200);

        if (error) throw error;

        // AGRUPAR em interações
        const interactions = [];
        let current = null;

        for (const log of data) {
            if (log.event_type === 'message_received') {
                if (current) interactions.push(current);
                current = {
                    id: log.id,
                    timestamp: log.created_at,
                    user_message: log.user_message,
                    message_type: log.message_type || 'text',
                    user_name: log.user_name,
                    source_workflow: log.source_workflow,
                    // Campos que serão preenchidos por eventos seguintes:
                    routed_to: null,
                    transcription: null,
                    branch: null,
                    ai_message: null,
                    ai_action: null,
                    ai_tools: null,
                    action_type: null,
                    action_input: null,
                    action_success: null,
                    error_message: null,
                    duration_ms: null,
                    events: [log]
                };
            } else if (current) {
                current.events.push(log);
                if (log.event_type === 'message_routed') current.routed_to = log.routed_to;
                if (log.event_type === 'transcription') current.transcription = log.transcription_text;
                if (log.event_type === 'classification') current.branch = log.branch;
                if (log.event_type === 'ai_response') {
                    current.ai_message = log.ai_message;
                    current.ai_action = log.ai_action;
                    current.ai_tools = log.ai_tools_called;
                }
                if (log.event_type === 'action_executed') {
                    current.action_type = log.action_type;
                    current.action_input = log.action_input;
                    current.action_success = log.action_success;
                    current.error_message = log.error_message;
                    current.duration_ms = log.duration_ms;
                }
            }
        }
        if (current) interactions.push(current);

        setMessages(interactions);
    } catch (err) {
        console.error(err);
    } finally {
        setLoadingMsgs(false);
    }
}
```

**Trocar o componente `ActivityCard` (linha 702-718) por:**

```javascript
function ActivityCard({ log, onClick }) {
    const hasError = log.error_message || log.action_success === false;
    const time = new Date(log.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    const date = new Date(log.timestamp).toLocaleDateString('pt-BR');

    return e('div', { className: `activity-card ${hasError ? 'card-error' : ''}`, onClick },
        // Header: hora + workflow badge
        e('div', { className: 'card-top' },
            e('span', { className: 'card-time' }, date + ' ' + time),
            e('div', { style: { display: 'flex', gap: '6px' } },
                e('span', { className: 'badge badge-' + log.source_workflow }, log.source_workflow),
                log.branch && e('span', { className: 'badge badge-branch' }, log.branch)
            )
        ),

        // Mensagem do user (SEMPRE aparece se existe)
        log.user_message && e('div', { className: 'bubble-user' },
            log.message_type === 'audio' ? '🎤 Áudio' : log.user_message
        ),

        // Transcrição (se áudio)
        log.transcription && e('div', { className: 'bubble-transcription' },
            '📝 ', log.transcription
        ),

        // Resposta da IA (AGORA APARECE!)
        log.ai_message && e('div', { className: 'bubble-ai' },
            log.ai_message
        ),

        // Se NÃO tem ai_message ainda (pode estar processando)
        !log.ai_message && log.branch && e('div', { className: 'bubble-ai bubble-pending' },
            '⏳ Processando...'
        ),

        // Footer: ação + status + tempo
        e('div', { className: 'card-footer' },
            log.action_type && e('span', { className: 'badge badge-action' }, log.action_type),
            !hasError && e('span', { className: 'badge badge-ok' }, '✓ OK'),
            hasError && e('span', { className: 'badge badge-fail' }, '✗ ', log.error_message || 'Falha'),
            log.duration_ms && e('span', { className: 'card-duration' }, (log.duration_ms / 1000).toFixed(1) + 's')
        )
    );
}
```

---

## BUG 2 — Ordem das mensagens invertida

### Problema
Linha 626: `ascending: false` — mostra mais novas em cima, mais velhas embaixo. Conversa fica ao contrário.

### Solução
Já corrigido na query acima: `ascending: true`. Mensagens mais antigas em cima, mais novas embaixo (como WhatsApp).

---

## BUG 3 — Sem scroll na área de conversas

### Problema
O `chat-timeline` tem `overflow-y: auto` (linha 1244 do CSS), mas o container pai `activity-content` não tem altura definida corretamente.

### Solução
Trocar no CSS:

```css
.activity-content {
    display: flex;
    flex-direction: column;
    height: 100%;
    overflow: hidden;  /* ← ADICIONAR: impede que o pai expanda */
}

.chat-timeline {
    flex: 1;
    overflow-y: auto;  /* ← já tem, mas agora funciona porque o pai limita */
    padding: 24px;
    display: flex;
    flex-direction: column;
    gap: 16px;
    scroll-behavior: smooth;
}
```

E adicionar auto-scroll para o final:

```javascript
// No componente ActivityLog, após setMessages:
const timelineRef = useRef(null);

useEffect(() => {
    if (timelineRef.current) {
        timelineRef.current.scrollTop = timelineRef.current.scrollHeight;
    }
}, [messages]);

// No render, trocar:
e('div', { className: 'chat-timeline', ref: timelineRef }, ...)
```

---

## BUG 4 — "Detalhes verdes" / cores erradas

### Problema
Os badges usam classes `badge-success` e `badge-error` mas NÃO existem no CSS. O navegador pode estar aplicando styles default ou herdados com verde.

### Solução — Adicionar ao `style.css`:

```css
/* ==============================
   BADGES — Activity Log
   ============================== */

.badge {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 3px 10px;
    border-radius: 9999px;
    font-size: 0.68rem;
    font-weight: 700;
    letter-spacing: 0.03em;
    text-transform: uppercase;
}

/* Workflow badges */
.badge-main       { background: hsla(215, 20%, 50%, 0.12); color: hsl(215, 20%, 65%); }
.badge-premium    { background: hsla(270, 60%, 60%, 0.12); color: hsl(270, 60%, 70%); }
.badge-financeiro { background: hsla(150, 60%, 50%, 0.12); color: hsl(150, 60%, 60%); }
.badge-calendar   { background: hsla(30, 80%, 55%, 0.12);  color: hsl(30, 80%, 65%); }
.badge-lembretes  { background: hsla(45, 80%, 55%, 0.12);  color: hsl(45, 80%, 65%); }
.badge-report     { background: hsla(190, 70%, 50%, 0.12); color: hsl(190, 70%, 60%); }
.badge-service_msg { background: hsla(280, 40%, 50%, 0.12); color: hsl(280, 40%, 65%); }

/* Branch badge */
.badge-branch {
    background: hsla(217, 100%, 50%, 0.1);
    color: #0057FF;
}

/* Action badge */
.badge-action {
    background: hsla(270, 60%, 60%, 0.1);
    color: hsl(270, 60%, 70%);
}

/* Status badges — SEM VERDE. Usa azul #0057FF para sucesso. */
.badge-ok {
    background: hsla(217, 100%, 50%, 0.1);
    color: #0057FF;
}

.badge-fail {
    background: hsla(0, 84%, 60%, 0.12);
    color: hsl(0, 84%, 65%);
}

/* Duration */
.card-duration {
    font-size: 0.7rem;
    opacity: 0.4;
    font-variant-numeric: tabular-nums;
}
```

**NOTA: Sucesso usa AZUL (#0057FF), não verde. Verde não combina com dark mode + #0057FF.**

---

## BUG 5 — Navbar não mudou

### Problema
A navbar foi alterada no código mas o visual ainda pode estar feio.

### Solução — CSS da navbar (confirmar que existe):

```css
.navbar-pill {
    position: fixed;
    top: 16px;
    left: 50%;
    transform: translateX(-50%);
    z-index: 100;
    padding: 8px 16px;
    border-radius: 9999px;
    background: hsla(222, 47%, 6%, 0.85);
    backdrop-filter: blur(32px);
    border: 1.5px solid hsla(210, 40%, 98%, 0.08);
    display: flex;
    align-items: center;
    gap: 4px;
}

.nav-btn {
    padding: 8px 16px;
    border-radius: 9999px;
    border: none;
    background: transparent;
    color: hsl(var(--muted-foreground));
    font-size: 0.82rem;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    white-space: nowrap;
}

.nav-btn:hover {
    color: hsl(var(--foreground));
    background: hsla(var(--foreground) / 0.05);
}

.nav-btn.active {
    background: #0057FF;
    color: white;
}

.logout-btn {
    opacity: 0.4;
    transition: opacity 0.2s;
}

.logout-btn:hover {
    opacity: 1;
}
```

---

## DESIGN — Bolhas estilo WhatsApp

### CSS completo das bolhas:

```css
/* Bolha do user (direita) */
.bubble-user {
    align-self: flex-end;
    background: #0057FF;
    color: white;
    padding: 10px 16px;
    border-radius: 18px 18px 4px 18px;
    font-size: 0.9rem;
    max-width: 80%;
    line-height: 1.45;
}

/* Bolha da IA (esquerda) */
.bubble-ai {
    align-self: flex-start;
    background: hsla(222, 47%, 12%, 0.8);
    border: 1px solid hsla(210, 40%, 98%, 0.06);
    color: hsl(210, 40%, 92%);
    padding: 10px 16px;
    border-radius: 18px 18px 18px 4px;
    font-size: 0.9rem;
    max-width: 80%;
    line-height: 1.45;
}

/* Processando */
.bubble-pending {
    opacity: 0.4;
    font-style: italic;
}

/* Transcrição */
.bubble-transcription {
    align-self: flex-start;
    font-size: 0.82rem;
    font-style: italic;
    color: hsl(215, 20%, 60%);
    padding: 8px 14px;
    background: hsla(222, 47%, 8%, 0.5);
    border-radius: 12px;
    max-width: 80%;
}

/* Card com erro */
.card-error {
    border-color: hsla(0, 84%, 60%, 0.2) !important;
}

.card-error .bubble-ai {
    background: hsla(0, 50%, 12%, 0.8);
    border-color: hsla(0, 84%, 60%, 0.2);
    color: hsl(0, 84%, 75%);
}
```

---

## DESIGN — Card do Activity Log (layout completo)

Cada card deve parecer isso:

```
┌────────────────────────────────────────────────┐
│  25/03/2026 10:32         [premium] [criar_gasto] │
│                                                │
│                    ┌──────────────────────────┐ │
│                    │ registra 45 reais almoco │ │  ← azul #0057FF
│                    └──────────────────────────┘ │
│                                                │
│  ┌──────────────────────────────────────────┐  │
│  │ ✅ Registrei seu gasto de R$45,00 na     │  │  ← glass dark
│  │ categoria Alimentação!                   │  │
│  └──────────────────────────────────────────┘  │
│                                                │
│  [registrar_gasto] [✓ OK] 2.1s                │
└────────────────────────────────────────────────┘
```

---

## RESUMO DAS CORREÇÕES

| # | Bug | Onde corrigir | Prioridade |
|---|-----|-------------|-----------|
| 1 | IA não aparece | `app.js` — agrupar eventos em interações | **CRÍTICO** |
| 2 | Ordem invertida | `app.js` linha 626 — `ascending: true` | **CRÍTICO** |
| 3 | Sem scroll | `style.css` — `overflow: hidden` no pai | **ALTO** |
| 4 | Cores verdes | `style.css` — adicionar classes de badges com azul #0057FF | **ALTO** |
| 5 | Navbar feia | `style.css` — confirmar estilos pill + active azul | **MÉDIO** |
| 6 | Bolhas WhatsApp | `style.css` — adicionar `.bubble-user`, `.bubble-ai` | **ALTO** |

**Ordem de execução: 1 → 2 → 3 → 6 → 4 → 5**
