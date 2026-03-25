# FIX DEFINITIVO — Agrupamento, Latência e OCR

## Causa raiz de TODOS os problemas

O campo `interaction_id` gera um **UUID novo em cada row**. Isso significa que `message_received`, `transcription`, `classification`, `ai_response` e `action_executed` — que pertencem à MESMA interação — têm IDs diferentes.

**O site não consegue agrupar os eventos da mesma mensagem.**

## Solução: agrupar por TEMPO + USER_PHONE

Não usar `interaction_id`. Usar a lógica:
1. Buscar TODOS os eventos de um user, ordenados por `created_at ASC`
2. Cada `message_received` inicia uma nova interação
3. Todos os eventos seguintes pertencem a essa interação ATÉ o próximo `message_received`

**ESSA É A ÚNICA FORMA CORRETA DE AGRUPAR.**

## Função correta (substituir a atual):

```javascript
function groupIntoInteractions(logs) {
    // logs DEVE estar ordenado por created_at ASC
    const interactions = [];
    let current = null;

    for (const log of logs) {
        if (log.event_type === 'message_received' && log.user_phone) {
            // Salvar interação anterior
            if (current) {
                // Calcular latência: primeiro evento → último evento
                const t1 = new Date(current.timestamp).getTime();
                const t2 = new Date(current.events[current.events.length - 1].created_at).getTime();
                current.duration_ms = t2 - t1;
                interactions.push(current);
            }
            // Nova interação
            current = {
                id: log.id,
                timestamp: log.created_at,
                user_phone: log.user_phone,
                user_name: log.user_name,
                user_message: log.user_message,
                message_type: log.message_type || 'text',
                source_workflow: log.source_workflow,
                events: [log],
                // Campos preenchidos pelos próximos eventos:
                routed_to: null,
                transcription: null,
                extracted_data: null,
                branch: null,
                ai_message: null,
                ai_action: null,
                ai_tools: null,
                ai_full_response: null,
                action_type: null,
                action_input: null,
                action_success: null,
                error_message: null,
                duration_ms: 0
            };
        } else if (current) {
            // Adicionar evento à interação atual
            current.events.push(log);

            switch (log.event_type) {
                case 'message_routed':
                    current.routed_to = log.routed_to;
                    break;

                case 'transcription':
                    if (log.message_type === 'audio') {
                        current.transcription = log.transcription_text;
                        current.message_type = 'audio';
                    }
                    if (log.message_type === 'image') {
                        // PARSE extracted_data (pode ser string JSON ou objeto)
                        let ed = log.extracted_data;
                        if (typeof ed === 'string') {
                            try { ed = JSON.parse(ed); } catch(e) {}
                        }
                        current.extracted_data = ed;
                        current.message_type = 'image';
                    }
                    if (log.message_type === 'document') {
                        let ed = log.extracted_data;
                        if (typeof ed === 'string') {
                            try { ed = JSON.parse(ed); } catch(e) {}
                        }
                        current.extracted_data = ed;
                        current.message_type = 'document';
                    }
                    break;

                case 'classification':
                    current.branch = log.branch;
                    // Se a classification tem message_type mais específico, usar
                    if (log.message_type && log.message_type !== 'text') {
                        current.message_type = log.message_type;
                    }
                    break;

                case 'ai_response':
                    current.ai_message = log.ai_message;
                    current.ai_action = log.ai_action;
                    current.ai_tools = log.ai_tools_called;
                    current.ai_full_response = log.ai_full_response;
                    break;

                case 'action_executed':
                    current.action_type = log.action_type;
                    current.action_input = log.action_input;
                    current.action_success = log.action_success;
                    current.error_message = log.error_message;
                    break;
            }
        }
    }

    // Não esquecer a última interação
    if (current) {
        const t1 = new Date(current.timestamp).getTime();
        const t2 = new Date(current.events[current.events.length - 1].created_at).getTime();
        current.duration_ms = t2 - t1;
        interactions.push(current);
    }

    return interactions;
}
```

## Query correta (DEVE ser ascending: true):

```javascript
const { data, error } = await supabaseDB2
    .from('v_exec_log_with_user')
    .select('*')
    .eq('user_phone', phone)
    .not('user_phone', 'is', null)
    .order('created_at', { ascending: true })  // ← OBRIGATÓRIO: mais antigo primeiro
    .limit(500);
```

**NUNCA usar `ascending: false` para a timeline.** A lógica de agrupamento depende da ordem cronológica.

## Exemplo real do banco (imagem enviada 16:26):

```
16:26:49 → message_received  (type=image, msg="[midia]")
16:26:50 → message_routed    (routed_to=premium)
16:26:52 → transcription     (type=image, extracted_data={"text":"Sem ego..."})  ← OCR
16:26:57 → action_executed   (action=padrao, success=true)
16:26:58 → ai_response       (ai_message="Olá! Como posso te ajudar?")
16:26:58 → classification    (branch=padrao)
```

Após `groupIntoInteractions`:
```javascript
{
    timestamp: "16:26:49",
    user_message: "[midia]",           // → mostrar como "🖼️ Imagem enviada"
    message_type: "image",
    extracted_data: { text: "Sem ego..." },  // ← AGORA APARECE
    branch: "padrao",
    ai_message: "Olá! Como posso te ajudar?",  // ← AGORA APARECE
    ai_action: "padrao",
    action_success: true,
    duration_ms: 9000                  // ← 16:26:58 - 16:26:49 = 9s
}
```

## Render do card para imagem:

```javascript
// No ActivityCard:

// 1. Mensagem do user
getUserMessageDisplay(log)  // retorna "🖼️ Imagem enviada"

// 2. OCR (se imagem/PDF)
log.extracted_data && e('div', { className: 'bubble-ocr' },
    log.message_type === 'image' ? '🖼️ Texto extraído da imagem:' : '📄 Texto extraído do PDF:',
    e('div', { className: 'ocr-text' },
        log.extracted_data.text || JSON.stringify(log.extracted_data)
    )
),

// 3. Transcrição (se áudio)
log.transcription && e('div', { className: 'bubble-transcription' },
    '📝 Transcrição: ', log.transcription
),

// 4. Resposta da IA
log.ai_message && e('div', { className: 'bubble-ai' },
    log.ai_message
),

// 5. Footer com latência
e('div', { className: 'card-footer' },
    log.branch && e('span', { className: 'badge badge-branch' }, log.branch),
    log.action_type && e('span', { className: 'badge badge-action' }, log.action_type),
    log.duration_ms > 0 && e('span', { className: 'card-duration' },
        '⏱ ' + (log.duration_ms / 1000).toFixed(1) + 's'
    )
)
```

## Checklist para o dev

- [ ] Query com `ascending: true` (não false)
- [ ] Usar `groupIntoInteractions()` acima (substituir a atual)
- [ ] NÃO usar `interaction_id` para agrupar (cada row tem UUID diferente)
- [ ] Parsear `extracted_data` (pode ser string JSON ou objeto)
- [ ] `getUserMessageDisplay()` para 🎤/🖼️/📄 em vez de "[midia]"
- [ ] Latência = último evento timestamp - primeiro evento timestamp
- [ ] Mostrar OCR text no card quando `extracted_data` existe
