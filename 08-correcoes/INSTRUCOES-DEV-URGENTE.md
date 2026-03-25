# INSTRUÇÕES PARA O DEV — URGENTE

**Repo:** github.com/luizporto-ai/analise-total
**Arquivos:** `app.js` + `style.css`

---

## PROBLEMAS ATUAIS

1. **"Falha" aparecendo errado** — O site mostra campos `null` como falha. Null é NORMAL, não é erro.
2. **Mensagem da IA não aparece** — O node `ai_response` no N8N estava quebrando (já corrigido). Mas o site precisa da lógica certa pra ler.
3. **Design geral feio/inacabado** — Logs, chat simulador, detalhes, tudo precisa de polish.
4. **Light mode** — Remover. Só dark mode.
5. **Cor primária errada** — Trocar pra `#0057FF` (azul Total Assistente).

---

## CORREÇÃO 1 — Lógica de "Falha"

O site está lendo a tabela `execution_log` do Supabase PRINCIPAL (`ldbdtakddxznfridsarn`, variável `supabaseDB2` no código).

Cada registro tem um `event_type` que determina quais campos são preenchidos. **Campos null são NORMAIS, NÃO são falha.**

### Mapa de campos por event_type:

| event_type | user_message | branch | ai_message | ai_action | action_type | action_success |
|-----------|:---:|:---:|:---:|:---:|:---:|:---:|
| `message_received` | ✅ | ❌ null | ❌ null | ❌ null | ❌ null | ❌ null |
| `message_routed` | ❌ null | ❌ null | ❌ null | ❌ null | ❌ null | ❌ null |
| `transcription` | ❌ null | ❌ null | ❌ null | ❌ null | ❌ null | ❌ null |
| `classification` | ✅ | ✅ | ❌ null | ❌ null | ❌ null | ❌ null |
| `ai_response` | ❌ null | ❌ null | ✅ | ✅ | ❌ null | ❌ null |
| `action_executed` | ❌ null | ❌ null | ❌ null | ❌ null | ✅ | ✅ |

**❌ null = NORMAL para aquele tipo. NÃO é falha.**

### Função correta de status:

```javascript
function getLogStatus(log) {
    if (log.error_message) return 'error';
    if (log.action_success === false) return 'error';
    if (log.status === 'error') return 'error';
    return 'success';  // null em qualquer campo = OK
}
```

### Como mostrar na UI:

```javascript
function getStatusBadge(log) {
    const status = getLogStatus(log);
    if (status === 'error') {
        return { label: 'Erro', color: '#FF4444', icon: '✗' };
    }
    return { label: 'OK', color: '#22C55E', icon: '✓' };
}
```

---

## CORREÇÃO 2 — CSS: Dark Mode Only + Cor #0057FF

### No `style.css`:

**Trocar todo o bloco `:root` por:**

```css
:root {
    /* Cor primária — Azul Total Assistente #0057FF */
    --primary: 217 100% 50%;
    --primary-light: 217 100% 60%;
    --primary-dark: 217 100% 40%;
    --secondary: 217 80% 55%;
    --negative: 0 84% 60%;

    /* Dark mode FIXO */
    --background: 222 47% 4%;
    --foreground: 210 40% 98%;
    --card: 222 47% 8%;
    --card-foreground: 210 40% 98%;
    --muted: 217.2 32.6% 12%;
    --muted-foreground: 215 20.2% 65.1%;
    --glass-bg: hsla(222, 47%, 4%, 0.8);
    --glass-border: hsla(210, 40%, 98%, 0.12);

    --radius-3xl: 24px;
    --radius-full: 9999px;
    --duration-500: 500ms;
}
```

**Deletar o bloco inteiro `[data-theme='dark'] { ... }`**

### No `app.js`:

**1. Remover state theme (linha ~78):**
```javascript
// REMOVER: const [theme, setTheme] = useState(localStorage.getItem('theme') || 'light');
```

**2. Trocar useEffect do theme (linha ~87-90) por:**
```javascript
useEffect(() => {
    document.documentElement.setAttribute('data-theme', 'dark');
}, []);
```

**3. Remover toggleTheme (linha ~174):**
```javascript
// REMOVER: const toggleTheme = () => setTheme(prev => prev === 'light' ? 'dark' : 'light');
```

**4. Na Navbar, remover o botão Sun/Moon (linhas ~235-241):**
```javascript
// REMOVER todo o bloco:
// e('div', { className: 'theme-toggle-wrapper', ... },
//     e('button', { ... }, theme === 'light' ? e(Moon, ...) : e(Sun, ...))
// ),
```

**5. Remover Sun e Moon do import (linha ~6-7):**
```javascript
// REMOVER: Sun, Moon
```

---

## CORREÇÃO 3 — Navbar reorganizada

**Trocar `navItems` na função Navbar (linha ~219-226):**

```javascript
const navItems = [
    { id: 'activity', label: 'Activity Log', icon: Zap },
    { id: 'dashboard', label: 'Dashboard', icon: null },
    { id: 'users', label: 'Usuários', icon: Users },
    { id: 'chat', label: 'Chat', icon: MessageCircle },
    { id: 'log', label: 'Conversas', icon: User },
    { id: 'docs', label: 'Docs', icon: Mail }
];
```

**Trocar view default (linha ~77):**
```javascript
const [view, setView] = useState('activity'); // era 'menu'
```

**Adicionar no renderView switch (linha ~184-203):**
```javascript
case 'activity': return e(ActivityLog, {});
```

---

## CORREÇÃO 4 — Tela Activity Log (lê do execution_log)

### IMPORTANTE: Usa `supabaseDB2` (não `supabase`)

A tela Activity Log deve ler da view `v_exec_log_with_user` que já traz o **nome do usuário** via JOIN.

### Query principal:

```javascript
// Buscar últimos 50 logs com nome do usuário
const { data } = await supabaseDB2
    .from('v_exec_log_with_user')
    .select('*')
    .not('user_phone', 'is', null)
    .order('created_at', { ascending: false })
    .range(0, 49);
```

### Essa view retorna todos os campos do execution_log MAIS:
- `user_name` — nome do usuário (vem da tabela profiles)
- `user_email` — email
- `resolved_plan` — plano

### Como mostrar cada tipo de log na tela:

```javascript
function renderLogCard(log) {
    const status = getLogStatus(log);
    const time = new Date(log.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    switch (log.event_type) {
        case 'message_received':
            // Card: "Mensagem recebida"
            // Mostrar: user_name, user_message, message_type, time
            break;

        case 'message_routed':
            // Card: "Roteado para premium"
            // Mostrar: user_name, routed_to, time
            break;

        case 'classification':
            // Card: "Classificado como criar_gasto"
            // Mostrar: user_name, user_message, branch, time
            break;

        case 'ai_response':
            // Card: "IA respondeu"
            // Mostrar: user_name, ai_message, ai_action, ai_tools_called, time
            break;

        case 'action_executed':
            // Card: "Ação executada"
            // Mostrar: user_name, action_type, action_input (JSON), action_success, time
            break;

        case 'transcription':
            // Card: "Áudio transcrito"
            // Mostrar: user_name, transcription_text, time
            break;
    }
}
```

### Badges por workflow:

```javascript
const workflowColors = {
    main:        { bg: 'hsla(215, 20%, 50%, 0.15)', text: 'hsl(215, 20%, 65%)' },
    premium:     { bg: 'hsla(270, 60%, 60%, 0.15)', text: 'hsl(270, 60%, 70%)' },
    financeiro:  { bg: 'hsla(150, 60%, 50%, 0.15)', text: 'hsl(150, 60%, 60%)' },
    calendar:    { bg: 'hsla(30, 80%, 55%, 0.15)',  text: 'hsl(30, 80%, 65%)' },
    lembretes:   { bg: 'hsla(45, 80%, 55%, 0.15)',  text: 'hsl(45, 80%, 65%)' },
    report:      { bg: 'hsla(190, 70%, 50%, 0.15)', text: 'hsl(190, 70%, 60%)' },
    service_msg: { bg: 'hsla(280, 40%, 50%, 0.15)', text: 'hsl(280, 40%, 65%)' }
};
```

### Badges de status:

```javascript
const statusColors = {
    success: { bg: 'hsla(150, 60%, 50%, 0.15)', text: '#22C55E', label: '✓ sucesso' },
    error:   { bg: 'hsla(0, 84%, 60%, 0.15)',   text: '#FF4444', label: '✗ erro' }
};
```

---

## CORREÇÃO 5 — Design dos cards de log (estilo WhatsApp)

Cada card na timeline deve ter este visual:

```css
.activity-card {
    background: hsla(222, 47%, 8%, 0.6);
    backdrop-filter: blur(16px);
    border: 1px solid hsla(210, 40%, 98%, 0.06);
    border-radius: 16px;
    padding: 20px;
    margin-bottom: 12px;
    cursor: pointer;
    transition: all 0.2s;
}

.activity-card:hover {
    border-color: hsla(210, 40%, 98%, 0.15);
    transform: translateY(-1px);
}

/* Mensagem do usuário */
.activity-user-msg {
    font-size: 0.95rem;
    color: hsl(210, 40%, 98%);
    margin: 12px 0 8px;
    line-height: 1.5;
}

/* Resposta da IA */
.activity-ai-msg {
    font-size: 0.88rem;
    color: hsl(215, 20%, 65%);
    padding-left: 14px;
    border-left: 2px solid #0057FF;
    margin: 8px 0 12px;
    line-height: 1.5;
}

/* Header do card */
.activity-card-header {
    display: flex;
    align-items: center;
    gap: 10px;
}

.activity-card-time {
    font-size: 0.78rem;
    color: hsl(215, 20%, 50%);
    font-variant-numeric: tabular-nums;
}

.activity-card-name {
    font-weight: 600;
    font-size: 0.88rem;
}

/* Footer com badges */
.activity-card-footer {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
}

/* Badge genérico */
.activity-badge {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 3px 10px;
    border-radius: 9999px;
    font-size: 0.68rem;
    font-weight: 600;
    letter-spacing: 0.03em;
    text-transform: uppercase;
}
```

---

## CORREÇÃO 6 — Modal de detalhes

Quando clicar num card, abrir modal glass com ALL data:

```css
.detail-modal-overlay {
    position: fixed;
    inset: 0;
    background: hsla(222, 47%, 2%, 0.85);
    backdrop-filter: blur(8px);
    z-index: 1000;
    display: flex;
    align-items: center;
    justify-content: center;
}

.detail-modal {
    background: hsla(222, 47%, 8%, 0.95);
    backdrop-filter: blur(32px);
    border: 1px solid hsla(210, 40%, 98%, 0.1);
    border-radius: 24px;
    padding: 32px;
    max-width: 560px;
    width: 90%;
    max-height: 85vh;
    overflow-y: auto;
}

.detail-section {
    margin-bottom: 24px;
}

.detail-section-title {
    font-size: 0.7rem;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: hsl(215, 20%, 50%);
    margin-bottom: 8px;
    padding-bottom: 6px;
    border-bottom: 1px solid hsla(210, 40%, 98%, 0.06);
}

.detail-field {
    display: flex;
    justify-content: space-between;
    padding: 6px 0;
    font-size: 0.85rem;
}

.detail-label {
    color: hsl(215, 20%, 55%);
}

.detail-value {
    color: hsl(210, 40%, 98%);
    font-weight: 500;
    text-align: right;
    max-width: 60%;
    word-break: break-word;
}

.detail-json {
    background: hsla(222, 47%, 4%, 0.8);
    border-radius: 12px;
    padding: 14px;
    font-family: 'JetBrains Mono', 'SF Mono', monospace;
    font-size: 0.78rem;
    color: hsl(215, 20%, 65%);
    white-space: pre-wrap;
    word-break: break-all;
    margin-top: 8px;
    max-height: 200px;
    overflow-y: auto;
}
```

### Conteúdo do modal:

```
── Usuário ──────────────────────
Nome:      Luiz Felipe Porto
Telefone:  +55 43 9193-6205
Plano:     Premium

── Mensagem ─────────────────────
"Gasto 54 iFood"
Tipo: text

── Classificação ────────────────
Branch: criar_gasto

── Resposta IA ──────────────────
"Registrei seu gasto de R$54 em Alimentação!"
Ação: registrar_gasto
Tools: registrar_financeiros

── Execução ─────────────────────
Input:
  { "nome": "iFood", "valor": 54, "categoria": "Alimentação" }
Status: ✓ Sucesso

── Metadados ────────────────────
Workflow: premium
Evento: action_executed
ID: 28577b41-b184-...
Hora: 25/03/2026 11:34:28
```

---

## RESUMO — ORDEM DE EXECUÇÃO

| # | O que | Prioridade |
|---|-------|-----------|
| 1 | CSS: dark mode only + cor #0057FF + deletar `[data-theme='dark']` | FAZER PRIMEIRO |
| 2 | app.js: remover theme/toggle, forçar dark | FAZER PRIMEIRO |
| 3 | Corrigir lógica de falha (null ≠ erro) | URGENTE |
| 4 | Navbar: nova ordem + view `activity` | ALTO |
| 5 | Componente ActivityLog (sidebar + cards + query supabaseDB2) | ALTO |
| 6 | CSS dos cards (glassmorphism, badges, cores) | ALTO |
| 7 | Modal de detalhes | MÉDIO |
| 8 | Responsivo mobile | MÉDIO |

---

*Tudo deve usar `supabaseDB2` (PRINCIPAL). NÃO usar `supabase` (DB1 antigo) para nada novo.*
*View `v_exec_log_with_user` já traz o nome do usuário automaticamente.*
