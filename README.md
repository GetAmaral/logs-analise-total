# logs-analise-total

Sistema de logs centralizado do **Total Assistente** — tabela `execution_log` no Supabase + nodes de logging nos workflows N8N.

---

## Problema

| Metrica | Valor |
|---------|-------|
| Acoes de escrita nos workflows | **98** |
| Acoes logadas hoje | **8** |
| Acoes SEM cobertura | **74** |
| Conversas Standard perdidas | **100%** (apos 1h Redis TTL) |
| Transcricoes de audio perdidas | **100%** (apos 1h Redis TTL) |
| Tool calls / branch / acoes | **100%** perdidos imediatamente |

## Solucao

Tabela `execution_log` no Supabase que captura cada etapa do processamento:

```
WhatsApp msg → N8N trigger → Classificacao → IA responde → Acao executada → Log completo
```

---

## Estrutura do repositorio

```
logs-analise-total/
│
├── 01-analise/                          # Diagnostico atual
│   ├── analise-logs-existentes.md       # Mapeamento completo de logs e persistencia
│   └── analise-acoes-completa.md        # 98 acoes mapeadas, cobertura por workflow
│
├── 02-plano/                            # Plano de implementacao
│   └── PLANO-IMPLEMENTACAO-v2.md        # Passo a passo completo (7 fases)
│
├── 03-migration/                        # SQL pronto para executar
│   ├── 01-create-table.sql              # CREATE TABLE execution_log
│   ├── 02-create-indexes.sql            # Indices para performance
│   ├── 03-rls-policies.sql              # Row Level Security
│   └── 04-create-views.sql              # Views para a UI
│
├── 04-sanitizacao/                      # Regras de protecao de dados
│   └── REGRAS-SANITIZACAO.md            # O que logar vs o que NUNCA logar
│
└── 05-ui/                               # Blueprint da interface
    └── BLUEPRINT-UI.md                  # Componentes, queries, visual Apple-style
```

## Fases de implementacao

| Fase | O que | Status |
|------|-------|--------|
| 1 | Criar tabela no Supabase | Pendente |
| 2 | Log no Main (onboarding + roteamento) | Pendente |
| 3 | Log no Premium (Fix Conflito v2) | Pendente |
| 4 | Log no Standard (PRIORIDADE — hoje perde tudo) | Pendente |
| 5 | Log nos sub-workflows (Financeiro, Calendar, Lembretes, Report) | Pendente |
| 6 | Validacao + auditoria de seguranca | Pendente |
| 7 | Pagina no dashboard (visual Apple-style) | Futuro |

## Principios

- **CAMPOS EXPLICITOS** — nunca logar payload cru completo
- **ZERO tokens/keys/secrets** nos logs
- **Apenas ADICIONAR** nodes, nunca alterar existentes
- **Um workflow por vez**, checkpoint entre cada fase

---

*Gerado pelo squad auditor-real (Argus) — AIOS Core*
