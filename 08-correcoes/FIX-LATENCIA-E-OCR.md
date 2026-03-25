# FIX — Latência (nullms) + OCR não aparece no site

## Problema 1: Latência sempre null

O campo `duration_ms` nunca é preenchido nos nodes N8N porque os logs rodam em **paralelo** — não sabem quanto tempo a ação levou.

### Solução: calcular no FRONTEND

A latência pode ser calculada pela diferença de timestamps entre `message_received` e o último evento da interação (`ai_response` ou `action_executed`). Os timestamps já existem no banco.

**No código JS do site, na função `groupIntoInteractions`:**

```javascript
// Dentro do loop, após agrupar os eventos:
if (current) {
    // Calcular latência
    const firstTs = new Date(current.events[0].created_at).getTime();
    const lastTs = new Date(current.events[current.events.length - 1].created_at).getTime();
    current.duration_ms = lastTs - firstTs;
}
```

**Ao renderizar:**
```javascript
// No card, mostrar:
log.duration_ms > 0
    ? (log.duration_ms / 1000).toFixed(1) + 's'
    : null
```

**Dados reais (calculados pelos timestamps existentes):**
- Média de latência: **9.0 segundos**
- Range: 6.9s — 13.2s

---

## Problema 2: OCR de imagens não aparece no site

### Os dados EXISTEM no banco

O campo `extracted_data` está preenchido para imagens:
```json
{
    "text": "DANCA LUCO\n\nSem ego\nSem ego\n...",
    "pages": 1
}
```

### O site NÃO mostra `extracted_data`

O componente `ActivityCard` (e o `groupIntoInteractions`) não lê o campo `extracted_data`. Só lê `transcription_text` (áudio).

### Correção no `groupIntoInteractions`:

```javascript
// Dentro do loop, adicionar:
if (log.event_type === 'transcription' && log.message_type === 'image') {
    current.extracted_data = log.extracted_data;
    current.message_type = 'image';
}
if (log.event_type === 'transcription' && log.message_type === 'document') {
    current.extracted_data = log.extracted_data;
    current.message_type = 'document';
}
```

### Correção no `ActivityCard` / renderização:

```javascript
// Após mostrar a transcrição de áudio, adicionar:

// OCR de imagem
log.extracted_data && log.message_type === 'image' &&
    e('div', { className: 'bubble-ocr' },
        '🖼️ Imagem recebida',
        e('div', { className: 'ocr-text' },
            typeof log.extracted_data === 'string'
                ? JSON.parse(log.extracted_data).text
                : log.extracted_data.text
        )
    ),

// OCR de PDF
log.extracted_data && log.message_type === 'document' &&
    e('div', { className: 'bubble-ocr' },
        '📄 PDF recebido',
        e('div', { className: 'ocr-text' },
            typeof log.extracted_data === 'string'
                ? JSON.parse(log.extracted_data).text
                : log.extracted_data.text
        )
    ),
```

### CSS para OCR:

```css
.bubble-ocr {
    align-self: flex-start;
    background: hsla(222, 47%, 12%, 0.6);
    border: 1px solid hsla(210, 40%, 98%, 0.06);
    border-radius: 16px;
    padding: 12px 16px;
    max-width: 80%;
    font-size: 0.88rem;
}

.ocr-text {
    margin-top: 8px;
    padding: 10px;
    background: hsla(222, 47%, 6%, 0.8);
    border-radius: 10px;
    font-size: 0.78rem;
    color: hsl(215, 20%, 60%);
    font-family: 'SF Mono', 'JetBrains Mono', monospace;
    white-space: pre-wrap;
    max-height: 150px;
    overflow-y: auto;
    line-height: 1.4;
}
```

---

## Problema 3: "[midia]" em vez de tipo correto

Quando o user manda áudio, o campo `user_message` mostra `[midia]` porque a expression no Main tenta pegar `text.body` que não existe para áudio.

### Correção no `ActivityCard`:

```javascript
// Em vez de mostrar log.user_message direto:
function getUserMessageDisplay(log) {
    if (log.message_type === 'audio') return '🎤 Mensagem de áudio';
    if (log.message_type === 'image') return '🖼️ Imagem enviada';
    if (log.message_type === 'document') return '📄 Documento enviado';
    if (log.user_message === '[midia]') return '📎 Mídia';
    return log.user_message || '';
}
```

---

## Resumo das 3 correções (TODAS no frontend/site)

| # | Problema | Onde corrigir | O que fazer |
|---|---------|-------------|------------|
| 1 | Latência null | `groupIntoInteractions()` | Calcular diferença de timestamps |
| 2 | OCR não aparece | `groupIntoInteractions()` + `ActivityCard` + CSS | Ler `extracted_data`, mostrar com estilo |
| 3 | "[midia]" genérico | `ActivityCard` | Função `getUserMessageDisplay()` por message_type |

**Nenhuma dessas correções precisa mexer no N8N. São todas no site.**
