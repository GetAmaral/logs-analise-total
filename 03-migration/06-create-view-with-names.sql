-- ================================================
-- VIEW: v_exec_log_with_user — execution_log + nome do usuário
-- EXECUTAR NO SUPABASE PRINCIPAL (ldbdtakddxznfridsarn)
-- ================================================
-- JOIN por user_phone → profiles.phone (mais confiável, sempre presente)
-- Fallback por user_id → profiles.id (quando phone não tem match)

CREATE OR REPLACE VIEW v_exec_log_with_user AS
SELECT
    el.*,
    COALESCE(p1.name, p2.name, 'Desconhecido') AS user_name,
    COALESCE(p1.email, p2.email) AS user_email,
    COALESCE(el.user_plan, p1.plan_type, p2.plan_type) AS resolved_plan
FROM execution_log el
LEFT JOIN profiles p1 ON el.user_phone = p1.phone
LEFT JOIN profiles p2 ON el.user_id = p2.id::text AND p1.id IS NULL;

COMMENT ON VIEW v_exec_log_with_user IS 'execution_log com nome e email do usuário resolvidos via JOIN com profiles';
