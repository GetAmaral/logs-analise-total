# DESIGN — Chat WhatsApp Reconstruído via execution_log

## É possível?

SIM. O `execution_log` captura TUDO que precisa pra reconstruir a conversa completa.

## Dados disponíveis:

| O que | Campo no execution_log | Exemplo |
|-------|----------------------|---------|
| Mensagem do user | `user_message` | "registra 45 reais almoco" |
| Nome do user | `user_name` (via v_exec_log_with_user) | "Luiz Felipe" |
| Tipo (texto/áudio/img) | `message_type` | "audio" |
| Transcrição do áudio | `transcription_text` | "agendar dentista amanhã" |
| Resposta da IA | `ai_message` | "Registrei R$45 em Alimentação!" |
| Ação executada | `ai_action` | "registrar_gasto" |
| Tools chamadas | `ai_tools_called` | JSON com params |
| Sucesso/falha | `action_success` | true/false |
| Erro | `error_message` | "timeout" |
| Hora | `created_at` | timestamp |
| Branch | `branch` | "criar_gasto" |

---

## 2 MODOS DE VISUALIZAÇÃO

### MODO CLEAN (💬) — WhatsApp puro

Parece WhatsApp de verdade. Só bolhas de mensagem.

**Bolha DIREITA (azul #0057FF)** = mensagem do usuário
**Bolha ESQUERDA (glass dark)** = resposta da IA

#### Tipos de bolha:

**Texto normal:**
```
┌──────────────────┐
│ registra 45      │   ← user (direita, azul)
│ reais almoco     │
│          10:32 ✓ │
└──────────────────┘

┌────────────────────────┐
│ ✅ Registrei seu gasto  │   ← IA (esquerda, glass)
│ de R$45 em Alimentação!│
│               10:34 ✓✓ │
└────────────────────────┘
```

**Áudio (mostra transcrição):**
```
┌──────────────────┐
│ 🎤 0:12          │   ← user mandou áudio
│          10:40 ✓ │
└──────────────────┘

┌────────────────────────┐
│ 📝 Transcrição:        │   ← IA transcreve + responde
│ "agendar dentista      │
│ amanhã 14h"            │
│                        │
│ ✅ Agendei consulta no  │
│ dentista amanhã 14:00! │
│               10:42 ✓✓ │
└────────────────────────┘
```

**Relatório (mostra como arquivo):**
```
┌────────────────────────────┐
│ 📄 Relatório Mensal        │   ← IA enviou relatório
│ ┌────────────────────────┐ │
│ │ 📊 relatorio-marco.pdf │ │
│ │ PDF · Via WhatsApp     │ │
│ └────────────────────────┘ │
│                  11:17 ✓✓  │
└────────────────────────────┘
```

**Exclusão:**
```
┌────────────────────────────┐
│ 🗑️ Gasto excluído!         │
│ iFood · R$54,00            │
│                  11:20 ✓✓  │
└────────────────────────────┘
```

**Erro (bolha com borda vermelha):**
```
┌────────────────────────────┐
│ ❌ Não consegui excluir.    │
│ Erro: timeout na API       │
│                  11:22 ✗   │
└────────────────────────────┘
```

---

### MODO PRO (⚙) — WhatsApp + Flow técnico

Igual ao Clean, mas cada bolha da IA tem um **mini-badge expandível** embaixo.

**Fechado:**
```
┌────────────────────────────┐
│ ✅ Registrei R$45 em        │
│ Alimentação!               │
│                  10:34 ✓✓  │
│                            │
│ ┌─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┐  │
│   📊 criar_gasto · 2.1s ✓  │   ← clicar pra expandir
│ └─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┘  │
└────────────────────────────┘
```

**Expandido (clicou no badge):**
```
┌────────────────────────────────────────┐
│  FLUXO COMPLETO              10:32-34  │
│                                        │
│  ① Recebida · text · 10:32            │
│     "registra 45 reais almoco"         │
│                                        │
│  ② Roteada → premium · 10:32          │
│                                        │
│  ③ Classificação: criar_gasto · 10:33 │
│                                        │
│  ④ IA respondeu · 10:34               │
│     Ação: registrar_gasto              │
│     Tool: registrar_financeiros        │
│     Params:                            │
│       { nome: "Almoco",                │
│         valor: 45,                     │
│         categoria: "Alimentação" }     │
│                                        │
│  ⑤ Ação executada · ✓ sucesso · 2.1s  │
│                                        │
│  ─────────────────────────────────     │
│  Tempo total: 2.1s                     │
│  Workflow: premium                     │
│  IDs: 28577b41, cc076b3c...           │
└────────────────────────────────────────┘
```

---

## TOGGLE

Botão no header do chat:

```
[💬 Clean]  ←→  [⚙ Pro]
```

- Clean = só mensagens, WhatsApp puro (default)
- Pro = mensagens + badges + flow expandível

---

## COMO MONTAR A CONVERSA (QUERY + LÓGICA)

### Query — busca TUDO de um usuário, ordenado:

```javascript
const { data } = await supabaseDB2
    .from('v_exec_log_with_user')
    .select('*')
    .eq('user_phone', selectedPhone)
    .not('user_phone', 'is', null)
    .order('created_at', { ascending: true });
```

### Agrupamento — junta eventos em "interações":

Cada `message_received` inicia uma nova interação. Os eventos seguintes (classification, ai_response, action_executed) pertencem a ela.

```javascript
function groupIntoInteractions(logs) {
    const interactions = [];
    let current = null;

    for (const log of logs) {
        if (log.event_type === 'message_received') {
            // Nova interação
            if (current) interactions.push(current);
            current = {
                id: log.id,
                user_message: log.user_message,
                message_type: log.message_type,
                timestamp: log.created_at,
                user_name: log.user_name,
                events: [log],
                // Campos que serão preenchidos pelos eventos seguintes:
                transcription: null,
                branch: null,
                ai_message: null,
                ai_action: null,
                ai_tools: null,
                ai_full_response: null,
                action_type: null,
                action_input: null,
                action_success: null,
                error_message: null,
                routed_to: null
            };
        } else if (current) {
            current.events.push(log);

            if (log.event_type === 'message_routed') {
                current.routed_to = log.routed_to;
            }
            if (log.event_type === 'transcription') {
                current.transcription = log.transcription_text;
            }
            if (log.event_type === 'classification') {
                current.branch = log.branch;
            }
            if (log.event_type === 'ai_response') {
                current.ai_message = log.ai_message;
                current.ai_action = log.ai_action;
                current.ai_tools = log.ai_tools_called;
                current.ai_full_response = log.ai_full_response;
            }
            if (log.event_type === 'action_executed') {
                current.action_type = log.action_type;
                current.action_input = log.action_input;
                current.action_success = log.action_success;
                current.error_message = log.error_message;
            }
        }
    }
    if (current) interactions.push(current);
    return interactions;
}
```

### Renderizar cada interação como bolhas:

```javascript
function renderInteraction(interaction, mode) {
    const time = formatTime(interaction.timestamp);
    const hasError = interaction.error_message || interaction.action_success === false;

    // BOLHA DO USER (direita)
    let userBubble;
    if (interaction.message_type === 'audio') {
        userBubble = audioBubble(time);
    } else {
        userBubble = textBubble(interaction.user_message, time, 'user');
    }

    // BOLHA DA IA (esquerda)
    let aiBubble;

    if (interaction.message_type === 'audio' && interaction.transcription) {
        // Áudio: mostrar transcrição + resposta
        aiBubble = transcriptionBubble(
            interaction.transcription,
            interaction.ai_message,
            time
        );
    } else if (interaction.ai_action === 'gerar_relatorio') {
        // Relatório: mostrar como arquivo
        aiBubble = fileBubble('Relatório', 'relatorio.pdf', time);
    } else if (interaction.action_type && interaction.action_type.includes('excluir')) {
        // Exclusão: mostrar com ícone lixeira
        aiBubble = deleteBubble(interaction.ai_message, time, hasError);
    } else if (hasError) {
        // Erro: bolha vermelha
        aiBubble = errorBubble(interaction.ai_message, interaction.error_message, time);
    } else {
        // Normal: texto da IA
        aiBubble = textBubble(interaction.ai_message || 'Processando...', time, 'ai');
    }

    // MODO PRO: adicionar badge + flow expandível
    let flowBadge = null;
    if (mode === 'pro' && interaction.branch) {
        flowBadge = expandableFlow(interaction);
    }

    return { userBubble, aiBubble, flowBadge };
}
```

---

## CSS DAS BOLHAS

```css
/* Container do chat */
.whatsapp-chat {
    display: flex;
    flex-direction: column;
    padding: 20px;
    overflow-y: auto;
    height: calc(100vh - 120px);
    gap: 4px;
}

/* Bolha base */
.bubble {
    max-width: 75%;
    padding: 10px 14px;
    border-radius: 16px;
    font-size: 0.9rem;
    line-height: 1.45;
    position: relative;
    animation: slideUp 0.2s ease;
}

/* User (direita) */
.bubble-user {
    align-self: flex-end;
    background: #0057FF;
    color: white;
    border-bottom-right-radius: 4px;
}

/* IA (esquerda) */
.bubble-ai {
    align-self: flex-start;
    background: hsla(222, 47%, 10%, 0.8);
    backdrop-filter: blur(8px);
    border: 1px solid hsla(210, 40%, 98%, 0.06);
    color: hsl(210, 40%, 95%);
    border-bottom-left-radius: 4px;
}

/* Erro (esquerda, borda vermelha) */
.bubble-error {
    align-self: flex-start;
    background: hsla(0, 50%, 10%, 0.8);
    border: 1px solid hsla(0, 84%, 60%, 0.3);
    color: hsl(0, 84%, 75%);
    border-bottom-left-radius: 4px;
}

/* Timestamp dentro da bolha */
.bubble-time {
    font-size: 0.68rem;
    opacity: 0.6;
    text-align: right;
    margin-top: 4px;
}

/* Áudio */
.bubble-audio {
    display: flex;
    align-items: center;
    gap: 10px;
}

.bubble-audio-icon {
    width: 36px;
    height: 36px;
    border-radius: 50%;
    background: hsla(210, 40%, 98%, 0.15);
    display: flex;
    align-items: center;
    justify-content: center;
}

.bubble-audio-wave {
    flex: 1;
    height: 24px;
    background: linear-gradient(90deg,
        hsla(210, 40%, 98%, 0.2) 2px, transparent 2px) 0/6px 100%;
}

/* Arquivo (relatório) */
.bubble-file {
    background: hsla(222, 47%, 12%, 0.8);
    border: 1px solid hsla(210, 40%, 98%, 0.08);
    border-radius: 12px;
    padding: 12px;
    margin: 8px 0;
    display: flex;
    align-items: center;
    gap: 12px;
}

.bubble-file-icon {
    width: 40px;
    height: 40px;
    border-radius: 8px;
    background: hsla(0, 84%, 60%, 0.15);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 1.2rem;
}

.bubble-file-info {
    font-size: 0.82rem;
}

.bubble-file-name {
    font-weight: 600;
    color: hsl(210, 40%, 95%);
}

.bubble-file-meta {
    font-size: 0.72rem;
    color: hsl(215, 20%, 55%);
}

/* Transcrição */
.bubble-transcription {
    font-size: 0.82rem;
    font-style: italic;
    color: hsl(215, 20%, 65%);
    padding: 8px 12px;
    background: hsla(222, 47%, 6%, 0.5);
    border-radius: 10px;
    margin-bottom: 8px;
}

/* Badge expandível (modo PRO) */
.flow-badge {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 4px 12px;
    border-radius: 9999px;
    font-size: 0.7rem;
    font-weight: 600;
    background: hsla(210, 40%, 98%, 0.06);
    border: 1px solid hsla(210, 40%, 98%, 0.08);
    color: hsl(215, 20%, 60%);
    cursor: pointer;
    transition: all 0.2s;
    margin-top: 8px;
}

.flow-badge:hover {
    background: hsla(217, 100%, 50%, 0.1);
    border-color: #0057FF;
    color: #0057FF;
}

/* Flow expandido */
.flow-expanded {
    background: hsla(222, 47%, 6%, 0.9);
    backdrop-filter: blur(16px);
    border: 1px solid hsla(210, 40%, 98%, 0.08);
    border-radius: 16px;
    padding: 20px;
    margin-top: 8px;
    font-size: 0.82rem;
    animation: slideUp 0.3s ease;
}

.flow-step {
    display: flex;
    gap: 12px;
    padding: 8px 0;
    border-bottom: 1px solid hsla(210, 40%, 98%, 0.04);
}

.flow-step:last-child {
    border-bottom: none;
}

.flow-step-number {
    width: 24px;
    height: 24px;
    border-radius: 50%;
    background: hsla(217, 100%, 50%, 0.15);
    color: #0057FF;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 0.72rem;
    font-weight: 700;
    flex-shrink: 0;
}

.flow-step-content {
    flex: 1;
}

.flow-step-label {
    font-weight: 600;
    color: hsl(210, 40%, 90%);
}

.flow-step-detail {
    color: hsl(215, 20%, 55%);
    font-size: 0.78rem;
    margin-top: 2px;
}

.flow-json {
    background: hsla(222, 47%, 4%, 0.8);
    border-radius: 8px;
    padding: 10px;
    font-family: 'SF Mono', 'JetBrains Mono', monospace;
    font-size: 0.72rem;
    color: hsl(215, 20%, 60%);
    white-space: pre-wrap;
    margin-top: 6px;
}
```

---

## SUBSTITUI O LOG ANTIGO

Esta tela substitui completamente o `UserLog` atual que lê do DB1 (`log_users_messages`). O novo lê do DB2 (`execution_log` via `v_exec_log_with_user`), que é muito mais completo.

**Manter o antigo como fallback** caso o execution_log ainda não tenha dados históricos de antes de 25/03/2026.
