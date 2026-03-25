# PLANO COMPLETO — Integração execution_log no analise-total

**Data:** 2026-03-25
**Repo:** github.com/luizporto-ai/analise-total
**Premissa:** Dark mode only. Não excluir funcionalidades. Reorganizar UX.

---

## 1. ARQUITETURA ATUAL DO PROJETO

### Estrutura de arquivos
```
analise-total/
├── index.html        ← Entry point (importmap CDN: React, Supabase, Lucide, Chart.js)
├── app.js            ← TODA a aplicação (2.153 linhas, React.createElement, sem JSX)
├── style.css         ← TODOS os estilos (1.629 linhas, CSS puro, glassmorphism)
└── coolify_upload/   ← Deploy (Dockerfile nginx:alpine)
```

### Stack (NÃO muda)
| Camada | Tecnologia |
|--------|-----------|
| React 18.2 | Via CDN esm.sh (sem build step) |
| Supabase JS 2.39.7 | Via CDN esm.sh |
| Chart.js 4.4.7 | Via CDN jsdelivr |
| Lucide React 0.263.1 | Via CDN esm.sh |
| CSS | Puro, CSS variables, glassmorphism |
| Deploy | nginx:alpine via Coolify |

**Padrão de código:** `const e = React.createElement;` — tudo usa `e('div', {...}, ...)`.

### Bancos de dados (2 instâncias Supabase)

| Alias | Project Ref | Para que | Variável no código |
|-------|-------------|---------|-------------------|
| **DB1** (mensagens) | `hkzgttizcfklxfafkzfl` | log_users_messages, log_total, resposta_ia, RPCs dashboard | `supabase` |
| **DB2** (principal) | `ldbdtakddxznfridsarn` | profiles, subscriptions, google_calendar_connections, **execution_log** | `supabaseDB2` |

**execution_log está no DB2** — já conectado via `supabaseDB2` com service_role.

### Páginas existentes (6)

| View ID | Componente | Linhas | Função |
|---------|-----------|--------|--------|
| `menu` | `Menu()` | 519-563 | Hub com 5 opções |
| `chat` | `ChatTotal()` | 681-1043 | Simulador WhatsApp (webhook N8N dev) |
| `log` | `UserLog()` | 1048-1277 | Histórico de mensagens por usuário (sidebar + chat) |
| `users` | `UserManager()` | 254-515 | CRUD de usuários (profiles + subscriptions) |
| `dashboard` | `Dashboard()` | 1345-2102 | KPIs log_total (RPCs + Chart.js) |
| `docs` | `Documentation()` | 567-674 | Browser de arquivos do GitHub |

### Tabelas usadas HOJE

**DB1:**
- `log_users_messages` — Pares mensagem↔resposta (UserLog + fetchSessions)
- `log_total` — Ações do sistema com categoria (Dashboard)
- `resposta_ia` — Fila de respostas em tempo real (ChatTotal)
- RPCs: `fn_dashboard_resumo`, `fn_dashboard_acoes_periodo`, `fn_dashboard_diario_periodo`
- Views: `v_dashboard_top_users`, `v_dashboard_atividade_hora`

**DB2:**
- `profiles` — Nome, email, phone, plan_type (UserManager + Dashboard)
- `subscriptions` — Plano e status (UserManager)
- `google_calendar_connections` — Status Google (UserManager + Dashboard)
- **`execution_log`** — NOVA (criada hoje, já com dados fluindo)
- **Views:** `v_exec_log_daily_summary`, `v_exec_log_branch_stats`, `v_exec_log_hourly_volume`, `v_exec_log_recent_errors`, `v_exec_log_plan_split`

---

## 2. O QUE VAI MUDAR

### 2.1 — Dark mode only

**Arquivo:** `style.css`
- Mover as variáveis de `[data-theme='dark']` para `:root`
- Remover bloco `[data-theme='dark']`
- Remover light mode vars do `:root` original

**Arquivo:** `app.js`
- Remover state `theme` e `toggleTheme`
- Remover botão Sun/Moon da Navbar
- Forçar `document.documentElement.setAttribute('data-theme', 'dark')` no mount

### 2.2 — Reorganizar navegação

**Arquivo:** `app.js` — Navbar component (linhas 218-249)

**Antes:**
```
Início | Chat | Logs | Usuários | Dashboard | Docs | [🌙] | [Logout]
```

**Depois:**
```
Activity Log | Dashboard | Usuários | Chat | Logs | Docs | [Logout]
```

Mudanças:
- Remover "Início" (Menu) — navbar já é o menu
- Adicionar "Activity Log" como nova view (`activity`)
- Renomear "Logs" → manter (é o histórico de conversas existente)
- View default ao logar: `activity` (não mais `menu`)

**Novo navItems:**
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

### 2.3 — Nova view: `activity`

**Componente:** `ActivityLog()` — a ser criado no `app.js`

---

## 3. COMPONENTE ActivityLog — ESPECIFICAÇÃO COMPLETA

### 3.1 — State

```javascript
function ActivityLog() {
    // Data
    const [logs, setLogs] = useState([]);
    const [kpis, setKpis] = useState(null);
    const [branchStats, setBranchStats] = useState([]);
    const [hourlyVolume, setHourlyVolume] = useState([]);

    // UI
    const [loading, setLoading] = useState(true);
    const [viewMode, setViewMode] = useState('timeline'); // 'timeline' | 'table'
    const [selectedLog, setSelectedLog] = useState(null); // modal detail
    const [showFilters, setShowFilters] = useState(false);

    // Filters
    const [periodo, setPeriodo] = useState('24h'); // '1h', '24h', '7d', '30d'
    const [filterWorkflow, setFilterWorkflow] = useState([]); // multi-select
    const [filterEventType, setFilterEventType] = useState([]); // multi-select
    const [filterBranch, setFilterBranch] = useState(null);
    const [filterStatus, setFilterStatus] = useState('all'); // 'all', 'success', 'error'
    const [searchText, setSearchText] = useState('');

    // Pagination
    const [page, setPage] = useState(0);
    const [hasMore, setHasMore] = useState(true);

    // Charts
    const lineChartRef = useRef(null);
    const doughnutChartRef = useRef(null);
    const lineChartInstance = useRef(null);
    const doughnutChartInstance = useRef(null);
}
```

### 3.2 — Fetch de dados

```javascript
async function fetchActivityData() {
    setLoading(true);
    const range = getDateRange(periodo);

    try {
        // Paralelo: KPIs + logs + branch stats + volume
        const [kpiRes, logsRes, branchRes, volumeRes] = await Promise.all([
            // KPIs do período
            supabaseDB2.rpc('fn_exec_log_kpis', {
                p_start: range.start,
                p_end: range.end
            }),
            // Timeline (paginada, 50 por vez)
            fetchLogs(range, 0),
            // Branch stats
            supabaseDB2
                .from('v_exec_log_branch_stats')
                .select('*')
                .order('total', { ascending: false })
                .limit(10),
            // Volume horário
            supabaseDB2
                .from('v_exec_log_hourly_volume')
                .select('*')
                .gte('hora', range.start)
        ]);

        if (kpiRes.data) setKpis(kpiRes.data[0] || null);
        if (logsRes) setLogs(logsRes);
        if (branchRes.data) setBranchStats(branchRes.data);
        if (volumeRes.data) setHourlyVolume(volumeRes.data);
    } catch(err) {
        console.error('ActivityLog fetch error:', err);
    } finally {
        setLoading(false);
    }
}

async function fetchLogs(range, pageNum) {
    let query = supabaseDB2
        .from('execution_log')
        .select('*')
        .not('user_phone', 'is', null)
        .gte('created_at', range.start)
        .lte('created_at', range.end)
        .order('created_at', { ascending: false })
        .range(pageNum * 50, (pageNum + 1) * 50 - 1);

    // Apply filters
    if (filterWorkflow.length > 0) {
        query = query.in('source_workflow', filterWorkflow);
    }
    if (filterEventType.length > 0) {
        query = query.in('event_type', filterEventType);
    }
    if (filterBranch) {
        query = query.eq('branch', filterBranch);
    }
    if (filterStatus === 'success') {
        query = query.eq('action_success', true);
    } else if (filterStatus === 'error') {
        query = query.eq('action_success', false);
    }
    if (searchText) {
        query = query.or(`user_message.ilike.%${searchText}%,ai_message.ilike.%${searchText}%`);
    }

    const { data, error } = await query;
    if (error) throw error;
    setHasMore(data.length === 50);
    return data;
}
```

### 3.3 — RPC a criar no Supabase (KPIs)

```sql
-- Nova RPC para KPIs do Activity Log
CREATE OR REPLACE FUNCTION fn_exec_log_kpis(p_start TIMESTAMPTZ, p_end TIMESTAMPTZ)
RETURNS TABLE(
    total_interacoes BIGINT,
    total_acoes BIGINT,
    acoes_sucesso BIGINT,
    acoes_falha BIGINT,
    total_erros BIGINT,
    taxa_sucesso NUMERIC,
    tempo_medio_ms NUMERIC,
    usuarios_unicos BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        count(*) FILTER (WHERE event_type = 'message_received') AS total_interacoes,
        count(*) FILTER (WHERE event_type = 'action_executed') AS total_acoes,
        count(*) FILTER (WHERE action_success = true) AS acoes_sucesso,
        count(*) FILTER (WHERE action_success = false) AS acoes_falha,
        count(*) FILTER (WHERE error_message IS NOT NULL) AS total_erros,
        CASE
            WHEN count(*) FILTER (WHERE event_type = 'action_executed') > 0
            THEN round(
                count(*) FILTER (WHERE action_success = true)::numeric /
                count(*) FILTER (WHERE event_type = 'action_executed')::numeric * 100, 1
            )
            ELSE 100
        END AS taxa_sucesso,
        round(avg(duration_ms) FILTER (WHERE duration_ms IS NOT NULL), 0) AS tempo_medio_ms,
        count(DISTINCT user_phone) AS usuarios_unicos
    FROM execution_log
    WHERE created_at >= p_start AND created_at <= p_end
      AND user_phone IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

### 3.4 — Render do componente

**Estrutura hierárquica:**

```
ActivityLog
├── Header ("Activity Log" + botão filtros + toggle timeline/tabela)
├── KPIGrid (4 cards)
├── FiltersPanel (colapsável)
├── ChartsRow (line chart + doughnut)
├── Timeline OU Table (baseado em viewMode)
│   ├── TimelineEntry (repetido por log)
│   └── LoadMore button
└── DetailModal (quando selectedLog != null)
```

### 3.5 — Sub-componentes

**KPIGrid:** 4 cards glass
- Interações (total_interacoes)
- Taxa de sucesso (taxa_sucesso + badge cor)
- Erros (total_erros)
- Usuários únicos (usuarios_unicos)

**FiltersPanel:** Grid com filtros
- Período: pills (1h, 24h, 7d, 30d)
- Workflow: pills toggleáveis (main, premium, financeiro...)
- Evento: pills toggleáveis (message_received, classification, ai_response, action_executed)
- Branch: dropdown
- Status: pills (Todos, Sucesso, Erro)
- Busca: input text

**ChartsRow:** 2 gráficos Chart.js
- Line chart: volume por hora (últimas 24h/7d baseado no período)
- Doughnut chart: distribuição de branches

**TimelineEntry:** Card glass com
- Hora + badge workflow + badge branch
- Mensagem do usuário (se disponível)
- Resposta da IA (se disponível)
- Footer: badge action_type + badge status + duration
- Clicável → abre DetailModal

**DetailModal:** Modal glass com todas as infos do log
- Seção Usuário (phone, plan, id)
- Seção Mensagem (text, type, timestamp WhatsApp)
- Seção Classificação (branch)
- Seção Resposta IA (message, action, tools)
- Seção Execução (input, output, success, error, duration)
- Seção Metadados (workflow, event_type, id, created_at)

---

## 4. INTEGRAÇÃO COM BANCO — MAPA COMPLETO

### Tabelas usadas pelo ActivityLog

| Tabela/View | Banco | Operação | Onde usa |
|-------------|-------|----------|---------|
| `execution_log` | DB2 | SELECT (paginado, filtrado) | Timeline + Table |
| `v_exec_log_daily_summary` | DB2 | SELECT | Dashboard existente (gráficos extras) |
| `v_exec_log_branch_stats` | DB2 | SELECT | Doughnut chart |
| `v_exec_log_hourly_volume` | DB2 | SELECT | Line chart |
| `v_exec_log_recent_errors` | DB2 | SELECT | Lista de erros (futuro) |
| `v_exec_log_plan_split` | DB2 | SELECT | Dashboard (futuro) |
| `fn_exec_log_kpis()` | DB2 | RPC | KPI cards |

### SQL adicional a executar no Supabase

Além das views já criadas (Fase 1), precisa da RPC `fn_exec_log_kpis` (mostrada acima no 3.3).

---

## 5. TODAS AS MUDANÇAS POR ARQUIVO

### index.html
- Nenhuma mudança necessária (imports CDN já cobrem tudo)

### style.css — Mudanças

| # | O que | Onde |
|---|-------|------|
| S1 | Dark mode only (mover vars) | `:root` + remover `[data-theme='dark']` |
| S2 | Classe `.kpi-grid` + `.kpi-card` | Novo bloco |
| S3 | Classe `.timeline-entry` + variantes | Novo bloco |
| S4 | Classe `.filters-panel` + `.filter-pill` | Novo bloco |
| S5 | Classe `.badge` + cores por workflow/status | Novo bloco |
| S6 | Classe `.detail-modal` + seções internas | Novo bloco |
| S7 | Classe `.charts-row` | Novo bloco |
| S8 | Classe `.data-table` (view tabela) | Novo bloco |
| S9 | Responsivo para novos componentes | Dentro dos `@media` existentes |

### app.js — Mudanças

| # | O que | Onde | Tipo |
|---|-------|------|------|
| A1 | Importar novos ícones Lucide | Linha 3-22 | Editar (adicionar: ArrowRight, AlertTriangle, Clock, Activity, Brain, Tag, ChevronDown, ChevronUp, X, Table, LayoutList) |
| A2 | Remover state `theme` e `toggleTheme` | App() linha 78, 174 | Editar |
| A3 | Forçar dark mode no mount | useEffect linha 87-90 | Editar |
| A4 | Adicionar view `activity` no switch | renderView() linha 184-203 | Editar |
| A5 | Mudar view default de `menu` para `activity` | useState linha 77 | Editar |
| A6 | Atualizar navItems | Navbar() linha 219-226 | Editar |
| A7 | Remover botão theme toggle da Navbar | Navbar() linha 235-241 | Editar |
| A8 | Componente `ActivityLog()` | NOVO (~400 linhas) | Adicionar |
| A9 | Sub-componente `KPIGrid()` | NOVO (~60 linhas) | Dentro de ActivityLog |
| A10 | Sub-componente `FiltersPanel()` | NOVO (~80 linhas) | Dentro de ActivityLog |
| A11 | Sub-componente `TimelineEntry()` | NOVO (~80 linhas) | Dentro de ActivityLog |
| A12 | Sub-componente `DetailModal()` | NOVO (~120 linhas) | Dentro de ActivityLog |
| A13 | Sub-componente `DataTable()` | NOVO (~60 linhas) | Dentro de ActivityLog |
| A14 | Helpers: `getDateRange()`, `formatDuration()`, `getBadgeClass()` | NOVO (~30 linhas) | Utilitários |

**Estimativa:** app.js cresce de ~2.153 para ~2.980 linhas (~830 linhas novas).

---

## 6. CORES E BADGES — REFERÊNCIA COMPLETA

### Badges de workflow (source_workflow)

| Workflow | CSS Class | Background | Text |
|----------|-----------|-----------|------|
| main | `.badge-main` | `hsla(215, 20%, 50%, 0.15)` | `hsl(215, 20%, 65%)` |
| premium | `.badge-premium` | `hsla(270, 60%, 60%, 0.15)` | `hsl(270, 60%, 70%)` |
| financeiro | `.badge-financeiro` | `hsla(150, 60%, 50%, 0.15)` | `hsl(150, 60%, 60%)` |
| calendar | `.badge-calendar` | `hsla(30, 80%, 55%, 0.15)` | `hsl(30, 80%, 65%)` |
| lembretes | `.badge-lembretes` | `hsla(45, 80%, 55%, 0.15)` | `hsl(45, 80%, 65%)` |
| report | `.badge-report` | `hsla(190, 70%, 50%, 0.15)` | `hsl(190, 70%, 60%)` |
| service_msg | `.badge-service` | `hsla(280, 40%, 50%, 0.15)` | `hsl(280, 40%, 65%)` |

### Badges de status

| Status | CSS Class | Visual |
|--------|-----------|--------|
| success/completed | `.badge-success` | Verde |
| error | `.badge-error` | Vermelho |
| pending/processing | `.badge-pending` | Amarelo (pulse) |

### Badges de event_type

| Event | Label | Ícone Lucide |
|-------|-------|-------------|
| message_received | Recebida | MessageCircle |
| transcription | Transcrição | Mic (adicionar no import) |
| audio_summary | Resumo | FileText (adicionar) |
| message_routed | Roteada | ArrowRight |
| classification | Classificação | Tag |
| ai_response | IA | Zap |
| action_executed | Ação | Activity |
| error | Erro | AlertTriangle |

---

## 7. FASES DE IMPLEMENTAÇÃO

| Fase | O que fazer | Arquivo | Estimativa |
|------|------------|---------|-----------|
| **I1** | Executar RPC `fn_exec_log_kpis` no Supabase SQL Editor | Supabase | 2 min |
| **I2** | Dark mode only + remover toggle | style.css + app.js | 15 min |
| **I3** | Reorganizar navbar + adicionar view `activity` | app.js | 15 min |
| **I4** | Componente ActivityLog (fetch + KPIs + timeline básica) | app.js | 1.5h |
| **I5** | CSS dos novos componentes (KPI, timeline, badges, filtros) | style.css | 1h |
| **I6** | Filtros funcionais | app.js | 45 min |
| **I7** | Gráficos Chart.js (line + doughnut) | app.js | 45 min |
| **I8** | Modal de detalhe | app.js + style.css | 45 min |
| **I9** | View tabela (toggle timeline/tabela) | app.js + style.css | 30 min |
| **I10** | Responsivo mobile | style.css | 30 min |
| **I11** | Deploy (copiar para coolify_upload/) | Arquivos | 10 min |

**Total estimado: ~6h de trabalho conjunto**

---

## 8. CHECKLIST PRÉ-IMPLEMENTAÇÃO

- [x] Tabela `execution_log` criada no Supabase (DB2)
- [x] Índices criados
- [x] RLS ativo
- [x] Views criadas (`v_exec_log_*`)
- [x] Dados fluindo via N8N (Main + Premium)
- [ ] RPC `fn_exec_log_kpis` criada (Fase I1)
- [ ] Depois: implementar I2 a I11

---

*Plano completo — Argus (auditor-real squad)*
