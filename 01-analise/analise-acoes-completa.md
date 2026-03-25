# Analise Completa de Acoes de Escrita - Todos os Workflows

**Data da analise:** 2026-03-18
**Objetivo:** Mapear TODA acao de escrita (write) em cada workflow que NAO esta coberta pelo execution_log atual.

---

## Resumo de Cobertura Existente (log_total)

Os seguintes workflows JA possuem ALGUM logging via `log_total`:

| Workflow | Acao Logada | O que cobre |
|----------|-------------|-------------|
| Financeiro | `transacao_criada` | Criacao de gasto/entrada |
| Lembretes | `lembrete_automatico` | Envio de lembrete ao usuario |
| Lembretes | `criar_recorrente` | Criacao de evento recorrente (com Google) |
| Lembretes | `criar_recorrente_semgoogle` | Criacao de evento recorrente (sem Google) |
| Calendar | `criar_{compromisso_tipo}` | Criacao de evento (com e sem Google) |
| Report | `relatorio_enviado` | Geracao e envio de relatorio |

**IMPORTANTE:** Mesmo os workflows acima possuem acoes de escrita SEM cobertura. O logging existente cobre apenas a criacao principal, nao as acoes auxiliares (WhatsApp sends, updates, deletes, etc).

---

## 1. Financeiro - Total (eYWjnmvP8LQxY87g)

| Node Name | Type | Target | Data Written | user_phone available? | user_id available? | Currently Logged? |
|-----------|------|--------|--------------|----------------------|-------------------|-------------------|
| Update a row | n8n-nodes-base.supabase | Supabase: `spent` (UPDATE) | name_spent, value_spent, date_spent (filtrado por id_spent + fk_user) | Sim (via `$('Code').item.json.user.phone`) | Sim (via `$json.id` = fk_user) | NAO |
| Delete a row | n8n-nodes-base.supabase | Supabase: `spent` (DELETE) | Remove registro por id_spent + fk_user | Sim (via Code node) | Sim (via `$json.id`) | NAO |
| HTTP Request5 | n8n-nodes-base.httpRequest | Evolution API (WhatsApp): sendText | Envia resposta do AI Agent ao usuario (number = user.phone, text = output) | Sim (`$('Code').item.json.user.phone`) | Sim (via Code node) | NAO |
| HTTP Request6 | n8n-nodes-base.httpRequest | Evolution API (WhatsApp): sendText | Envia resposta do AI Agent ao usuario (number = user.phone, text = output) | Sim (`$('Code2').item.json.user.phone`) | Sim (via Code2 node) | NAO |
| Send message | n8n-nodes-base.whatsApp | WhatsApp Cloud API (oficial) | Envia mensagem "Buscando..." para o usuario (recipientPhoneNumber = phone) | Sim (`$json.phone`) | Nao diretamente | NAO |

**Total de acoes nao logadas: 5**

---

## 2. Lembretes Total Assistente (sjDpjKqtwLk7ycki)

| Node Name | Type | Target | Data Written | user_phone available? | user_id available? | Currently Logged? |
|-----------|------|--------|--------------|----------------------|-------------------|-------------------|
| Criar_principal_basic1 | n8n-nodes-base.supabase | Supabase: `calendar_principal` (CREATE) | nome_evento, sessao_evento, inicio_evento, fim_evento, lembrar_user | Nao diretamente | Sim (via SET user_id node) | NAO |
| criar_evento_google1 | n8n-nodes-base.httpRequest | Google Calendar API (CREATE event) | summary, description, start, end, timeZone | Nao diretamente | Sim (via SET user_id) | NAO |
| criar_evento_google_recorrente | n8n-nodes-base.httpRequest | Google Calendar API (CREATE recurring event) | summary, description, start, end, recurrence (RRULE) | Nao diretamente | Sim (via SET user_id) | NAO |
| create_calendar_sup_google | n8n-nodes-base.supabase | Supabase: `calendar` (CREATE) | event_name, desc_event, start_event, end_event, connect_google=TRUE, user_id, session_event_id_google, reminder=TRUE | Nao diretamente | Sim (user_id campo) | NAO (a criacao simples nao tem log neste workflow) |
| create_calendar_sup_google1 | n8n-nodes-base.supabase | Supabase: `calendar` (CREATE) | event_name, desc_event, start/end, connect_google=FALSE, user_id, reminder=TRUE | Nao diretamente | Sim (user_id campo) | NAO |
| create_calendar_sup_google (rec) | n8n-nodes-base.supabase | Supabase: `calendar` (CREATE) | event_name, desc, start/end, connect_google=TRUE, user_id, session_event_id_google, is_recurring=TRUE, rrule, next_fire_at | Nao diretamente | Sim (user_id campo) | SIM (log_total: criar_recorrente) |
| create_calendar_sup_local (rec) | n8n-nodes-base.supabase | Supabase: `calendar` (CREATE) | event_name, desc, start/end, connect_google=FALSE, user_id, is_recurring=TRUE, rrule, next_fire_at | Nao diretamente | Sim (user_id campo) | SIM (log_total: criar_recorrente_semgoogle) |
| Mark as Remembered | n8n-nodes-base.supabase | Supabase: `calendar` (UPDATE) | remembered = TRUE | Nao diretamente | Nao diretamente | NAO |
| Mark as Remembered1 | n8n-nodes-base.supabase | Supabase: `calendar` (UPDATE) | remembered = TRUE | Nao diretamente | Nao diretamente | NAO |
| Avancar Recorrente | n8n-nodes-base.supabase | Supabase: `calendar` (UPDATE) | next_fire_at, last_fired_at, active | Nao diretamente | Nao diretamente | NAO |
| HTTP Request - send agenda template1 | n8n-nodes-base.httpRequest | WhatsApp Cloud API (oficial): template lembrete_automatico | Envia template de lembrete ao usuario (to = phone do profiles) | Sim (`$('Get a row').item.json.phone`) | Sim (via Get a row) | SIM (log_total: lembrete_automatico) |
| HTTP Request - send agenda template | n8n-nodes-base.httpRequest | WhatsApp Cloud API (oficial): template lembrete_automatico | Envia template de lembrete ao usuario (to = phone do profiles) | Sim (`$('Get a row2').item.json.phone`) | Sim (via Get a row2) | SIM (log_total: lembrete_automatico) |
| descriptografar_token_prod | n8n-nodes-base.httpRequest | Supabase RPC: `decrypt_token_json` | Decripta refresh token do Google OAuth | Nao | Nao | NAO (acao auxiliar/infraestrutura) |
| descriptografar_token_prod1 | n8n-nodes-base.httpRequest | Supabase RPC: `decrypt_token_json` | Decripta refresh token do Google OAuth | Nao | Nao | NAO (acao auxiliar/infraestrutura) |
| refresh_access | n8n-nodes-base.httpRequest | Google OAuth2: token refresh | Obtem novo access_token | Nao | Nao | NAO (acao auxiliar/infraestrutura) |
| refresh_access1 | n8n-nodes-base.httpRequest | Google OAuth2: token refresh | Obtem novo access_token | Nao | Nao | NAO (acao auxiliar/infraestrutura) |

**Total de acoes nao logadas: 10 (excluindo 4 de infraestrutura e 4 ja logadas)**

---

## 3. Calendar WebHooks (ZZbMdcuCKx0fM712)

| Node Name | Type | Target | Data Written | user_phone available? | user_id available? | Currently Logged? |
|-----------|------|--------|--------------|----------------------|-------------------|-------------------|
| create_calendar_sup_google | n8n-nodes-base.supabase | Supabase: `calendar` (CREATE) | event_name, desc_event, start/end, connect_google=TRUE, user_id, session_event_id_google, compromisso_tipo | Nao diretamente | Sim (via SET user_id / webhook body) | SIM (log_total: criar_{tipo}) |
| create_calendar_sup_google1 | n8n-nodes-base.supabase | Supabase: `calendar` (CREATE) | event_name, desc_event, start/end, connect_google=FALSE, user_id, compromisso_tipo | Nao diretamente | Sim (via webhook body) | SIM (log_total: criar_{tipo}) |
| criar_evento_google | n8n-nodes-base.httpRequest | Google Calendar API (CREATE event) | summary, description, start, end, timeZone | Nao diretamente | Sim (via SET user_id) | NAO |
| criar_evento_google1 | n8n-nodes-base.httpRequest | Google Calendar API (CREATE event) | summary, description, start, end, timeZone | Nao diretamente | Sim (via SET user_id) | NAO |
| Update a row1 | n8n-nodes-base.supabase | Supabase: `calendar` (UPDATE) | event_name, desc_event, start_event, end_event | Nao diretamente | Sim (via webhook) | NAO |
| editar_evento_google3 | n8n-nodes-base.httpRequest | Google Calendar API (PATCH event) | summary, description, start, end (campos alterados) | Nao diretamente | Sim (via webhook) | NAO |
| excluir_evento_google | n8n-nodes-base.httpRequest | Google Calendar API (DELETE event) | Remove evento pelo event_id | Nao diretamente | Sim (via webhook) | NAO |
| delete_supabase | n8n-nodes-base.supabase | Supabase: `calendar` (DELETE) | Remove registro do calendar por filtro | Nao diretamente | Sim (via webhook) | NAO |
| delete_supabase1 | n8n-nodes-base.supabase | Supabase: `calendar` (DELETE) | Remove registro do calendar por filtro | Nao diretamente | Sim (via webhook) | NAO |
| descriptografar_token_prod | n8n-nodes-base.httpRequest | Supabase RPC: `decrypt_token_json` | Decripta refresh token | Nao | Nao | NAO (infraestrutura) |
| descriptografar_token_prod1 | n8n-nodes-base.httpRequest | Supabase RPC: `decrypt_token_json` | Decripta refresh token | Nao | Nao | NAO (infraestrutura) |
| descriptografar_token_prod2 | n8n-nodes-base.httpRequest | Supabase RPC: `decrypt_token_json` | Decripta refresh token | Nao | Nao | NAO (infraestrutura) |
| refresh_access | n8n-nodes-base.httpRequest | Google OAuth2: token refresh | Obtem novo access_token | Nao | Nao | NAO (infraestrutura) |
| refresh_access1 | n8n-nodes-base.httpRequest | Google OAuth2: token refresh | Obtem novo access_token | Nao | Nao | NAO (infraestrutura) |
| refresh_access2 | n8n-nodes-base.httpRequest | Google OAuth2: token refresh | Obtem novo access_token | Nao | Nao | NAO (infraestrutura) |

**Total de acoes nao logadas: 7 (excluindo 6 de infraestrutura e 2 ja logadas)**

---

## 4. Report Unificado (S2QgrsN6uteyB04E)

| Node Name | Type | Target | Data Written | user_phone available? | user_id available? | Currently Logged? |
|-----------|------|--------|--------------|----------------------|-------------------|-------------------|
| Update a row | n8n-nodes-base.supabase | Supabase: `recurrency_report` (UPDATE) | monthly = true | Nao diretamente | Sim (via webhook body user_id) | NAO |
| Update a row5 | n8n-nodes-base.supabase | Supabase: `recurrency_report` (UPDATE) | weekly = true | Nao diretamente | Sim (via webhook body) | NAO |
| Update a row6 | n8n-nodes-base.supabase | Supabase: `recurrency_report` (UPDATE) | weekly = false | Nao diretamente | Sim (via webhook body) | NAO |
| Update a row7 | n8n-nodes-base.supabase | Supabase: `recurrency_report` (UPDATE) | monthly = false | Nao diretamente | Sim (via webhook body) | NAO |
| Update a row8 | n8n-nodes-base.supabase | Supabase: `recurrency_report` (UPDATE) | monthly = false | Nao diretamente | Sim (via webhook body) | NAO |
| Update a row9 | n8n-nodes-base.supabase | Supabase: `recurrency_report` (UPDATE) | monthly = false | Nao diretamente | Sim (via webhook body) | NAO |
| HTTP Request1 | n8n-nodes-base.httpRequest | Gotenberg (PDF gen) | Gera PDF do relatorio HTML | Nao | Sim (via webhook) | NAO (infraestrutura) |
| HTTP Request2 | n8n-nodes-base.httpRequest | Gotenberg (PDF gen) | Gera PDF do relatorio HTML | Nao | Sim (via webhook) | NAO (infraestrutura) |
| gotenberg-pdf | n8n-nodes-base.httpRequest | Gotenberg (PDF gen) | Gera PDF do relatorio HTML | Nao | Sim (via webhook) | NAO (infraestrutura) |
| gotenberg-pdf1 | n8n-nodes-base.httpRequest | Gotenberg (PDF gen) | Gera PDF do relatorio HTML | Nao | Sim (via webhook) | NAO (infraestrutura) |
| Upload PDF WhatsApp | n8n-nodes-base.httpRequest | WhatsApp Cloud API: media upload | Upload do PDF gerado para WhatsApp | Nao | Sim (via webhook) | NAO |
| Upload PDF WhatsApp1 | n8n-nodes-base.httpRequest | WhatsApp Cloud API: media upload | Upload do PDF gerado para WhatsApp | Nao | Sim (via webhook) | NAO |
| upload-pdf-whatsapp | n8n-nodes-base.httpRequest | WhatsApp Cloud API: media upload | Upload do PDF gerado para WhatsApp | Nao | Sim (via webhook) | NAO |
| upload-pdf-whatsapp1 | n8n-nodes-base.httpRequest | WhatsApp Cloud API: media upload | Upload do PDF gerado para WhatsApp | Nao | Sim (via webhook) | NAO |
| Enviar Arquivo WhatsApp Oficial3 | n8n-nodes-base.httpRequest | WhatsApp Cloud API: send document | Envia PDF do relatorio ao usuario | Sim (via profiles lookup) | Sim (via webhook) | NAO |
| Enviar Arquivo WhatsApp Oficial4 | n8n-nodes-base.httpRequest | WhatsApp Cloud API: send document | Envia PDF do relatorio ao usuario | Sim (via profiles lookup) | Sim (via webhook) | NAO |
| enviar-whatsapp | n8n-nodes-base.httpRequest | WhatsApp Cloud API: send document | Envia PDF do relatorio ao usuario | Sim (via profiles lookup) | Sim (via webhook) | NAO |
| enviar-whatsapp1 | n8n-nodes-base.httpRequest | WhatsApp Cloud API: send document | Envia PDF do relatorio ao usuario | Sim (via profiles lookup) | Sim (via webhook) | NAO |
| HTTP Request4 | n8n-nodes-base.httpRequest | Evolution API (WhatsApp): sendMedia | Envia relatorio via Evolution API (mordomo) | Sim (via profiles) | Sim (via webhook) | NAO |
| HTTP Request | n8n-nodes-base.httpRequest | WhatsApp Cloud API: send message | Envia mensagem template ao usuario | Sim (via profiles) | Sim (via webhook) | NAO |

**Total de acoes nao logadas: 16 (excluindo 4 de infraestrutura/gotenberg). Log_total existente cobre apenas `relatorio_enviado`.**

---

## 5. Service Message - 24 Hours (GNdoIS2zxGBa4CW0)

| Node Name | Type | Target | Data Written | user_phone available? | user_id available? | Currently Logged? |
|-----------|------|--------|--------------|----------------------|-------------------|-------------------|
| HTTP Request - send flow with wa_id | n8n-nodes-base.httpRequest | WhatsApp Cloud API: send text | Envia mensagem de reengajamento ("Tudo bem com voce?") ao usuario inativo | Sim (`$json.phone`) | Sim (via message_log) | NAO |
| Update a row | n8n-nodes-base.supabase | Supabase: `message_log` (UPDATE) | notified = true (marca usuario como notificado) | Sim (disponivel no fluxo) | Sim (via message_log) | NAO |

**Total de acoes nao logadas: 2**

---

## 6. Fix Conflito v2 (tyJ3YAAtSg1UurFj)

### 6a. Acoes do AI Agent (Tool Calls)

| Node Name | Type | Target | Data Written | user_phone available? | user_id available? | Currently Logged? |
|-----------|------|--------|--------------|----------------------|-------------------|-------------------|
| excluir_financeiro | httpRequestTool | Webhook: excluir-supabase | Exclui registro financeiro (id_gasto + id_user) | Sim (`$('setar_user').item.json.telefone`) | Sim (`$('setar_user').item.json.id_user`) | NAO |
| excluir_evento | httpRequestTool | Webhook: excluir-evento-total | Exclui evento (event_id + user_id) | Sim (via setar_user) | Sim (via setar_user) | NAO |
| editar_evento | httpRequestTool | Webhook: editar_eventos_total | Edita evento (sessao_id + campos novos) | Sim (via setar_user) | Sim (via setar_user) | NAO |
| editar_eventos | httpRequestTool | Webhook: editar-eventos | Busca e edita eventos (nome, desc, datas) | Sim (via setar_user) | Sim (via setar_user) | NAO |
| editar_eventos1 | httpRequestTool | Webhook: editar-eventos | Busca e edita eventos (mesmo endpoint) | Sim (via setar_user) | Sim (via setar_user) | NAO |
| criar_lembrete | httpRequestTool | Webhook: criar-lembrete-total | Cria lembrete (nome, inicio, fim) | Sim (via setar_user) | Sim (via setar_user) | NAO |
| registrar_financeiros | httpRequestTool | Webhook: registrar-gasto | Registra gasto/entrada (nome, valor, categoria, data, tipo) | Sim (via setar_user) | Sim (via setar_user) | NAO |
| gerar_relatorio | httpRequestTool | Webhook: report | Gera relatorio financeiro (user_id, startDate, endDate, tipo) | Sim (via setar_user) | Sim (via setar_user) | NAO |

### 6b. Acoes de Criacao de Evento/Lembrete (HTTP direto)

| Node Name | Type | Target | Data Written | user_phone available? | user_id available? | Currently Logged? |
|-----------|------|--------|--------------|----------------------|-------------------|-------------------|
| HTTP - Create Calendar Tool | httpRequest | Webhook: criar-evento (5e0f5e77) | Cria evento (nome, desc, data_inicio, data_fim, id_user) | Sim (via premium body user_phone) | Sim (via setar_user) | NAO |
| HTTP - Create Calendar Tool2 | httpRequest | Webhook: criar-evento (5e0f5e77) | Cria evento (dados do Switch2) | Sim (via premium body) | Sim (via setar_user) | NAO |
| HTTP - Create Calendar Tool4 | httpRequest | Webhook: criar-evento (5e0f5e77) | Cria evento (dados do tool output) | Sim (via premium body) | Sim (via setar_user) | NAO |
| HTTP - Create Calendar Tool6 | httpRequest | Webhook: criar-evento (5e0f5e77) | Cria evento (dados do Switch2) | Sim (via premium body) | Sim (via setar_user) | NAO |
| HTTP - Create Calendar Tool3 | httpRequest | Webhook: criar-lembrete-recorrente-total | Cria lembrete recorrente (nome, rrule, dtstart, timezone, until) | Sim (via premium body) | Sim (via setar_user) | NAO |
| HTTP - Create Calendar Tool5 | httpRequest | Webhook: criar-lembrete-recorrente-total | Cria lembrete recorrente (nome, rrule, dtstart, timezone, until) | Sim (via premium body) | Sim (via setar_user) | NAO |

### 6c. Acoes de Botao (Exclusao via interacao do usuario)

| Node Name | Type | Target | Data Written | user_phone available? | user_id available? | Currently Logged? |
|-----------|------|--------|--------------|----------------------|-------------------|-------------------|
| Excluir Evento (Botao) | httpRequest | Webhook: excluir-evento-total | Exclui evento (event_id do botao + user_id) | Sim (via premium body user_phone) | Sim (via setar_user) | NAO |
| Excluir Financeiro (Botao) | httpRequest | Webhook: excluir-supabase | Exclui registro financeiro (id_gasto do botao + id_user) | Sim (via premium body user_phone) | Sim (via setar_user) | NAO |
| Excluir Recorrente (Botao) | httpRequest | Webhook: excluir-evento-total | Exclui evento recorrente (event_id do botao + user_id) | Sim (via premium body user_phone) | Sim (via setar_user) | NAO |

### 6d. Envios WhatsApp (mensagens ao usuario)

| Node Name | Type | Target | Data Written | user_phone available? | user_id available? | Currently Logged? |
|-----------|------|--------|--------------|----------------------|-------------------|-------------------|
| HTTP Request4 | httpRequest | Evolution API: sendText/mordomo | Resposta do AI Agent ao usuario | Sim (`$('setar_user').item.json.telefone`) | Sim (via setar_user) | NAO |
| HTTP Request6 | httpRequest | Evolution API: sendText/mordomo | Mensagem de formato nao suportado | Sim (via setar_user) | Sim (via setar_user) | NAO |
| HTTP Request - Basic Create Template | httpRequest | WhatsApp Cloud API: interactive button | Confirmacao de criacao de gasto com botoes (desfazer) | Sim (`$('premium').item.json.body.user_phone`) | Sim (via setar_user) | NAO |
| HTTP Request - Basic Template | httpRequest | WhatsApp Cloud API: template novo_evento_user | Template de novo evento criado | Sim (via premium body) | Sim (via setar_user) | NAO |
| HTTP Request - send text | httpRequest | WhatsApp Cloud API: text | Mensagem de texto livre ao usuario | Sim (via premium body) | Sim (via setar_user) | NAO |
| HTTP Request | httpRequest | WhatsApp Cloud API: interactive button | Confirmacao de evento agendado com botoes | Sim (via premium body) | Sim (via setar_user) | NAO |
| HTTP Request1 | httpRequest | WhatsApp Cloud API: interactive button | Mensagem com botoes de acao | Sim (via premium body) | Sim (via setar_user) | NAO |
| Confirmar Exclusao Evento | httpRequest | WhatsApp Cloud API: text | Mensagem "Evento excluido com sucesso!" | Sim (via premium body) | Sim (via setar_user) | NAO |
| Confirmar Exclusao Financeiro | httpRequest | WhatsApp Cloud API: text | Mensagem "Registro financeiro desfeito!" | Sim (via premium body) | Sim (via setar_user) | NAO |
| Confirmar Exclusao Recorrente | httpRequest | WhatsApp Cloud API: text | Mensagem "Evento recorrente excluido!" | Sim (via premium body) | Sim (via setar_user) | NAO |

### 6e. Nudge Flow (Google Calendar connection)

| Node Name | Type | Target | Data Written | user_phone available? | user_id available? | Currently Logged? |
|-----------|------|--------|--------------|----------------------|-------------------|-------------------|
| Enviar Nudge Google | httpRequest | WhatsApp Cloud API: interactive button | Mensagem perguntando se quer conectar Google Calendar | Sim (via Evolution API Take all phone) | Sim (via setar_user) | NAO |
| Registrar Nudge Enviado | httpRequest | Supabase REST: `gc_nudge` (INSERT) | user_id, last_sent_at | Nao diretamente | Sim (via setar_user) | NAO |
| Registrar Sim | httpRequest | Supabase REST: `gc_nudge` (INSERT) | user_id, last_response='sim', last_response_at | Nao diretamente | Sim (via setar_user) | NAO |
| Registrar Nao | httpRequest | Supabase REST: `gc_nudge` (PATCH) | last_response='nao', last_response_at | Nao diretamente | Sim (via setar_user) | NAO |
| Enviar Tutorial Google | httpRequest | WhatsApp Cloud API: text | Tutorial de como conectar Google Calendar | Sim (via premium body) | Sim (via setar_user) | NAO |
| Responder Nao Google | httpRequest | WhatsApp Cloud API: text | Mensagem "Sem problemas!" | Sim (via premium body) | Sim (via setar_user) | NAO |

### 6f. OCR / PDF (processamento externo, nao e acao de usuario)

| Node Name | Type | Target | Data Written | user_phone available? | user_id available? | Currently Logged? |
|-----------|------|--------|--------------|----------------------|-------------------|-------------------|
| PDF Extractor | httpRequest | Mistral AI OCR API | Extrai texto de PDF via OCR | Nao | Sim (via setar_user) | NAO (infraestrutura) |
| HTTP Request8 | httpRequest | Mistral AI OCR API | Extrai texto de imagem via OCR | Nao | Sim (via setar_user) | NAO (infraestrutura) |

**Total de acoes nao logadas no Fix Conflito v2: 38 (excluindo 2 de OCR/infraestrutura)**

---

## Resumo Geral

| Workflow | Acoes de Escrita Total | Ja Logadas | NAO Logadas | Infraestrutura (excluida) |
|----------|----------------------|------------|-------------|--------------------------|
| Financeiro - Total | 5 | 0 | **5** | 0 |
| Lembretes Total Assistente | 16 | 4 | **8** | 4 (token/oauth) |
| Calendar WebHooks | 15 | 2 | **7** | 6 (token/oauth) |
| Report Unificado | 20 | 2 | **14** | 4 (gotenberg) |
| Service Message - 24 Hours | 2 | 0 | **2** | 0 |
| Fix Conflito v2 | 40 | 0 | **38** | 2 (OCR) |
| **TOTAL** | **98** | **8** | **74** | **16** |

---

## Classificacao por Tipo de Acao NAO Logada

### 1. Supabase WRITE (create/update/delete) - 23 acoes

| Acao | Workflow | Tabela | Operacao |
|------|----------|--------|----------|
| Update a row | Financeiro | spent | UPDATE |
| Delete a row | Financeiro | spent | DELETE |
| Criar_principal_basic1 | Lembretes | calendar_principal | CREATE |
| create_calendar_sup_google | Lembretes | calendar | CREATE |
| create_calendar_sup_google1 | Lembretes | calendar | CREATE |
| Mark as Remembered | Lembretes | calendar | UPDATE |
| Mark as Remembered1 | Lembretes | calendar | UPDATE |
| Avancar Recorrente | Lembretes | calendar | UPDATE |
| Update a row1 | Calendar | calendar | UPDATE |
| delete_supabase | Calendar | calendar | DELETE |
| delete_supabase1 | Calendar | calendar | DELETE |
| Update a row | Report | recurrency_report | UPDATE |
| Update a row5 | Report | recurrency_report | UPDATE |
| Update a row6 | Report | recurrency_report | UPDATE |
| Update a row7 | Report | recurrency_report | UPDATE |
| Update a row8 | Report | recurrency_report | UPDATE |
| Update a row9 | Report | recurrency_report | UPDATE |
| Update a row | Service Msg | message_log | UPDATE |
| Registrar Nudge Enviado | Fix Conflito | gc_nudge | INSERT |
| Registrar Sim | Fix Conflito | gc_nudge | INSERT |
| Registrar Nao | Fix Conflito | gc_nudge | PATCH |

### 2. Google Calendar API - 7 acoes

| Acao | Workflow | Operacao |
|------|----------|----------|
| criar_evento_google1 | Lembretes | CREATE event |
| criar_evento_google_recorrente | Lembretes | CREATE recurring event |
| criar_evento_google | Calendar | CREATE event |
| criar_evento_google1 | Calendar | CREATE event |
| editar_evento_google3 | Calendar | PATCH event |
| excluir_evento_google | Calendar | DELETE event |

### 3. WhatsApp Sends (Cloud API + Evolution) - 27 acoes

| Acao | Workflow | Tipo Mensagem |
|------|----------|---------------|
| HTTP Request5 | Financeiro | Text (AI response via Evolution) |
| HTTP Request6 | Financeiro | Text (AI response via Evolution) |
| Send message | Financeiro | Text ("Buscando..." via Cloud API) |
| Upload PDF WhatsApp (x4) | Report | Media upload |
| Enviar Arquivo WhatsApp Oficial3/4 | Report | Document send |
| enviar-whatsapp / enviar-whatsapp1 | Report | Document send |
| HTTP Request4 | Report | Media (Evolution) |
| HTTP Request | Report | Template message |
| HTTP Request - send flow with wa_id | Service Msg | Text (reengajamento) |
| HTTP Request4 | Fix Conflito | Text (AI response via Evolution) |
| HTTP Request6 | Fix Conflito | Text (formato nao suportado) |
| HTTP Request - Basic Create Template | Fix Conflito | Interactive button (confirmacao gasto) |
| HTTP Request - Basic Template | Fix Conflito | Template (novo evento) |
| HTTP Request - send text | Fix Conflito | Text (resposta livre) |
| HTTP Request | Fix Conflito | Interactive button (confirmacao evento) |
| HTTP Request1 | Fix Conflito | Interactive button |
| Confirmar Exclusao Evento | Fix Conflito | Text (confirmacao) |
| Confirmar Exclusao Financeiro | Fix Conflito | Text (confirmacao) |
| Confirmar Exclusao Recorrente | Fix Conflito | Text (confirmacao) |
| Enviar Nudge Google | Fix Conflito | Interactive button (nudge) |
| Enviar Tutorial Google | Fix Conflito | Text (tutorial) |
| Responder Nao Google | Fix Conflito | Text (resposta nao) |

### 4. Webhook Calls (disparam outros workflows) - 17 acoes

| Acao | Workflow | Webhook Destino |
|------|----------|----------------|
| excluir_financeiro (tool) | Fix Conflito | excluir-supabase |
| excluir_evento (tool) | Fix Conflito | excluir-evento-total |
| editar_evento (tool) | Fix Conflito | editar_eventos_total |
| editar_eventos (tool) | Fix Conflito | editar-eventos |
| editar_eventos1 (tool) | Fix Conflito | editar-eventos |
| criar_lembrete (tool) | Fix Conflito | criar-lembrete-total |
| registrar_financeiros (tool) | Fix Conflito | registrar-gasto |
| gerar_relatorio (tool) | Fix Conflito | report |
| HTTP - Create Calendar Tool | Fix Conflito | criar-evento (5e0f5e77) |
| HTTP - Create Calendar Tool2 | Fix Conflito | criar-evento (5e0f5e77) |
| HTTP - Create Calendar Tool4 | Fix Conflito | criar-evento (5e0f5e77) |
| HTTP - Create Calendar Tool6 | Fix Conflito | criar-evento (5e0f5e77) |
| HTTP - Create Calendar Tool3 | Fix Conflito | criar-lembrete-recorrente-total |
| HTTP - Create Calendar Tool5 | Fix Conflito | criar-lembrete-recorrente-total |
| Excluir Evento (Botao) | Fix Conflito | excluir-evento-total |
| Excluir Financeiro (Botao) | Fix Conflito | excluir-supabase |
| Excluir Recorrente (Botao) | Fix Conflito | excluir-evento-total |

---

## Prioridade de Implementacao do execution_log

### P0 - Critica (acoes que modificam dados do usuario)
1. **Supabase spent DELETE/UPDATE** (Financeiro) - Perda/alteracao de dados financeiros
2. **Supabase calendar DELETE** (Calendar) - Perda de eventos
3. **Supabase calendar UPDATE** (Calendar) - Alteracao de eventos
4. **Excluir Evento/Financeiro/Recorrente (Botao)** (Fix Conflito) - Exclusoes via botao de interacao
5. **excluir_financeiro / excluir_evento (tools)** (Fix Conflito) - Exclusoes via AI Agent

### P1 - Alta (acoes que criam dados)
6. **Supabase calendar CREATE** (Lembretes) - Criacao de eventos simples (nao-recorrentes)
7. **Supabase calendar_principal CREATE** (Lembretes) - Criacao na tabela principal
8. **Google Calendar CREATE/PATCH/DELETE** (Calendar, Lembretes) - Sync com Google
9. **HTTP - Create Calendar Tool (x4)** (Fix Conflito) - Criacao de eventos via webhook
10. **criar_lembrete / editar_evento / editar_eventos (tools)** (Fix Conflito) - Acoes do AI Agent

### P2 - Media (acoes de comunicacao)
11. **WhatsApp sends** (todos os workflows) - Mensagens enviadas ao usuario
12. **Report PDF sends** (Report) - Envio de relatorios

### P3 - Baixa (acoes auxiliares/estado)
13. **recurrency_report updates** (Report) - Flags de controle
14. **Mark as Remembered** (Lembretes) - Estado de lembrete
15. **message_log update** (Service Msg) - Flag de notificacao
16. **gc_nudge inserts/patches** (Fix Conflito) - Tracking de nudge
