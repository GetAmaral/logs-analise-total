-- ================================================
-- RPC: fn_exec_log_kpis — KPIs para o Activity Log
-- EXECUTAR NO SUPABASE PRINCIPAL (ldbdtakddxznfridsarn)
-- ================================================

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
