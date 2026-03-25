# Blueprint UI — Activity Log Dashboard

Visual **Apple-style**: clean, espacado, tipografia clara, dark mode nativo.

---

## Stack existente (reutilizar)

| Camada | Tecnologia |
|--------|-----------|
| Framework | React 18 + TypeScript + Vite |
| UI | shadcn/ui (Radix UI primitives) |
| Styling | TailwindCSS (dark mode via class) |
| Tables | TanStack React Table |
| State | TanStack React Query |
| Charts | Recharts + Chart.js |
| Icons | Lucide React |
| Export | jspdf + xlsx |

## Componentes existentes que REUTILIZAMOS

| Componente existente | Onde usar |
|---------------------|-----------|
| `AllTransactionsModal` (filtros + export) | Base para LogFilters |
| `TransactionsDataGrid` (tabela paginada) | Base para LogDataTable |
| `ActiveSessions` (cards de atividade) | Inspiracao para ActivityTimeline |
| `ReportsView` (KPIs + graficos) | Base para LogKPICards |
| `CustomBarChart` / `CustomDonutChart` | Base para graficos de logs |

---

## Rota

```
/dashboard/activity-log
```

---

## Layout da pagina

```
┌─────────────────────────────────────────────────────────┐
│  Activity Log                              [Filtros v]  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │ Interacoes│ │  Sucesso │ │  Erros   │ │Tempo med.│  │
│  │   127     │ │  94.2%   │ │    3     │ │  2.1s    │  │
│  │  +12 hoje │ │  ↑ 1.3%  │ │  ↓ 2    │ │  ↓ 0.3s  │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘  │
│                                                         │
│  ┌─────────────────────────┐ ┌─────────────────────────┐│
│  │   Volume por hora       │ │  Top intents            ││
│  │   ▁▂▃▅▇█▇▅▃▂▁          │ │  criar_gasto    ████ 34 ││
│  │                         │ │  criar_evento   ███  28 ││
│  │   Area chart (Recharts) │ │  padrao         ██   19 ││
│  └─────────────────────────┘ └─────────────────────────┘│
│                                                         │
│  ┌─────────────────────────────────────────────────────┐│
│  │  Timeline                                           ││
│  │                                                     ││
│  │  10:32  Premium  criar_gasto                        ││
│  │  ┌─────────────────────────────────────────────┐    ││
│  │  │ "registra 45 reais almoco"                  │    ││
│  │  │                                             │    ││
│  │  │ IA: "Registrei R$45 em Alimentacao!"        │    ││
│  │  │                                             │    ││
│  │  │ [criar_gasto] [sucesso] [2.1s]              │    ││
│  │  └─────────────────────────────────────────────┘    ││
│  │                                                     ││
│  │  10:28  Standard  padrao                            ││
│  │  ┌─────────────────────────────────────────────┐    ││
│  │  │ "bom dia"                                   │    ││
│  │  │                                             │    ││
│  │  │ IA: "Bom dia! Como posso ajudar?"           │    ││
│  │  │                                             │    ││
│  │  │ [padrao] [sucesso] [1.8s]                   │    ││
│  │  └─────────────────────────────────────────────┘    ││
│  │                                                     ││
│  │  [Carregar mais...]                                 ││
│  └─────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

---

## Componentes a construir

### 1. LogKPICards

4 cards no topo. Dados da view `v_exec_log_daily_summary`.

```tsx
// Exemplo de estrutura
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
  <Card className="rounded-2xl shadow-sm">
    <CardContent className="p-6">
      <p className="text-sm text-muted-foreground">Interacoes hoje</p>
      <p className="text-3xl font-semibold tracking-tight">127</p>
      <p className="text-xs text-green-500">+12 vs ontem</p>
    </CardContent>
  </Card>
  ...
</div>
```

### 2. LogFilters

Barra de filtros. Reutilizar pattern do `AllTransactionsModal`.

| Filtro | Campo | Componente shadcn |
|--------|-------|-------------------|
| Periodo | `created_at` | DatePickerWithRange |
| Workflow | `source_workflow` | Select com badges coloridos |
| Tipo de evento | `event_type` | MultiSelect / ToggleGroup |
| Intent | `branch` | Select |
| Status | `action_success` | ToggleGroup (sucesso/falha/todos) |
| Plano | `user_plan` | ToggleGroup (premium/standard/free) |
| Busca | `user_message`, `ai_message` | Input com debounce |

### 3. ActivityTimeline

Timeline vertical com cards. Cada card = uma interacao (agrupada por `interaction_id`).

**Icones por event_type (Lucide):**

| event_type | Icone | Cor |
|-----------|-------|-----|
| message_received | MessageSquare | blue |
| transcription | Mic | purple |
| audio_summary | FileText | purple |
| message_routed | ArrowRight | gray |
| classification | Brain | amber |
| ai_response | Bot | green |
| action_executed | Zap | emerald |
| interaction_complete | CheckCircle | green |
| error | AlertCircle | red |

**Badges por status:**

| status | Badge | Estilo |
|--------|-------|--------|
| completed | Sucesso | `bg-green-100 text-green-700 dark:bg-green-900/30` |
| error | Erro | `bg-red-100 text-red-700 dark:bg-red-900/30` |
| processing | Processando | `bg-amber-100 text-amber-700` (com pulse animation) |
| pending | Pendente | `bg-gray-100 text-gray-500` |

**Badges por source_workflow:**

| Workflow | Cor |
|----------|-----|
| premium | `bg-violet-100 text-violet-700` |
| standard | `bg-blue-100 text-blue-700` |
| main | `bg-gray-100 text-gray-700` |
| financeiro | `bg-emerald-100 text-emerald-700` |
| calendar | `bg-orange-100 text-orange-700` |
| lembretes | `bg-amber-100 text-amber-700` |
| report | `bg-cyan-100 text-cyan-700` |

### 4. LogCharts

Dois graficos lado a lado:
- **Volume por hora** — Area chart (Recharts) com gradiente suave
- **Top intents** — Horizontal bar chart

### 5. InteractionDetail

Ao clicar em um card na timeline, abre um Sheet (shadcn) com detalhe completo:

```
┌─────────────────────────────────────┐
│  Detalhe da Interacao          [X]  │
│                                     │
│  Usuario: +55 43 9193-XXXX          │
│  Plano: Premium                     │
│  Workflow: premium                  │
│  Horario: 25/03/2026 10:32:15      │
│  Duracao: 2.1s                      │
│                                     │
│  ─── Mensagem ──────────────────    │
│  "registra 45 reais almoco"         │
│  Tipo: text                         │
│                                     │
│  ─── Classificacao ─────────────    │
│  Branch: criar_gasto                │
│                                     │
│  ─── Resposta IA ───────────────    │
│  "Registrei seu gasto de R$45,00    │
│   na categoria Alimentacao!"        │
│  Acao: registrar_gasto              │
│                                     │
│  ─── Execucao ──────────────────    │
│  Tool: registrar_financeiros        │
│  Input: {nome: "Almoco",            │
│          valor: 45,                  │
│          categoria: "Alimentacao"}   │
│  Status: Sucesso                    │
│                                     │
└─────────────────────────────────────┘
```

### 6. LogDataTable

Tabela detalhada para analise. Reutilizar `TransactionsDataGrid` pattern.

Colunas:
| Coluna | Campo | Sortable | Filterable |
|--------|-------|----------|-----------|
| Hora | created_at | Sim | Sim (range) |
| Usuario | user_phone | Sim | Sim |
| Plano | user_plan | Sim | Sim |
| Workflow | source_workflow | Sim | Sim |
| Intent | branch | Sim | Sim |
| Mensagem | user_message (truncada) | Nao | Sim (busca) |
| Resposta | ai_message (truncada) | Nao | Sim (busca) |
| Status | action_success | Sim | Sim |
| Tempo | duration_ms | Sim | Nao |

Export: PDF + Excel (jspdf + xlsx)

---

## Queries do frontend (via TanStack Query)

```typescript
// Hook: useActivityLog
const useActivityLog = (filters: LogFilters) => {
  return useQuery({
    queryKey: ['activity-log', filters],
    queryFn: () => supabase
      .from('execution_log')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(50)
      // ... filters
  });
};

// Hook: useLogKPIs
const useLogKPIs = () => {
  return useQuery({
    queryKey: ['log-kpis', 'today'],
    queryFn: () => supabase
      .from('v_exec_log_daily_summary')
      .select('*')
      .gte('dia', new Date().toISOString().split('T')[0])
  });
};

// Hook: useBranchStats
const useBranchStats = () => {
  return useQuery({
    queryKey: ['branch-stats'],
    queryFn: () => supabase
      .from('v_exec_log_branch_stats')
      .select('*')
      .order('total', { ascending: false })
      .limit(10)
  });
};
```

---

## Estilo Apple-style (guidelines)

- `rounded-2xl` em todos os cards
- Sombra suave: `shadow-sm hover:shadow-md transition-shadow`
- Espacamento generoso: `p-6`, `gap-4`, `space-y-4`
- Tipografia: Inter/Roboto, hierarquia clara (`text-3xl font-semibold` para numeros, `text-sm text-muted-foreground` para labels)
- Cores: usar HSL variables do shadcn theme, nada hardcoded
- Dark mode: `dark:bg-zinc-900 dark:text-zinc-100`
- Animacoes: `transition-all duration-200`, skeleton loading via shadcn `<Skeleton />`
- Bordas: `border border-border/50` (sutil)
- Icones: Lucide, tamanho `w-4 h-4` em badges, `w-5 h-5` em cards
