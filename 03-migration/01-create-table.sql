-- ================================================
-- EXECUTION_LOG v2 — Tabela centralizada de auditoria
-- Total Assistente — Supabase
-- ================================================
-- SEGURO: Nenhum campo armazena tokens, keys ou secrets.
-- Todos os dados sao sanitizados antes do INSERT via N8N.
-- ================================================

CREATE TABLE IF NOT EXISTS execution_log (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,

  -- Agrupamento de eventos
  interaction_id UUID DEFAULT gen_random_uuid(),
    -- Agrupa TODOS os eventos de uma unica interacao
    -- (message_received → classification → ai_response → action_executed)
  session_id TEXT,
    -- Agrupa interacoes da mesma sessao (gap > 30min = nova sessao)

  -- Identificacao do usuario (dados seguros)
  user_phone TEXT,
  user_id TEXT,
  user_plan TEXT,
    -- valores: free | standard | premium

  -- Mensagem original
  user_message TEXT,
  message_type TEXT DEFAULT 'text',
    -- valores: text | audio | image | document | button
  whatsapp_timestamp TIMESTAMPTZ,
    -- Timestamp original do WhatsApp (diferente do created_at do Supabase)

  -- Audio (se aplicavel)
  transcription_text TEXT,
    -- Texto transcrito pelo Whisper (se message_type = audio)
  summary_text TEXT,
    -- Resumo gerado pelo LLM (se usuario solicitou)

  -- Classificacao de intent
  branch TEXT,
    -- valores: criar_gasto | buscar_gasto | editar_gasto | excluir_gasto
    --          criar_evento | buscar_evento | editar_evento | excluir_evento
    --          criar_lembrete | gerar_relatorio | padrao

  -- Resposta da IA (SANITIZADA)
  ai_message TEXT,
    -- Texto da resposta enviada ao usuario
  ai_action TEXT,
    -- Nome da acao executada (registrar_gasto, criar_evento, etc.)
  ai_tools_called JSONB,
    -- Array de tools chamadas pelo AI Agent
    -- Ex: [{"name": "registrar_financeiros", "params": {"nome": "Almoco", "valor": 45}}]
  ai_full_response JSONB,
    -- JSON parseado do AI Agent (acao + mensagem + tool)
    -- NUNCA contem tokens ou keys

  -- Acao executada (SANITIZADA — campos explicitos)
  action_type TEXT,
    -- Tipo padronizado: registrar_gasto | criar_evento | excluir_financeiro | etc.
  action_input JSONB,
    -- Dados SEGUROS enviados ao webhook (nome, valor, categoria — sem user_id, sem tokens)
  action_output JSONB,
    -- Resposta do webhook (status, dados criados — sem tokens)
  action_success BOOLEAN,
    -- true = acao executada com sucesso, false = falhou

  -- Dados extraidos (PDF/imagem)
  extracted_data JSONB,
    -- Texto extraido via OCR (Mistral AI) — apenas conteudo textual

  -- Metadados do evento
  source_workflow TEXT NOT NULL,
    -- valores: main | premium | standard | financeiro | calendar | lembretes | report | service_msg
  event_type TEXT NOT NULL,
    -- valores: message_received | transcription | audio_summary | message_routed
    --          classification | ai_response | action_executed | interaction_complete | error
  status TEXT DEFAULT 'completed',
    -- valores: pending | processing | completed | error
    -- Para a UI mostrar badges de status
  routed_to TEXT,
    -- valores: premium | standard (quando event_type = message_routed)
  duration_ms INTEGER,
    -- Tempo de processamento em ms (UI mostra "respondeu em 2.3s")

  -- Erro (se houver)
  error_message TEXT,
    -- Mensagem de erro generica — NUNCA contem stack traces com credentials

  -- Timestamp
  created_at TIMESTAMPTZ DEFAULT NOW()
);
