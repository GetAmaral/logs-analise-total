-- ================================================
-- RLS — execution_log
-- ================================================

-- Habilitar Row Level Security
ALTER TABLE execution_log ENABLE ROW LEVEL SECURITY;

-- ESTRATEGIA: Nenhuma policy criada = deny all para anon/authenticated.
-- Somente service_role (que bypassa RLS) pode ler/escrever.
-- Isso garante que:
--   - Frontend NAO acessa diretamente (precisa de edge function ou server-side)
--   - N8N acessa via service_role key (INSERT)
--   - Dashboard acessa via edge function com service_role (SELECT)

-- Comentarios
COMMENT ON TABLE execution_log IS 'Log centralizado de execucao dos workflows N8N — dados sanitizados, sem tokens/keys. Acesso somente via service_role.';
