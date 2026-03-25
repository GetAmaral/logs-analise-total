# Analise de Logs e Persistencia de Dados - Workflows n8n

**Data da analise:** 2026-03-18
**Analise READ-ONLY - nenhum workflow foi modificado.**

---

## 1. MAIN WORKFLOW - "Main - Total Assistente" (ID: 9WDlyel5xRCLAvtH)

### Funcao Principal
Ponto de entrada via WhatsApp (trigger-whatsapp). Responsavel por:
- Onboarding de novos usuarios (fluxo de cadastro com OTP)
- Roteamento de usuarios autenticados para o workflow Premium (via HTTP POST)
- Transcricao de audio e funcionalidade de "Resumir" audio
- Log de todas as mensagens do onboarding

### Tabelas Escritas (Supabase)

#### Tabela: `log_users_messages`
Escrita por **9 nodes** (Create a row, Create a row3, Create a row6, Create a row7, Create a row8, Create a row9, Create a row10, e mais).

**Campos salvos em TODOS os nodes de log_users_messages:**
| Campo | Valor |
|---|---|
| `user_phone` | Telefone do usuario (wa_id) |
| `user_id` | `ONBOARDING-{phone}` (durante onboarding) |
| `user_name` | `ONBOARDING-{phone}` (durante onboarding) |
| `user_email` | `ONBOARDING-{phone}` (durante onboarding) |
| `user_message` | Mensagem do usuario (texto bruto do WhatsApp) |
| `ai_message` | Resposta hardcoded do bot (mensagens fixas do onboarding) |

**IMPORTANTE:** No Main, o log_users_messages so e usado para o fluxo de ONBOARDING. As mensagens de usuarios ja autenticados NAO sao logadas aqui - sao enviadas ao workflow Premium via HTTP.

#### Tabela: `phones_whatsapp`
Escrita/atualizada por **8 nodes** (Create a row1, Update a row, Update a row1, Update a row3, Update a row4, Update stg to 4, Update stg to 5, Update stg to 6, Corrigir volta stg 2).

**Campos:**
| Campo | Valor |
|---|---|
| `phone` | Numero WhatsApp (wa_id) |
| `stg` | Estagio do onboarding (1-6) |
| `email` | Email do usuario (adicionado no stg 3) |

#### Tabela: `profiles`
- **Create a row2**: Cria perfil com `email` e `phone`
- **Update a row2**: Atualiza `phone` no perfil existente (filtro por email)
- **Get a row / Get a row4**: Leituras para verificar perfil

### Node "Resumir" (httpRequest)
- NAO e um resumo de IA automatico
- Envia uma mensagem interativa (botao) via WhatsApp Graph API perguntando: "Deseja um resumo desse audio?"
- O botao tem ID `btn_resumir` com titulo "Resuma para mim"

### Nodes Redis
| Node | Operacao | Chave | Valor | TTL |
|---|---|---|---|---|
| `Redis` (set) | SET | `transcricao:{wa_id}` | Texto da transcricao do audio | 3600s (1h) |
| `Redis1` (get) | GET | `transcricao:{wa_id}` | Recupera transcricao salva | - |

### Transcricao de Audio
1. **Download do audio**: Get Media Info1 -> Download File1 (via WhatsApp API)
2. **Transcricao**: Node "Transcribe a recording" (OpenAI Whisper, idioma: pt)
3. **Armazenamento**: Texto transcrito salvo no Redis (chave `transcricao:{wa_id}`, TTL 1h)
4. **Envio ao usuario**: Texto transcrito enviado via WhatsApp (Send message5)
5. **Resumo**: Se usuario clica "Resuma para mim" -> Redis1 recupera transcricao -> "Message a model" (GPT-4.1-mini, system: "resuma o texto") -> envia resumo via WhatsApp

**A TRANSCRICAO NAO E SALVA NO SUPABASE.** Fica apenas no Redis por 1 hora.

### Node "Message a model"
- Modelo: GPT-4.1-mini
- System prompt: "Voce e um assistente que resume textos de forma clara e concisa em portugues brasileiro. Resuma o texto mantendo os pontos principais. Apenas resuma."
- Input: texto da transcricao recuperado do Redis
- Max tokens: 500, temperature: 0.3

---

## 2. PREMIUM WORKFLOW - "Fix Conflito v2" (ID: tyJ3YAAtSg1UurFj)

### Funcao Principal
Workflow de usuarios Premium. Recebe dados do Main via webhook. Processa mensagens com IA (AI Agent), classifica intencoes, executa acoes (financeiro, agenda, relatorios).

### Tabelas Escritas (Supabase)

#### Tabela: `log_users_messages`
Escrita por **1 unico node**: `Create a row1`

**Campos:**
| Campo | Valor | Origem |
|---|---|---|
| `user_id` | ID do usuario | `premium.body.user_id` |
| `user_name` | Nome do usuario | `premium.body.user_name` ou email |
| `user_phone` | Telefone | `premium.body.user_phone` |
| `user_message` | Mensagem do usuario | `Merge1.mensagem` (mensagem consolidada pos-debounce) |
| `ai_message` | Resposta da IA | `Code in JavaScript.parsed_output.mensagem` |
| `user_email` | Email | `profiles.email` (via Get a row) |

**IMPORTANTE:** Este e o UNICO ponto de log de conversas no Premium. O node `Create a row1` e acionado APOS o `Get a row` (profiles), ou seja, so loga se o perfil for encontrado.

#### Tabela: `recurrency_report` (somente leitura)
- Node `buscar_relatorios`: GET - busca relatorios recorrentes

#### Tabela: `calendar` (somente leitura)
- Nodes `Buscar Conflitos (Batch)` e `Buscar Conflitos (Unico)`: getAll - busca eventos para verificar conflitos

#### Tabela: `gc_nudge` (somente leitura)
- Node `Buscar Nudge`: GET - verifica nudge do Google Calendar

#### Tabela: `google_calendar_connections` (somente leitura)
- Node `Get a row1`: GET - verifica conexao do Google Calendar

#### Tabela: `profiles` (somente leitura)
- Node `Get a row`: GET - busca perfil do usuario por email

### Node "AI Agent"
- **Modelo**: Conectado via OpenAI Chat Model (separado)
- **System prompt** (resumo das regras):
  - Data atual e nome do usuario injetados dinamicamente
  - Financeiro recente via Redis (`{phone}_idobject`)
  - Persona: "Total, assistente pessoal de agenda e financas no WhatsApp"
  - Tom: secretaria profissional, educada, eficiente, acolhedora
  - Escopo: AGENDA (CRUD eventos/lembretes), FINANCEIRO (CRUD gastos/receitas), RELATORIOS, AUDIO (transcricao), PDF/IMAGEM (extracao), CONFLITOS
  - Fora do escopo: planejamentos, investimentos, dashboards, coaching, transacoes financeiras, piadas
  - Formato de resposta: JSON com `acao`, `mensagem`, `tool`
- **Input**: Mensagens do usuario (consolidadas do debounce Redis, deduplicadas)
- **Tools disponiveis**: Think, buscar_financeiro, editar_financeiro, excluir_financeiro, registrar_financeiros, buscar_eventos, editar_evento, editar_eventos, editar_eventos1, excluir_evento, criar_lembrete

### Node "Redis Chat Memory"
- Tipo: `memoryRedisChat` (LangChain)
- Chave: `chatmem-{phone}`
- TTL: **300 segundos (5 minutos)**
- Funcao: Memoria de curto prazo para o AI Agent manter contexto da conversa

### Node "formatacao_mensagem" (Code)
- Formata mensagem de itens registrados POR CATEGORIA
- Recebe output do "Code in JavaScript" (itens parseados da IA)
- Agrupa gastos por `categoria_gasto`
- Formata cada item como `- Nome, R$valor`
- Limita a 3500 caracteres (limite do WhatsApp)
- Retorna `mensagem_formatada`

### Node "Escolher Branch" (chainLlm)
- Classificador de intencoes usando LLM (OpenAI Chat Model2)
- Modelo conectado via Redis Chat Memory7 (historico recente para contexto)
- Output: JSON `{ "branch": "<nome>" }`
- Branches possiveis: `criar_gasto`, `buscar_gasto`, `editar_gasto`, `excluir_gasto`, `criar_evento`, `buscar_evento`, `editar_evento`, `excluir_evento`, `criar_lembrete`, `gerar_relatorio`, `padrao`
- Regras de prioridade:
  - Mensagem atual > historico
  - Verbos imperativo (paga, transfere) -> `padrao` (nao executa transacoes)
  - Verbos declaracao/passado (paguei, transferi) -> `criar_gasto`
  - Recorrencia tem prioridade maxima

### Node "Code in JavaScript"
- Parser generico da saida do AI Agent
- Recebe `json.output` (string JSON da IA)
- Limpa markdown, extrai JSON, parseia
- Se `acao` = `registrar_gasto` ou `criar_evento` e `tool` e array: explode em multiplos items
- Resultado: `parsed_output` com `acao`, `mensagem`, `tool`

### Debounce Redis (Acumulacao de Mensagens)
Fluxo completo:
1. `firstGet`: GET `{phone}_debounce` - verifica se ja tem mensagens acumuladas
2. `pushRedisMessage`: PUSH na lista `{phone}_debounce` - adiciona `{"message_user":"..."}`
3. Espera (If17/If18/If19 com delays)
4. `lastGet`/`mediumGet`: GET novamente para verificar se novas mensagens chegaram
5. Se nenhuma nova: `Redis3` DELETE a lista e processa todas as mensagens acumuladas
6. Se novas chegaram: espera mais (no-op)

### Acoes via HTTP (nao Supabase direto)
- **Registrar gasto**: POST `https://totalassistente.com.br/webhook/registrar-gasto` com campos: `nome_gasto`, `valor_gasto`, `categoria_gasto`, `entra_sai_gasto`, `data_gasto`, `id_user`, `tipo_gasto`
- **Criar evento**: POST `https://totalassistente.com.br/webhook/5e0f5e77-...` com campos: `nome_evento`, `descricao_evento`, `data_inicio_evento`, `data_fim_evento`, `id_user`
- Buscar/editar/excluir financeiro e eventos: via httpRequestTool nodes (chamados pelo AI Agent)

---

## 3. STANDARD WORKFLOW - "User Standard - Total" (ID: c8gtSmh1BPzZXbJa)

### Funcao Principal
Workflow de usuarios Standard (plano basico). Estrutura similar ao Premium mas com menos funcionalidades.

### Tabelas Escritas (Supabase)

**NENHUMA TABELA DE LOG E ESCRITA.**

- `buscar_relatorios`: GET (somente leitura) na tabela `recurrency_report`
- NAO existe node `Create a row` para `log_users_messages`
- NAO existe NENHUM node de escrita Supabase

### Diferencas em relacao ao Premium

**O que o Standard TEM a mais:**
- Nodes de limites financeiros: `add_limite`, `edit_limite`, `excluir_limite`, `buscar_limite`
- Prompts especificos de relatorio: `prompt_rel_semanal`, `prompt_rel_mensal`

**O que o Standard NAO TEM (presente no Premium):**
- `Create a row1` (log de log_users_messages) -- **SEM LOG DE MENSAGENS**
- Nodes de conflito de agenda (Buscar Conflitos, Aviso Conflito, etc.)
- Text Classifier
- Convert to File
- Nodes de nudge do Google Calendar
- Nodes de confirmacao de exclusao com botoes interativos
- Buscar eventos (buscar_eventos tool)
- Prompts de agenda detalhados (prompt_criar1, prompt_busca1, etc.)

### Redis Chat Memory (Standard)
- Chave: `chatmem-{phone}` (via Evolution API- Take all1)
- TTL: **3600 segundos (1 hora)** -- DIFERENTE do Premium que usa 300s (5min)

---

## 4. RESUMO: TABELAS E CAMPOS POR WORKFLOW

| Workflow | Tabela | Operacao | Campos |
|---|---|---|---|
| Main | `log_users_messages` | CREATE | user_phone, user_id, user_name, user_email, user_message, ai_message |
| Main | `phones_whatsapp` | CREATE/UPDATE | phone, stg (1-6), email |
| Main | `profiles` | CREATE/UPDATE | email, phone |
| Premium | `log_users_messages` | CREATE | user_id, user_name, user_phone, user_message, ai_message, user_email |
| Standard | *(nenhuma escrita)* | - | - |

---

## 5. GAPS DE LOGGING IDENTIFICADOS

### CRITICOS

1. **Standard SEM log de mensagens**: O workflow Standard NAO possui NENHUM node de escrita em `log_users_messages`. Todas as conversas de usuarios do plano Standard sao perdidas apos o TTL do Redis (1h).

2. **Transcricao de audio NAO persistida**: O texto transcrito pelo Whisper e armazenado APENAS no Redis com TTL de 1 hora. Apos isso, e perdido permanentemente. Nenhuma transcricao e salva no Supabase.

3. **Resumos de audio NAO logados**: O resultado do "Message a model" (resumo da transcricao) e enviado ao usuario via WhatsApp mas NAO e salvo em nenhum lugar.

4. **Respostas da IA (Premium)**: A resposta da IA so e logada como `ai_message` no campo texto. O JSON completo da resposta (incluindo `acao` e `tool`) NAO e salvo. Perde-se a informacao estruturada de qual acao foi tomada.

5. **Tool calls/acoes NAO logados**: Quando a IA chama ferramentas (registrar_financeiro, criar_evento, etc.), essas chamadas NAO sao registradas em log. Nao ha como auditar quais acoes foram executadas, apenas a mensagem textual.

6. **Sem campo de branch/classificacao**: O resultado do "Escolher Branch" (classificacao da intencao) NAO e salvo no log. Nao ha como analisar como as mensagens sao classificadas.

7. **Sem campo de timestamp customizado**: O log depende do `created_at` default do Supabase. Nao ha campo para timestamp da mensagem original do WhatsApp.

8. **Sem campo de tipo de mensagem**: Nao se distingue no log se a mensagem original era texto, audio, imagem ou documento.

9. **Sem campo de sessao/conversa**: Nao ha session_id ou conversation_id para agrupar mensagens da mesma sessao.

10. **Dados de documento/imagem extraidos NAO logados**: Quando o usuario envia PDF ou imagem, os dados extraidos sao processados mas nao ha log da extracao.

### MODERADOS

11. **Main - Onboarding usa IDs provisorios**: Durante o onboarding, `user_id`, `user_name` e `user_email` sao todos `ONBOARDING-{phone}`, dificultando rastreamento pos-ativacao.

12. **Premium - Log conectado ao Get a row (profiles)**: Se o Get a row falhar ou nao encontrar perfil, o log pode nao ser escrito.

13. **Memoria Redis de curto prazo**: Premium usa 5min, Standard usa 1h. Apos TTL, todo o contexto de conversa e perdido.

---

## 6. FLUXO ATUAL: log_users_messages

### Main (Onboarding)
```
trigger-whatsapp -> Switch (stg) -> [cada estagio do onboarding]
  -> Create a row (log_users_messages)
     user_message: texto do usuario
     ai_message: mensagem fixa do bot (hardcoded)
     user_id/name/email: ONBOARDING-{phone}
```

### Premium
```
webhook (premium) -> debounce Redis -> Escolher Branch -> AI Agent -> Code in JavaScript (parse)
  -> Switch2 (acao) -> [HTTP Create Tool / Calendar Tool / etc]
  -> ... -> Get a row (profiles)
  -> Create a row1 (log_users_messages)
     user_message: mensagem consolidada (pos-debounce)
     ai_message: parsed_output.mensagem (texto que a IA enviou)
```

### Standard
```
webhook -> debounce Redis -> Escolher Branch -> AI Agent -> Code in JavaScript
  -> Switch2 -> [acoes]
  -> Send message (WhatsApp)
  *** NENHUM LOG ***
```

---

## 7. ONDE VÃO AS COISAS HOJE

| Dado | Onde vai | Persistencia |
|---|---|---|
| Mensagem do usuario (onboarding) | `log_users_messages.user_message` | Permanente (Supabase) |
| Resposta do bot (onboarding) | `log_users_messages.ai_message` | Permanente (Supabase) |
| Mensagem do usuario (Premium) | `log_users_messages.user_message` | Permanente (Supabase) |
| Resposta da IA (Premium) | `log_users_messages.ai_message` | Permanente (Supabase) |
| Mensagem do usuario (Standard) | **NENHUM LUGAR** | Perdido apos Redis TTL (1h) |
| Resposta da IA (Standard) | **NENHUM LUGAR** | Perdido apos Redis TTL (1h) |
| Transcricao de audio | Redis `transcricao:{phone}` | 1 hora (Redis TTL) |
| Resumo de audio | **NENHUM LUGAR** | Perdido imediatamente |
| Classificacao (branch) | **NENHUM LUGAR** | Perdido imediatamente |
| Tool calls da IA | **NENHUM LUGAR** | Perdido imediatamente |
| Acao executada | **NENHUM LUGAR** | Perdido imediatamente |
| Dados extraidos de PDF/imagem | **NENHUM LUGAR** | Perdido imediatamente |
| Historico de conversa | Redis `chatmem-{phone}` | 5min (Premium) / 1h (Standard) |
| Gastos/receitas registrados | Via webhook externo | Permanente (API backend) |
| Eventos de agenda | Via webhook externo | Permanente (API backend) |
| Estagio de onboarding | `phones_whatsapp.stg` | Permanente (Supabase) |
| Perfil do usuario | `profiles` | Permanente (Supabase) |

---

## 8. TABELA message_log

A tabela `message_log` NAO e referenciada em NENHUM dos tres workflows analisados. Se ela existe no Supabase, nao esta sendo usada por estes workflows.
