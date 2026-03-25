-- ================================================
-- INDICES — execution_log
-- ================================================

-- Indices simples (filtros individuais)
CREATE INDEX idx_exec_log_phone ON execution_log(user_phone);
CREATE INDEX idx_exec_log_user_id ON execution_log(user_id);
CREATE INDEX idx_exec_log_event_type ON execution_log(event_type);
CREATE INDEX idx_exec_log_source ON execution_log(source_workflow);
CREATE INDEX idx_exec_log_created ON execution_log(created_at DESC);
CREATE INDEX idx_exec_log_branch ON execution_log(branch);
CREATE INDEX idx_exec_log_action_type ON execution_log(action_type);
CREATE INDEX idx_exec_log_status ON execution_log(status);
CREATE INDEX idx_exec_log_interaction ON execution_log(interaction_id);
CREATE INDEX idx_exec_log_session ON execution_log(session_id);
CREATE INDEX idx_exec_log_plan ON execution_log(user_plan);

-- Indices compostos (queries da UI — mais usados)
CREATE INDEX idx_exec_log_phone_created ON execution_log(user_phone, created_at DESC);
CREATE INDEX idx_exec_log_phone_event ON execution_log(user_phone, event_type);
CREATE INDEX idx_exec_log_source_created ON execution_log(source_workflow, created_at DESC);
