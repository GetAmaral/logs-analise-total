# ANÁLISE COMPLETA DO SISTEMA DE LOGS — ESTADO FINAL

**Data:** 2026-03-25
**Total de registros:** 536
**Período:** 25/03/2026 (1 dia)

---

## RESUMO EXECUTIVO

```
SAÚDE GERAL:

  Registros úteis:     283/536  (53%)
  Registros lixo:      253/536  (47%)  ← fantasmas sem phone
  Cadeia completa:     ~60% dos users
  ai_response:         43 registros (funciona, mas perde ~30% por estar no Aggregate11)
  Erros capturados:    0 de 0 (paralelo = nunca captura)
  Sub-workflows:       0% cobertura
  Campos úteis:        4 de 18 campos nunca preenchidos
```

---

## TODOS OS PROBLEMAS — ORGANIZADOS POR PRIORIDADE

### 🔴 CRÍTICO (quebra a funcionalidade)

#### C1. 253 fantasmas (47% do banco é lixo)

**O que:** O node `Log: message_received` no Main está conectado direto no `trigger-whatsapp` sem filtro. O webhook do WhatsApp dispara para TUDO: mensagens reais, delivery receipts, read receipts, typing. 78% dos `message_received` têm phone=null, message=null.

**Fix:** Adicionar If node entre `trigger-whatsapp` e `Log: message_received`:
```
trigger-whatsapp → "É mensagem real?" (If) → [TRUE] → Log: message_received
```

**Condição do If:**
```
{{ $json.entry[0].changes[0].value.messages ? true : false }}
```

**Arquivo:** `06-nodes-n8n/fixes/01-FIX-filtro-fantasmas-main.json`

**Após fix, limpar lixo:**
```sql
DELETE FROM execution_log WHERE event_type = 'message_received' AND user_phone IS NULL;
```

---

#### C2. ai_response conectado ao Aggregate11 (perde ~30%)

**O que:** O node `Log: ai_response1` está conectado ao `Aggregate11`, não ao `Code in JavaScript`. O Aggregate nem sempre dispara (debounce, multi-mensagem), perdendo respostas da IA.

**Evidência por user:**
- 554396817394: 5 received, 0 ai_response = **0% completude**
- 554399016674: 4 received, 0 ai_response = **0% completude**
- 554398459145: 11 received, 2 ai_response = **18% completude**

**Fix:** Deletar `Log: ai_response1`. Colar novo node conectado ao `Code in JavaScript` (branch paralela com Switch2).

**Arquivo:** `06-nodes-n8n/fixes/02-FIX-ai-response-reconectar.json`

---

#### C3. 3 nodes de ação sem log

| Node | Função | Status |
|------|--------|--------|
| `HTTP - Create Tool` | Registrar gasto (variante 1) | SEM LOG |
| `HTTP - Create Calendar Tool` | Criar evento (variante 1) | SEM LOG |
| `HTTP - Create Calendar Tool4` | Criar evento (variante 3) | SEM LOG |

**Fix:** Colar e conectar. **Arquivo:** `06-nodes-n8n/fixes/03-FIX-acoes-orfas.json`

---

### 🟡 ALTO (dados incompletos)

#### A1. `ai_full_response` sempre null (0%)

O campo existe na tabela mas NENHUM node grava nele. A versão do node que tínhamos com optional chaining (`?.`) quebrava no N8N.

**Fix:** O node `02-FIX-ai-response-reconectar.json` já inclui esse campo com ternário correto.

---

#### A2. `routed_to` sempre null (0%)

O node `Log: message_routed` no Main deveria gravar `routed_to = "premium"` mas a expression não funciona ou o campo não está mapeado corretamente.

**Fix:** Verificar o node `Log: message_routed` no Main — confirmar que o campo `routed_to` está com:
```
={{ $('Get a row').item.json.plan_type === 'premium' ? 'premium' : 'standard' }}
```

---

#### A3. `interaction_id` inútil (cada row gera UUID diferente)

536 registros, 536 IDs únicos. Impossível agrupar eventos da mesma mensagem por este campo.

**Fix no frontend:** NÃO usar `interaction_id`. Agrupar por `created_at ASC` onde cada `message_received` inicia nova interação.

**Fix futuro no N8N:** Criar Code node no início do Premium que gera 1 UUID e passa pra todos os logs da mesma mensagem.

---

#### A4. `duration_ms` sempre null (0%)

Nenhum node seta este campo. Impossível medir latência.

**Fix no frontend:** Calcular pela diferença de timestamps: último evento - primeiro evento. Dados reais mostram média de **9 segundos**.

---

#### A5. `whatsapp_timestamp` só no Main (13%)

O Premium não seta este campo. Só o node `Log: message_received` no Main grava o timestamp original do WhatsApp.

**Fix:** Adicionar no node `Log: classification` do Premium:
```
whatsapp_timestamp = {{ $('premium').item.json.body.timestamp || null }}
```

---

#### A6. `ai_tools_called` quase sempre null (1%)

Só 8 de 536 registros têm tools. O node de ai_response usa ternário que retorna null quando `parsed_output.tool` não existe (maioria dos casos é `padrao` que não usa tool).

**Não é bug** — é comportamento correto. Ações `padrao` não chamam tools.

---

#### A7. 12 nodes de ação/envio SEM LOG no Premium

| Node | O que faz |
|------|----------|
| `HTTP - Create Tool` | Registrar gasto (variante 1) |
| `HTTP - Create Calendar Tool` | Criar evento (variante 1) |
| `HTTP - Create Calendar Tool4` | Criar evento (variante 3) |
| `Confirmar Exclusão Evento` | Envio WhatsApp confirmando exclusão |
| `Confirmar Exclusão Financeiro` | Envio WhatsApp confirmando exclusão |
| `Confirmar Exclusão Recorrente` | Envio WhatsApp confirmando exclusão |
| `HTTP Request — Basic Create Template` | Confirmação gasto com botões |
| `Enviar Nudge Google` | Pergunta "quer conectar Google?" |
| `Registrar Nudge Enviado` | Grava nudge no Supabase |
| `Registrar Sim` | Grava resposta sim |
| `Registrar Não` | Grava resposta não |
| `Enviar Tutorial Google` | Envia tutorial de conexão |

---

### 🟠 MÉDIO (funciona mas poderia ser melhor)

#### M1. `action_success` sempre true (0 falhas capturadas)

44 ações executadas, todas com `success=true`. Impossível que nunca houve erro — o problema é que logs rodam em **paralelo**, hardcoded `true`.

**Fix futuro:** Modo em série (log APÓS a ação HTTP, não paralelo).

---

#### M2. `session_id` nunca preenchido

Não há como agrupar interações em "sessões" (ex: gap >30min = nova sessão).

**Fix futuro:** Code node no início do Premium que verifica último log do user e decide se é mesma sessão ou nova.

---

#### M3. Credentials inconsistentes

| Nodes | Credential |
|-------|-----------|
| classification, ai_response, actions, excluir | `Total Supabase` |
| transcription, OCR image, OCR pdf | `Supabase account` |

Ambos funcionam, mas é confuso.

**Fix:** Padronizar para UM credential. Recomendo `Supabase account` (1ENA7UIm6ILehilJ) que é o mais usado no Premium.

---

### 🔵 FUTURO (zero cobertura em sub-workflows)

#### F1. Financeiro — 0 logs

Edição e exclusão de gastos não são registradas quando processadas pelo sub-workflow `Financeiro - Total`.

#### F2. Calendar WebHooks — 0 logs

CREATE/UPDATE/DELETE em eventos + sincronização com Google Calendar — invisível.

#### F3. Lembretes — 0 logs

Criação de lembretes e eventos recorrentes pelo sub-workflow — invisível.

#### F4. Report — 0 logs

Geração de PDF e envio de relatório via WhatsApp — invisível.

#### F5. Service Message 24h — 0 logs

Mensagens de reengajamento para usuários inativos — invisível.

---

## TABELA CONSOLIDADA — TUDO QUE PRECISA FAZER

| # | O que | Onde | Esforço | Arquivo no GitHub |
|---|-------|------|---------|-------------------|
| **C1** | Filtrar fantasmas | Main (N8N) | 5 min | `fixes/01-FIX-filtro-fantasmas-main.json` |
| **C2** | Reconectar ai_response | Premium (N8N) | 3 min | `fixes/02-FIX-ai-response-reconectar.json` |
| **C3** | 3 ações órfãs | Premium (N8N) | 5 min | `fixes/03-FIX-acoes-orfas.json` |
| **C1b** | Limpar fantasmas existentes | Supabase SQL | 1 min | `DELETE WHERE user_phone IS NULL` |
| **A1** | ai_full_response | Incluso no C2 | — | — |
| **A2** | routed_to | Main (N8N) | 3 min | Editar node existente |
| **A3** | Agrupamento no frontend | Site (JS) | Dev | `FIX-AGRUPAMENTO-CORRETO.md` |
| **A4** | Latência no frontend | Site (JS) | Dev | `FIX-AGRUPAMENTO-CORRETO.md` |
| **A5** | whatsapp_timestamp Premium | Premium (N8N) | 3 min | Editar node classification |
| **A7** | 12 nodes sem log | Premium (N8N) | 30 min | Colar + duplicar |
| **M1** | Falhas reais | Premium (N8N) | 1-2h | Modo série (futuro) |
| **M2** | session_id | Premium (N8N) | 30 min | Code node (futuro) |
| **M3** | Padronizar credential | Premium (N8N) | 15 min | Editar nodes |
| **F1-F5** | Sub-workflows | 5 workflows (N8N) | 2-3h | Criar nodes novos |

---

## PLANO DE EXECUÇÃO — ORDEM RECOMENDADA

### Bloco 1: Fixes urgentes (15 min)

```
1. Main: Colar If node "É mensagem real?" antes do Log: message_received
2. Premium: Deletar Log: ai_response1, colar novo conectado ao Code in JavaScript
3. Premium: Colar Log: action (órfã) nos 3 HTTP nodes desconectados
4. Supabase: DELETE FROM execution_log WHERE user_phone IS NULL
```

### Bloco 2: Complementos (15 min)

```
5. Main: Corrigir routed_to no Log: message_routed
6. Premium: Adicionar whatsapp_timestamp no Log: classification
7. Premium: Padronizar credential pra Supabase account em todos os log nodes
```

### Bloco 3: Frontend (dev)

```
8. groupIntoInteractions() com agrupamento por tempo
9. Latência calculada por timestamps
10. extracted_data mostrado no card (OCR imagem/PDF)
11. getUserMessageDisplay() para 🎤/🖼️/📄
```

### Bloco 4: Expansão (2-3h quando quiser)

```
12. 12 nodes faltantes no Premium (nudge, confirmações, template)
13. Financeiro: logs de UPDATE/DELETE gasto
14. Calendar: logs de CREATE/UPDATE/DELETE evento + Google sync
15. Lembretes: logs de criação
16. Report: logs de geração/envio
17. Service Message: logs de reengajamento
```

### Bloco 5: Polish (futuro)

```
18. Modo série para capturar falhas reais
19. interaction_id compartilhado (Code node)
20. session_id (lógica de gap 30min)
```

---

## ESTADO APÓS BLOCO 1+2+3

```
  Registros lixo:         0% (era 47%)
  Cadeia completa:       ~90% (era ~60%)
  ai_response:           ~95% (era ~70%)
  OCR no site:           ✅ funciona
  Latência no site:      ✅ calculada
  Erros capturados:      ainda 0% (precisa bloco 5)
  Sub-workflows:         ainda 0% (precisa bloco 4)
```

---

*Análise gerada por Argus (auditor-real) em 25/03/2026*
