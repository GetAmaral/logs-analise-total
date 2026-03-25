# Regras de Sanitizacao — execution_log

## Principio: CAMPOS EXPLICITOS, NUNCA PAYLOAD CRU

Cada node de log no N8N usa campos selecionados manualmente. Nunca `JSON.stringify($json)`.

---

## Dados sensiveis identificados nos workflows

| Dado | Onde aparece | Severidade |
|------|-------------|-----------|
| Google `access_token` / `refresh_token` | Calendar, Lembretes | CRITICO |
| `google_calendar_secret_key_2024` | Calendar WebHooks | CRITICO |
| `SUPABASE_SERVICE_ROLE_KEY` | Edge functions, headers | CRITICO |
| `GOOGLE_CLIENT_SECRET` | Edge functions OAuth | CRITICO |
| `HOTMART_HOTTOK` | Webhook de pagamento | CRITICO |
| WhatsApp `phoneNumberId` (744582292082931) | Todos os workflows | MEDIO |
| Evolution API host + instance `mordomo` | Premium, Standard, Report | MEDIO |
| `sessionToken` (64-char hex) | OTP verification | CRITICO |
| Bearer tokens nos headers HTTP | Calendar, Lembretes | CRITICO |

---

## O que LOGAR vs O que NUNCA LOGAR

### LOGAR (payload util)

```
- nome_gasto, valor_gasto, categoria_gasto, tipo_gasto, data_gasto
- nome_evento, descricao_evento, data_inicio, data_fim
- branch (classificacao de intent)
- acao executada (nome da acao)
- mensagem do usuario (texto)
- resposta da IA (texto)
- status da acao (success/fail)
- tipo de mensagem (text/audio/image/document)
- erro (mensagem generica)
- nome do tool chamado
- parametros do tool (nome, valor, categoria — sem IDs internos)
```

### NUNCA LOGAR

```
- access_token, refresh_token (Google OAuth)
- Bearer headers
- SUPABASE_SERVICE_ROLE_KEY
- GOOGLE_CLIENT_SECRET
- HOTMART_HOTTOK
- google_calendar_secret_key_2024
- Evolution API keys/URLs completas
- session tokens (OTP)
- URLs com tokens inline
- IPs internos do servidor (188.245.190.178)
- Payload cru do webhook WhatsApp (contem metadata sensivel)
- Binary data (PDF, imagens)
- media_id do WhatsApp (pode ser usado para download)
- Redis keys/values crus
```

---

## Sanitizacao por workflow

### Financeiro

| Campo seguro para logar | Campo a EXCLUIR |
|------------------------|-----------------|
| nome_gasto | fk_user (redundante, ja temos user_id) |
| valor_gasto | headers HTTP |
| categoria_gasto | |
| tipo_gasto (entrada/saida) | |
| data_gasto | |

### Calendar WebHooks

| Campo seguro para logar | Campo a EXCLUIR |
|------------------------|-----------------|
| event_name | session_event_id_google |
| start_event, end_event | tokens OAuth (access_token, refresh_token) |
| compromisso_tipo | google_calendar_secret_key |
| connect_google (true/false) | descriptografar_token payloads |
| operacao (create/update/delete) | refresh_access responses |

### Lembretes

| Campo seguro para logar | Campo a EXCLUIR |
|------------------------|-----------------|
| event_name | descriptografar_token payloads |
| start, end | refresh_access responses |
| rrule (recorrencia) | tokens OAuth |
| reminder (true/false) | |
| is_recurring | |

### Premium (Fix Conflito v2)

| Campo seguro para logar | Campo a EXCLUIR |
|------------------------|-----------------|
| parsed_output.acao | Redis chatmem raw |
| parsed_output.mensagem | $json.output cru (pode ter markdown lixo) |
| parsed_output.tool (nome + params seguros) | tokens em headers |
| branch (classificacao) | |
| setar_user.telefone, setar_user.id_user | |

### Standard

Identico ao Premium.

### Report

| Campo seguro para logar | Campo a EXCLUIR |
|------------------------|-----------------|
| tipo_relatorio (semanal/mensal) | PDF binary |
| periodo (startDate, endDate) | media_id WhatsApp |
| recurrency flags | template raw HTML |

### Service Message

| Campo seguro para logar | Campo a EXCLUIR |
|------------------------|-----------------|
| tipo (reengajamento) | template message raw |
| notified (true/false) | |

---

## Exemplo pratico no N8N

### ERRADO (vaza tudo):

```javascript
// Node: Supabase Create a Row
action_input = {{ JSON.stringify($json) }}
// PERIGO: $json pode conter tokens, keys, headers
```

### CORRETO (campos explicitos):

```javascript
// Node: Code (antes do Supabase)
const safe_input = {
  nome: $('setar_user').item.json.nome_gasto || null,
  valor: $('setar_user').item.json.valor_gasto || null,
  categoria: $('setar_user').item.json.categoria_gasto || null,
  tipo: $('setar_user').item.json.tipo_gasto || null
};
return { json: { action_input: JSON.stringify(safe_input) } };
```

---

## Auditoria pos-deploy

Executar apos cada fase para verificar vazamentos:

```sql
SELECT id, action_input::text, action_output::text, ai_full_response::text
FROM execution_log
WHERE
  action_input::text ILIKE '%token%'
  OR action_input::text ILIKE '%bearer%'
  OR action_input::text ILIKE '%secret%'
  OR action_input::text ILIKE '%key%'
  OR action_output::text ILIKE '%token%'
  OR action_output::text ILIKE '%refresh%'
  OR ai_full_response::text ILIKE '%password%';

-- Se retornar QUALQUER row = PARAR TUDO e corrigir imediatamente
```
