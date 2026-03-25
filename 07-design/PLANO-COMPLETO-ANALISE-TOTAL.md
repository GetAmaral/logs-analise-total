# PLANO COMPLETO — Integração execution_log no analise-total

**Data:** 2026-03-25
**Repo:** github.com/luizporto-ai/analise-total
**Premissa:** Dark mode only. Não excluir funcionalidades. Reorganizar UX.

---

## ⚠️ AVISO IMPORTANTE — QUAL SUPABASE

O projeto tem **2 Supabase**. Leia com atenção:

| Alias | Project | URL | Variável no código | O que tem |
|-------|---------|-----|--------------------|----|
| **DB1** (antigo) | `hkzgttizcfklxfafkzfl` | hkzgttizcfklxfafkzfl.supabase.co | `supabase` | log_users_messages, log_total, resposta_ia, RPCs dashboard |
| **DB2** (principal) | `ldbdtakddxznfridsarn` | ldbdtakddxznfridsarn.supabase.co | `supabaseDB2` | profiles, subscriptions, **execution_log**, views, RPCs novas |

### A tabela `execution_log` está no DB2 (PRINCIPAL).

O DB1 (antigo) tinha `log_users_messages` que só guardava pares mensagem↔resposta, sem branch, sem ação, sem nada. O `execution_log` no DB2 **substitui e amplia** isso — agora captura tudo: mensagem, classificação, resposta IA, ação executada, sucesso/falha, transcrições, etc.

**Para o programador:** Todas as queries novas do Activity Log usam `supabaseDB2` (já existe no código, linha 44 do app.js). NÃO usar `supabase` (DB1) para nada novo.

---

## ⚠️ NOME DO USUÁRIO NOS LOGS

A tabela `execution_log` tem `user_phone` e `user_id`, mas **NÃO tem o nome**. O nome está na tabela `profiles` (mesmo DB2).

**Solução criada:** View `v_exec_log_with_user` que faz JOIN automático:
- `execution_log.user_phone` → `profiles.phone` → traz `name`, `email`, `plan_type`
- Fallback: se phone não der match, tenta `user_id` → `profiles.id`

**O programador deve usar `v_exec_log_with_user` em vez de `execution_log` diretamente** para toda query que mostra dados ao usuário. Assim o nome aparece sempre.

Campos extras que a view adiciona:
- `user_name` — nome do usuário (ou "Desconhecido")
- `user_email` — email
- `resolved_plan` — plano resolvido (prioriza execution_log, fallback profiles)

---

## CHECKLIST — O QUE JÁ ESTÁ FEITO vs O QUE FALTA

### ✅ Já feito (não precisa fazer)

| Item | SQL no repo |
|------|-------------|
| Tabela `execution_log` | `03-migration/01-create-table.sql` |
| 13 índices | `03-migration/02-create-indexes.sql` |
| RLS (service_role only) | `03-migration/03-rls-policies.sql` |
| 5 views analíticas | `03-migration/04-create-views.sql` |
| Dados fluindo via N8N | 9 nodes em Main + Premium |

### ❌ Falta executar no Supabase PRINCIPAL (DB2)

| Item | SQL no repo | Colar onde |
|------|-------------|-----------|
| RPC `fn_exec_log_kpis` | `03-migration/05-create-rpc-kpis.sql` | SQL Editor do DB2 |
| View `v_exec_log_with_user` | `03-migration/06-create-view-with-names.sql` | SQL Editor do DB2 |

### ❌ Falta implementar no código

| Item | Descrição |
|------|-----------|
| Dark mode only | Remover light mode |
| Navbar reorganizada | Nova ordem + nova view |
| Tela 1: Activity Log (WhatsApp-like) | Timeline de conversas com nome do user |
| Tela 2: Dashboard Analytics | Gráficos, KPIs, distribuição |

---

## VISÃO DAS 2 TELAS NOVAS

### TELA 1 — Activity Log (estilo WhatsApp)

Uma tela que mostra **todas as interações em tempo real**, como se fosse o WhatsApp do admin. O admin vê tudo que tá acontecendo.

**Layout:**

```
┌────────────────────────────────────────────────────────────────┐
│  [Navbar]                                                       │
├──────────────┬─────────────────────────────────────────────────┤
│              │                                                  │
│  SIDEBAR     │  ÁREA DE CONVERSAS                               │
│              │                                                  │
│  [🔍 Buscar] │  ┌──────────────────────────────────────────┐   │
│              │  │ 10:36 · Luiz Felipe · Premium             │   │
│  Luiz Felipe │  │                                           │   │
│  "Oi" · 10:36│  │  👤 "Oi"                                  │   │
│  Premium ●   │  │                                           │   │
│              │  │  🤖 "Olá Luiz! Como posso ajudar?"        │   │
│  Maria       │  │                                           │   │
│  "registra.."│  │  ◉ padrao · ✓ sucesso                    │   │
│  Premium ●   │  └──────────────────────────────────────────┘   │
│              │                                                  │
│  João        │  ┌──────────────────────────────────────────┐   │
│  "excluir .."│  │ 10:32 · Luiz Felipe · Premium             │   │
│  Standard ●  │  │                                           │   │
│              │  │  👤 "registra 45 reais almoco"             │   │
│              │  │                                           │   │
│              │  │  🤖 "Registrei R$45 em Alimentação!"       │   │
│              │  │                                           │   │
│              │  │  ◉ registrar_gasto · ✓ sucesso · 2.1s    │   │
│              │  │  📦 {nome: "Almoco", valor: 45, ...}      │   │
│              │  └──────────────────────────────────────────┘   │
│              │                                                  │
│              │  [Carregar mais...]                               │
├──────────────┴─────────────────────────────────────────────────┤
│  [Filtros: Período | Workflow | Status | Branch]                │
└────────────────────────────────────────────────────────────────┘
```

**Sidebar:**
- Lista de usuários únicos (agrupados por user_phone)
- Mostra: **nome** (via v_exec_log_with_user), última mensagem, hora, badge plano
- Clique no usuário → filtra a área de conversas para ele
- "Todos" mostra tudo (default)

**Área de conversas:**
- Cards estilo chat — mensagem do user à esquerda, resposta IA à direita
- Cada card mostra: hora, nome, plano, mensagem, resposta, ação, status, duração
- Cores por workflow
- Clique no card → abre modal com detalhe completo (input/output JSON, metadados)

**Diferença do Log antigo:** O Log antigo (view `log`) mostra `log_users_messages` do DB1 (antigo). O Activity Log novo mostra `execution_log` do DB2 com TUDO — classificação, ações, erros, transcrições.

---

### TELA 2 — Dashboard Analytics

Uma tela que mostra **métricas, gráficos e análises** de tudo que está acontecendo. O admin entende padrões, problemas, volumes.

**Layout:**

```
┌────────────────────────────────────────────────────────────────┐
│  [Navbar]                                                       │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Execution Analytics                  [1h] [24h] [7d] [30d]   │
│                                                                 │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐         │
│  │Interações│ │ Sucesso  │ │  Erros   │ │ Usuários │         │
│  │   127    │ │  94.2%   │ │    3     │ │    12    │         │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘         │
│                                                                 │
│  ┌─────────────────────────────┐ ┌────────────────────────────┐│
│  │  📈 Volume por hora         │ │  🍩 Distribuição de intents ││
│  │                             │ │                             ││
│  │  Line chart (Chart.js)      │ │  criar_gasto ████████ 34   ││
│  │  Eixo X: horas              │ │  criar_evento █████ 28     ││
│  │  Eixo Y: qtd interações     │ │  padrao ████ 19            ││
│  │                             │ │  excluir_evento ██ 8       ││
│  └─────────────────────────────┘ └────────────────────────────┘│
│                                                                 │
│  ┌─────────────────────────────┐ ┌────────────────────────────┐│
│  │  📊 Sucesso vs Falha        │ │  👥 Top usuários           ││
│  │                             │ │                             ││
│  │  Stacked bar por dia        │ │  1. Luiz Felipe · 47 ações ││
│  │  Verde = sucesso            │ │  2. Maria · 23 ações       ││
│  │  Vermelho = falha           │ │  3. João · 18 ações        ││
│  └─────────────────────────────┘ └────────────────────────────┘│
│                                                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  ⚠️ Erros recentes                                          ││
│  │                                                              ││
│  │  10:32 · premium · registrar_gasto · "timeout na API..."    ││
│  │  09:15 · calendar · sync_google · "token expirado"          ││
│  └─────────────────────────────────────────────────────────────┘│
└────────────────────────────────────────────────────────────────┘
```

**KPI Cards (4):**
- Interações (message_received count)
- Taxa de sucesso (% com badge verde/amarelo/vermelho)
- Erros (count com badge)
- Usuários únicos (distinct user_phone)

**Gráficos (4):**
1. **Volume por hora** — Line chart, mostra picos de uso
2. **Distribuição de intents** — Doughnut/bar, mostra o que mais pedem
3. **Sucesso vs Falha** — Stacked bar por dia
4. **Top usuários** — Ranking com nome + total de ações

**Lista de erros recentes:**
- Últimos erros do `v_exec_log_recent_errors`
- Hora, workflow, action_type, error_message
- Clicável → abre modal de detalhe

---

## ARQUITETURA TÉCNICA

### Conexão com o banco

```javascript
// JÁ EXISTE no app.js (linha 40-44):
const SUPABASE_URL_DB2 = 'https://ldbdtakddxznfridsarn.supabase.co';
const SUPABASE_KEY_DB2 = '...service_role_key...';
const supabaseDB2 = createClient(SUPABASE_URL_DB2, SUPABASE_KEY_DB2);

// TODAS as queries novas usam supabaseDB2
```

### Queries principais

**Activity Log — Sidebar (usuários únicos com nome):**
```javascript
const { data } = await supabaseDB2
    .from('v_exec_log_with_user')
    .select('user_phone, user_name, user_message, resolved_plan, created_at')
    .not('user_phone', 'is', null)
    .order('created_at', { ascending: false });

// Agrupar por user_phone no JavaScript (igual ao fetchSessions existente)
```

**Activity Log — Timeline de um usuário:**
```javascript
const { data } = await supabaseDB2
    .from('v_exec_log_with_user')
    .select('*')
    .eq('user_phone', selectedPhone)
    .order('created_at', { ascending: false })
    .range(0, 49);
```

**Activity Log — Timeline geral (todos):**
```javascript
const { data } = await supabaseDB2
    .from('v_exec_log_with_user')
    .select('*')
    .not('user_phone', 'is', null)
    .order('created_at', { ascending: false })
    .range(0, 49);
```

**Dashboard — KPIs:**
```javascript
const { data } = await supabaseDB2.rpc('fn_exec_log_kpis', {
    p_start: startDate.toISOString(),
    p_end: endDate.toISOString()
});
```

**Dashboard — Branch stats (donut):**
```javascript
const { data } = await supabaseDB2
    .from('v_exec_log_branch_stats')
    .select('*')
    .order('total', { ascending: false })
    .limit(10);
```

**Dashboard — Volume horário (line chart):**
```javascript
const { data } = await supabaseDB2
    .from('v_exec_log_hourly_volume')
    .select('*')
    .gte('hora', startDate.toISOString());
```

**Dashboard — Erros recentes:**
```javascript
const { data } = await supabaseDB2
    .from('v_exec_log_recent_errors')
    .select('*')
    .limit(10);
```

**Dashboard — Top usuários (com nome):**
```javascript
// Buscar top phones por volume
const { data: topPhones } = await supabaseDB2
    .from('execution_log')
    .select('user_phone')
    .not('user_phone', 'is', null)
    .gte('created_at', startDate.toISOString());

// Agrupar no JS, depois buscar nomes via profiles
const { data: profiles } = await supabaseDB2
    .from('profiles')
    .select('name, phone, plan_type')
    .in('phone', topPhonesList);
```

---

## MUDANÇAS POR ARQUIVO

### index.html — Nenhuma mudança

### style.css — Mudanças

| # | O que | Tipo |
|---|-------|------|
| S1 | Dark mode only (`:root` recebe vars dark, remove `[data-theme='dark']`) | Editar |
| S2 | `.activity-container` (layout 2 colunas: sidebar + área) | Novo |
| S3 | `.activity-sidebar` + `.activity-user-item` | Novo |
| S4 | `.activity-card` (card estilo chat) | Novo |
| S5 | `.kpi-grid` + `.kpi-card` | Novo |
| S6 | `.badge` + todas as cores (workflow, status, event_type) | Novo |
| S7 | `.filters-bar` + `.filter-pill` | Novo |
| S8 | `.detail-modal` + seções internas | Novo |
| S9 | `.analytics-container` (layout dashboard) | Novo |
| S10 | `.chart-card` (container de gráfico) | Novo |
| S11 | `.error-list` + `.error-item` | Novo |
| S12 | `.ranking-list` + `.ranking-item` | Novo |
| S13 | Responsivo (@media) para novos componentes | Novo |

### app.js — Mudanças

| # | O que | Tipo |
|---|-------|------|
| A1 | Importar novos ícones Lucide (ArrowRight, AlertTriangle, Clock, Activity, Tag, ChevronDown, X, Table, LayoutList, Mic, FileText, BarChart3) | Editar |
| A2 | Remover state `theme`, `toggleTheme` | Editar |
| A3 | Forçar dark mode no useEffect | Editar |
| A4 | View default: `'activity'` (não mais `'menu'`) | Editar |
| A5 | Atualizar navItems (nova ordem, novo item `activity`) | Editar |
| A6 | Remover botão theme toggle da Navbar | Editar |
| A7 | Adicionar `case 'activity'` no renderView switch | Editar |
| A8 | Adicionar `case 'analytics'` no renderView switch | Editar |
| A9 | **Componente `ActivityLog()`** (~500 linhas) — Tela 1 WhatsApp-like | Novo |
| A10 | **Componente `ExecutionAnalytics()`** (~400 linhas) — Tela 2 Dashboard | Novo |
| A11 | Sub: `ActivitySidebar()` — lista de usuários | Novo |
| A12 | Sub: `ActivityCard()` — card de interação estilo chat | Novo |
| A13 | Sub: `ActivityDetailModal()` — detalhe completo | Novo |
| A14 | Sub: `AnalyticsKPIs()` — 4 KPI cards | Novo |
| A15 | Sub: `AnalyticsCharts()` — 4 gráficos Chart.js | Novo |
| A16 | Sub: `ErrorList()` — lista de erros recentes | Novo |
| A17 | Sub: `UserRanking()` — top usuários | Novo |
| A18 | Helpers: `getDateRange()`, `formatDuration()`, `formatTime()`, `getBadgeClass()` | Novo |

**Estimativa:** app.js cresce de ~2.153 para ~3.100 linhas (~950 novas).

### Supabase (DB2) — SQL a executar

| # | Arquivo | O que faz |
|---|---------|-----------|
| 1 | `03-migration/05-create-rpc-kpis.sql` | RPC para KPIs |
| 2 | `03-migration/06-create-view-with-names.sql` | View com JOIN de nomes |

---

## NAVEGAÇÃO FINAL

```
[Activity Log] [Analytics] [Usuários] [Chat] [Conversas] [Docs] [Logout]
      ↓              ↓          ↓         ↓        ↓          ↓
  Tela 1:        Tela 2:    Existente  Existente  Existente  Existente
  WhatsApp-like  Dashboard  (users)    (chat)     (log)      (docs)
  execution_log  gráficos
  com nomes      KPIs
```

- **Activity Log** = view principal, estilo WhatsApp, mostra tudo em tempo real
- **Analytics** = dashboard com gráficos, KPIs, rankings, erros
- O resto continua como está

---

## FASES DE IMPLEMENTAÇÃO

| Fase | O que | Estimativa |
|------|-------|-----------|
| **I1** | Executar 2 SQLs no Supabase DB2 (RPC + view com nomes) | 2 min |
| **I2** | Dark mode only + remover toggle | 15 min |
| **I3** | Navbar: nova ordem + views `activity` e `analytics` | 15 min |
| **I4** | Componente ActivityLog: sidebar + cards + fetch | 2h |
| **I5** | CSS: activity-container, cards, sidebar, badges | 1h |
| **I6** | Filtros funcionais (período, workflow, status, busca) | 45 min |
| **I7** | Modal de detalhe da interação | 45 min |
| **I8** | Componente ExecutionAnalytics: KPIs + gráficos Chart.js | 1.5h |
| **I9** | CSS: analytics, chart-cards, error-list, ranking | 30 min |
| **I10** | Responsivo mobile (ambas as telas) | 30 min |
| **I11** | Deploy (coolify_upload/) | 10 min |

**Total: ~7.5h de trabalho focado**

---

## PRINCÍPIOS

1. **`supabaseDB2` para tudo novo** — nunca `supabase` (DB1)
2. **`v_exec_log_with_user` para mostrar dados** — traz nome automaticamente
3. **Glassmorphism** em tudo (blur + transparência + border sutil)
4. **Badges coloridos** por workflow/status/branch
5. **Não quebrar nada** — todas as views existentes continuam funcionando
6. **Dark mode only** — sem toggle, sem light mode

---

*Plano completo v2 — Argus (auditor-real squad)*
