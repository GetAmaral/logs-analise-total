# PLANO DE DESIGN — Dashboard Execution Log

**Projeto:** analise-total (github.com/luizporto-ai/analise-total)
**Data:** 2026-03-25
**Premissa:** Dark mode only. Nao excluir nada existente. Reorganizar UX.

---

## ENTENDIMENTO DO PROJETO ATUAL

### Stack
- React 18.2 via CDN (sem build step, sem JSX — usa `React.createElement`)
- CSS puro com CSS variables (glassmorphism)
- Chart.js para graficos
- Lucide React para icones
- Supabase (2 instancias: DB1 mensagens, DB2 principal)
- Arquivo unico: `app.js` (2.153 linhas) + `style.css` (1.629 linhas)

### Paginas existentes (6)
| Pagina | O que faz | Status |
|--------|----------|--------|
| Menu | Hub com 5 opcoes | Funcional, mas generico |
| Chat | Simulador WhatsApp para testes | Funcional |
| Log | Historico de mensagens por usuario | Funcional, UX boa |
| Users | CRUD de usuarios | Funcional |
| Dashboard | KPIs + graficos de log_total | Funcional, mas denso |
| Docs | Browser de GitHub | Funcional, pouco util |

### Style atual
- Glassmorphism (blur + transparencia)
- CSS variables para temas
- Fontes: Inter (body) + Outfit (headings)
- Animacoes suaves (slideUp, fadeIn, float)
- Responsivo (3 breakpoints)

---

## MUDANCAS PROPOSTAS

### 1. DARK MODE ONLY

Remover o toggle light/dark. Forcar dark mode sempre.

```css
/* Antes: [data-theme='dark'] { ... } */
/* Depois: aplicar dark vars direto no :root */
:root {
    --background: 222 47% 4%;
    --foreground: 210 40% 98%;
    --card: 222 47% 8%;
    --card-foreground: 210 40% 98%;
    --muted: 217.2 32.6% 12%;
    --muted-foreground: 215 20.2% 65.1%;
    --glass-bg: hsla(222 47% 4% / 0.8);
    --glass-border: hsla(210 40% 98% / 0.12);
}
```

Remover o botao Sun/Moon da navbar.

### 2. REORGANIZAR NAVEGACAO

**Navbar atual:** Menu | Chat | Log | Users | Dashboard | Docs (6 itens flat)

**Navbar proposta:** Agrupamento logico

```
[Logo] [Activity Log] [Dashboard] [Users] [Chat] [Docs] [Logout]
```

Mudancas:
- "Menu" desaparece — a navbar JA e o menu
- "Log" renomeia para "Activity Log" (sera a pagina principal com execution_log)
- "Dashboard" continua (KPIs existentes + novos de execution_log)
- Ordem por importancia de uso

### 3. NOVA PAGINA: ACTIVITY LOG (execution_log)

Esta e a pagina principal nova. Substitui/amplia o "Log" atual.

---

## DESIGN DA PAGINA ACTIVITY LOG

### Layout

```
┌─────────────────────────────────────────────────────────────┐
│  [Navbar pill]                                               │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Activity Log                              [Filtros ▼]      │
│                                                              │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐  │
│  │ Interacoes │ │ Sucesso   │ │ Erros     │ │ Tempo med │  │
│  │    127     │ │   94%     │ │    3      │ │   2.1s    │  │
│  │ glass-card │ │ glass-card│ │ glass-card│ │ glass-card│  │
│  └───────────┘ └───────────┘ └───────────┘ └───────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────────┐│
│  │  TIMELINE                                     [Tabela ⇄]││
│  │                                                          ││
│  │  10:32  ● premium  criar_gasto                          ││
│  │  ┌──────────────────────────────────────────────────┐   ││
│  │  │  "registra 45 reais almoco"                      │   ││
│  │  │                                                  │   ││
│  │  │  IA: "Registrei R$45 em Alimentacao!"            │   ││
│  │  │                                                  │   ││
│  │  │  ◉ registrar_gasto  ✓ sucesso  ⏱ 2.1s          │   ││
│  │  └──────────────────────────────────────────────────┘   ││
│  │                                                          ││
│  │  10:28  ● main  message_received                        ││
│  │  ┌──────────────────────────────────────────────────┐   ││
│  │  │  "oi" (text)                                     │   ││
│  │  │  → Roteado para: premium                         │   ││
│  │  └──────────────────────────────────────────────────┘   ││
│  │                                                          ││
│  │  [Carregar mais...]                                      ││
│  └──────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

### KPI Cards (topo)

4 cards com glassmorphism (reutilizar estilo `glass-effect` existente):

| Card | Valor | Query |
|------|-------|-------|
| Interacoes hoje | COUNT onde event_type = 'message_received' AND today | Numero grande + delta vs ontem |
| Taxa de sucesso | action_success = true / total action_executed | Porcentagem + cor (verde >90%, amarelo >70%, vermelho) |
| Erros | COUNT onde error_message IS NOT NULL AND today | Numero + badge vermelho |
| Tempo medio | AVG(duration_ms) | Formato "2.1s" |

### Filtros (painel colapsavel)

Clicar em "Filtros" abre um painel glass abaixo dos KPIs:

| Filtro | Tipo | Valores |
|--------|------|---------|
| Periodo | Botoes pill (como Dashboard existente) | 1h, 24h, 7d, 30d |
| Workflow | Pills toggleaveis | main, premium, financeiro, calendar, lembretes, report |
| Evento | Pills toggleaveis | message_received, classification, ai_response, action_executed |
| Branch | Dropdown | criar_gasto, criar_evento, padrao, etc. |
| Status | Pills | Sucesso, Erro, Todos |
| Busca | Input text | Busca em user_message + ai_message |

### Timeline (corpo principal)

Cada entrada e um card glass com:

```
[Hora]  [●] [workflow badge]  [branch/action badge]

  Mensagem do usuario (se disponivel)

  Resposta da IA (se disponivel)

  [action_type badge] [success/error badge] [duration badge]
```

**Cores dos badges por workflow:**

| Workflow | Cor | HSL |
|----------|-----|-----|
| main | Cinza neutro | `215 20% 50%` |
| premium | Roxo | `270 60% 60%` |
| financeiro | Verde | `150 60% 50%` |
| calendar | Laranja | `30 80% 55%` |
| lembretes | Amarelo | `45 80% 55%` |
| report | Ciano | `190 70% 50%` |

**Icones por event_type (Lucide):**

| event_type | Icone Lucide | Cor |
|-----------|-------------|-----|
| message_received | MessageCircle | azul |
| transcription | Mic | roxo |
| audio_summary | FileText | roxo |
| message_routed | ArrowRight | cinza |
| classification | Brain (ou Tag) | amber |
| ai_response | Bot (ou Zap) | verde |
| action_executed | Zap | emerald |
| error | AlertTriangle | vermelho |

**Badge de status:**

| Status | Visual |
|--------|--------|
| success | `●` verde + "sucesso" |
| error | `●` vermelho + mensagem de erro |
| completed | `●` verde (sem texto extra) |

### Toggle Timeline ⇄ Tabela

Botao no canto superior direito alterna entre:
- **Timeline:** Cards visuais (default, mais bonito)
- **Tabela:** Grid com colunas sortaveis (para analise rapida)

Colunas da tabela:
| Coluna | Sortable |
|--------|---------|
| Hora | Sim |
| Telefone | Sim |
| Workflow | Sim |
| Branch | Sim |
| Mensagem (truncada) | Nao |
| Acao | Sim |
| Status | Sim |
| Tempo | Sim |

### Detalhe da interacao (modal)

Clicar em um card abre modal glass (reutilizar `modal-overlay` existente):

```
┌─────────────────────────────────────────┐
│  Detalhe da Interacao              [X]  │
│                                         │
│  ── Usuario ─────────────────────────── │
│  Telefone: +55 43 9193-XXXX            │
│  Plano: Premium                         │
│  ID: 2eb4065b...                        │
│                                         │
│  ── Mensagem ────────────────────────── │
│  "registra 45 reais almoco"             │
│  Tipo: text                             │
│  WhatsApp: 25/03/2026 10:36:09         │
│                                         │
│  ── Classificacao ───────────────────── │
│  Branch: criar_gasto                    │
│                                         │
│  ── Resposta IA ─────────────────────── │
│  "Registrei seu gasto de R$45,00        │
│   na categoria Alimentacao!"            │
│  Acao: registrar_gasto                  │
│  Tools: registrar_financeiros           │
│                                         │
│  ── Execucao ────────────────────────── │
│  Input: {nome: "Almoco", valor: 45,     │
│          categoria: "Alimentacao"}       │
│  Status: ● Sucesso                      │
│  Tempo: 2.1s                            │
│                                         │
│  ── Metadados ───────────────────────── │
│  Workflow: premium                      │
│  Event type: action_executed            │
│  ID: 7458171c-8eb5-41db...             │
│  Criado: 25/03/2026 10:36:30           │
└─────────────────────────────────────────┘
```

---

## MUDANCAS NO DASHBOARD EXISTENTE

### Adicionar secao "Execution Log" ao Dashboard

Abaixo dos KPIs existentes (log_total), adicionar:

**Nova secao: "Fluxo de Execucao"**

| Grafico | Tipo | Dados |
|---------|------|-------|
| Volume por hora | Line chart (Chart.js) | execution_log GROUP BY hour |
| Top intents | Horizontal bar | execution_log GROUP BY branch |
| Sucesso vs Falha | Doughnut | action_success true/false |
| Split por workflow | Stacked bar | GROUP BY source_workflow |

Reutilizar o padrao de Chart.js que ja existe no Dashboard.

---

## MUDANCAS NO LOG EXISTENTE

O "Log" atual mostra mensagens do `log_users_messages` + `log_total`. Proposta:

**Adicionar tab no topo da pagina Log:**

```
[Conversas]  [Execution Log]
```

- **Conversas:** Funcionalidade atual (sidebar + chat com mensagens)
- **Execution Log:** Nova pagina Activity Log descrita acima

Assim nao perde nada do que ja existe.

---

## ESTILO CSS — NOVOS COMPONENTES

### Cards de KPI (reutilizar glass-effect)

```css
.kpi-grid {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 16px;
    padding: 0 24px;
}

.kpi-card {
    background: hsla(222, 47%, 8%, 0.6);
    backdrop-filter: blur(32px);
    border: 1px solid hsla(210, 40%, 98%, 0.08);
    border-radius: 20px;
    padding: 24px;
}

.kpi-card .kpi-value {
    font-family: 'Outfit', sans-serif;
    font-size: 2.5rem;
    font-weight: 700;
    letter-spacing: -0.02em;
}

.kpi-card .kpi-label {
    font-size: 0.85rem;
    color: hsl(var(--muted-foreground));
    margin-top: 4px;
}

.kpi-card .kpi-delta {
    font-size: 0.75rem;
    margin-top: 8px;
}

.kpi-delta.positive { color: hsl(150, 60%, 50%); }
.kpi-delta.negative { color: hsl(0, 84%, 60%); }
```

### Timeline cards

```css
.timeline-entry {
    background: hsla(222, 47%, 8%, 0.4);
    backdrop-filter: blur(16px);
    border: 1px solid hsla(210, 40%, 98%, 0.06);
    border-radius: 16px;
    padding: 20px;
    margin-bottom: 12px;
    transition: border-color 0.2s, transform 0.2s;
    cursor: pointer;
}

.timeline-entry:hover {
    border-color: hsla(210, 40%, 98%, 0.15);
    transform: translateY(-1px);
}

.timeline-header {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 12px;
}

.timeline-time {
    font-size: 0.8rem;
    color: hsl(var(--muted-foreground));
    font-variant-numeric: tabular-nums;
}

.badge {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    padding: 3px 10px;
    border-radius: 9999px;
    font-size: 0.7rem;
    font-weight: 600;
    letter-spacing: 0.02em;
    text-transform: uppercase;
}

.badge-premium { background: hsla(270, 60%, 60%, 0.15); color: hsl(270, 60%, 70%); }
.badge-main { background: hsla(215, 20%, 50%, 0.15); color: hsl(215, 20%, 65%); }
.badge-financeiro { background: hsla(150, 60%, 50%, 0.15); color: hsl(150, 60%, 60%); }
.badge-calendar { background: hsla(30, 80%, 55%, 0.15); color: hsl(30, 80%, 65%); }
.badge-lembretes { background: hsla(45, 80%, 55%, 0.15); color: hsl(45, 80%, 65%); }
.badge-report { background: hsla(190, 70%, 50%, 0.15); color: hsl(190, 70%, 60%); }

.badge-success { background: hsla(150, 60%, 50%, 0.15); color: hsl(150, 60%, 60%); }
.badge-error { background: hsla(0, 84%, 60%, 0.15); color: hsl(0, 84%, 65%); }

.timeline-message {
    font-size: 0.9rem;
    line-height: 1.5;
    color: hsl(var(--foreground));
    margin-bottom: 8px;
}

.timeline-ai-response {
    font-size: 0.85rem;
    color: hsl(var(--muted-foreground));
    padding-left: 12px;
    border-left: 2px solid hsla(270, 60%, 60%, 0.3);
    margin-bottom: 12px;
}

.timeline-footer {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-wrap: wrap;
}
```

### Filtros

```css
.filters-panel {
    background: hsla(222, 47%, 6%, 0.8);
    backdrop-filter: blur(32px);
    border: 1px solid hsla(210, 40%, 98%, 0.08);
    border-radius: 20px;
    padding: 20px;
    margin: 0 24px 20px;
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
    gap: 16px;
}

.filter-pills {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
}

.filter-pill {
    padding: 5px 12px;
    border-radius: 9999px;
    font-size: 0.75rem;
    background: hsla(210, 40%, 98%, 0.06);
    border: 1px solid hsla(210, 40%, 98%, 0.1);
    color: hsl(var(--muted-foreground));
    cursor: pointer;
    transition: all 0.2s;
}

.filter-pill.active {
    background: hsla(270, 60%, 60%, 0.2);
    border-color: hsl(270, 60%, 60%);
    color: hsl(270, 60%, 70%);
}
```

---

## QUERIES SUPABASE PARA A UI

```javascript
// A tabela execution_log esta no DB2 (principal) — ja conectado como supabaseDB2

// Timeline (paginada)
const { data } = await supabaseDB2
    .from('execution_log')
    .select('*')
    .not('user_phone', 'is', null)
    .order('created_at', { ascending: false })
    .range(offset, offset + 49);

// KPIs do dia
const { data } = await supabaseDB2
    .from('v_exec_log_daily_summary')
    .select('*')
    .gte('dia', new Date().toISOString().split('T')[0]);

// Top intents
const { data } = await supabaseDB2
    .from('v_exec_log_branch_stats')
    .select('*')
    .order('total', { ascending: false })
    .limit(10);

// Volume por hora
const { data } = await supabaseDB2
    .from('v_exec_log_hourly_volume')
    .select('*')
    .gte('hora', new Date(Date.now() - 7*24*60*60*1000).toISOString());
```

---

## FASES DE IMPLEMENTACAO

| Fase | O que | Estimativa |
|------|-------|-----------|
| **D1** | Dark mode only + remover toggle | 15 min |
| **D2** | Reorganizar navbar (ordem + nomes) | 20 min |
| **D3** | Pagina Activity Log (KPIs + timeline + filtros) | 2-3h |
| **D4** | Modal de detalhe da interacao | 45 min |
| **D5** | Toggle timeline/tabela | 1h |
| **D6** | Graficos no Dashboard existente | 1h |
| **D7** | Tab no Log existente (Conversas / Execution Log) | 30 min |
| **D8** | Polish + responsivo mobile | 1h |

**Total estimado: ~7h**

---

## PRINCIPIOS DE DESIGN

1. **Glassmorphism consistente** — todos os novos componentes usam blur + transparencia
2. **Badges coloridos** — cada workflow e tipo tem cor propria
3. **Tipografia hierarquica** — Outfit para numeros grandes, Inter para texto
4. **Espacamento generoso** — padding 24px, gap 16px, respiro visual
5. **Animacoes sutis** — hover com translateY(-1px), transicao de borda
6. **Informacao progressiva** — resumo na timeline, detalhe no modal
7. **Nao quebrar nada** — tudo e ADICIONADO, nada removido

---

*Plano de design — Argus (auditor-real squad)*
