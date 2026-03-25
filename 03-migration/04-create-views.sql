-- ================================================
-- VIEWS — execution_log (queries pre-prontas para a UI)
-- ================================================

-- View: resumo diario (KPI cards no dashboard)
CREATE OR REPLACE VIEW v_exec_log_daily_summary AS
SELECT
  date_trunc('day', created_at) AS dia,
  source_workflow,
  event_type,
  count(*) AS total,
  count(*) FILTER (WHERE action_success = true) AS sucesso,
  count(*) FILTER (WHERE action_success = false) AS falha,
  count(*) FILTER (WHERE error_message IS NOT NULL) AS erros,
  avg(duration_ms) AS avg_duration_ms
FROM execution_log
GROUP BY 1, 2, 3;

-- View: distribuicao de intents (donut chart)
CREATE OR REPLACE VIEW v_exec_log_branch_stats AS
SELECT
  branch,
  source_workflow,
  count(*) AS total,
  count(*) FILTER (WHERE action_success = true) AS sucesso,
  count(*) FILTER (WHERE action_success = false) AS falha
FROM execution_log
WHERE branch IS NOT NULL
GROUP BY 1, 2;

-- View: volume por hora (area chart)
CREATE OR REPLACE VIEW v_exec_log_hourly_volume AS
SELECT
  date_trunc('hour', created_at) AS hora,
  source_workflow,
  count(*) AS total
FROM execution_log
GROUP BY 1, 2
ORDER BY 1;

-- View: erros recentes (lista de erros no dashboard)
CREATE OR REPLACE VIEW v_exec_log_recent_errors AS
SELECT
  id,
  user_phone,
  source_workflow,
  event_type,
  action_type,
  error_message,
  created_at
FROM execution_log
WHERE error_message IS NOT NULL
ORDER BY created_at DESC
LIMIT 50;

-- View: split por plano (premium vs standard)
CREATE OR REPLACE VIEW v_exec_log_plan_split AS
SELECT
  user_plan,
  date_trunc('day', created_at) AS dia,
  count(*) AS total_interacoes,
  count(DISTINCT user_phone) AS usuarios_unicos
FROM execution_log
WHERE event_type = 'interaction_complete'
  AND user_plan IS NOT NULL
GROUP BY 1, 2
ORDER BY 2 DESC;
