# CORREÇÃO URGENTE — Lógica de "Falha" no Site

## O problema

O site está mostrando logs com `status: "completed"` como **"Falha"**. Isso está errado. Os dados no banco estão corretos — `status = 'completed'`, `error_message = null`.

## Causa provável

O site está considerando campos `null` como falha. Exemplo: um registro de `classification` tem `ai_message = null` e `action_success = null` — porque esses campos **não se aplicam** a esse tipo de evento. Mas o código provavelmente faz algo tipo:

```javascript
// ERRADO — considera null como falha
const isFailed = !log.action_success || !log.ai_message;
```

## Correção

A lógica de sucesso/falha deve ser:

```javascript
// CORRETO — só é falha se explicitamente falhou
function getLogStatus(log) {
    // Se tem erro explícito → falha
    if (log.error_message) return 'error';

    // Se tem action_success definido → usar esse valor
    if (log.action_success === false) return 'error';
    if (log.action_success === true) return 'success';

    // Se status é 'error' → falha
    if (log.status === 'error') return 'error';

    // Tudo mais → sucesso (campos null são normais, não são falha)
    return 'success';
}
```

## Regra de ouro

**`null` NÃO é falha.** Cada `event_type` preenche campos diferentes:

| event_type | Campos preenchidos | Campos que ficam null (NORMAL) |
|-----------|-------------------|-------------------------------|
| `message_received` | user_phone, user_message, message_type | ai_message, branch, action_success, action_type |
| `message_routed` | user_phone, user_id, user_plan, routed_to | ai_message, branch, action_success |
| `classification` | user_phone, user_message, branch | ai_message, action_success, action_type |
| `ai_response` | ai_message, ai_action, ai_tools_called | branch, action_type, action_success |
| `action_executed` | action_type, action_input, action_success | ai_message, branch |
| `transcription` | transcription_text | tudo exceto phone e source_workflow |

**Só marcar como falha quando:**
- `error_message IS NOT NULL`
- `action_success = false`
- `status = 'error'`

---

# INSTRUÇÃO DE DESIGN — Cor primária + Dark Mode

## Cor primária do Total Assistente

Trocar a cor primária de azul escuro para **#0057FF** (azul Total Assistente).

### CSS — Substituir no `:root`

```css
:root {
    /* COR PRIMÁRIA — Azul Total Assistente */
    --primary: 217 100% 50%;        /* #0057FF */
    --primary-light: 217 100% 60%;  /* mais claro para hover */
    --primary-dark: 217 100% 40%;   /* mais escuro para active */
    --secondary: 217 80% 55%;

    /* DARK MODE ONLY — sem light mode */
    --background: 222 47% 4%;
    --foreground: 210 40% 98%;
    --card: 222 47% 8%;
    --card-foreground: 210 40% 98%;
    --muted: 217.2 32.6% 12%;
    --muted-foreground: 215 20.2% 65.1%;
    --glass-bg: hsla(222, 47%, 4%, 0.8);
    --glass-border: hsla(210, 40%, 98%, 0.12);

    /* Negative/Error */
    --negative: 0 84% 60%;

    /* Radius & Spacing */
    --radius-3xl: 24px;
    --radius-full: 9999px;
    --duration-500: 500ms;
}
```

### O que muda visualmente

| Elemento | Antes | Depois |
|----------|-------|--------|
| Navbar botão ativo | Azul escuro (#1a2744) | **#0057FF** |
| Links/botões primários | Azul escuro | **#0057FF** |
| Badges selecionados | Azul escuro | **#0057FF** com 20% opacity |
| Focus ring | Azul escuro | **#0057FF** |
| Charts accent | Azul escuro | **#0057FF** |

### Remover light mode completamente

1. Deletar o bloco `[data-theme='dark'] { ... }` do CSS
2. Mover as variáveis dark direto pro `:root` (como mostrado acima)
3. No `app.js`: remover state `theme`, remover `toggleTheme`, remover botão Sun/Moon
4. Forçar no mount:
```javascript
useEffect(() => {
    document.documentElement.setAttribute('data-theme', 'dark');
}, []);
```

---

## Resumo das 2 correções

| # | O que | Prioridade |
|---|-------|-----------|
| 1 | Corrigir lógica de falha — `null` NÃO é erro | **URGENTE** |
| 2 | Cor primária #0057FF + dark mode only | Design |
