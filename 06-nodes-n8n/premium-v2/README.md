# Nodes v2 — Com detecção de sucesso/falha

## Mudanças em relação ao v1

1. Os nodes de log agora ficam **EM SÉRIE** (não paralelo)
2. Detectam `action_success` baseado no output do HTTP anterior
3. Capturam `error_message` quando a ação falha
4. Capturam `action_output` (resposta sanitizada do webhook)

## ANTES de colar esses nodes:

### Passo obrigatório: Habilitar "Continue On Fail" nos nodes de ação

Para cada node HTTP de ação, faça:
1. Clique no node
2. Clique em **Settings** (ícone de engrenagem)
3. Ative **"Continue On Fail"**
4. Salve

Nodes que precisam disso:
- Excluir Evento (Botão)
- Excluir Financeiro (Botão)
- Excluir Recorrente (Botão)
- HTTP - Create Tool (e Tool1, Tool2)
- HTTP - Create Calendar Tool (e Tool2, Tool3, Tool4, Tool5, Tool6)

### Como reconectar (em série):

ANTES:
```
Ação HTTP ──→ Confirmação WhatsApp
         └──→ Log (paralelo)   ← REMOVER esta conexão
```

DEPOIS:
```
Ação HTTP ──→ Log ──→ Confirmação WhatsApp
```

O log fica NO MEIO. Ele passa os dados adiante para o próximo node funcionar normalmente.
