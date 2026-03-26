# Bloco M+ — Logs extras no Main

Todos usam credential **Total Supabase** (kQkN5PrZm2GihQfS).
Todos têm `continueOnFail: true` — não travam o fluxo.
Todos são saída **paralela** — não interrompem o caminho existente.

---

## 1. Onboarding — novo user (stg=0)

**Arquivo:** `01-log-onboarding-new-user.json`
**Conectar após:** `Create a row1` (phones_whatsapp) — saída paralela

```
Switch output[0] → Create a row1 → Send message4 (existente)
                                  → Log: onboarding new_user (NOVO, paralelo)
```

---

## 2. Onboarding — mudança de estágio

**Arquivo:** `02-log-onboarding-stg-change.json`
**Conectar após:** cada node de Update stg — saída paralela

Duplicar (`Ctrl+D`) e conectar em:
- `Update a row` (stg=2) — após user enviar email
- `Update a row1` (stg=3) — após envio de OTP
- `Update stg to 4` — após conta verificada (OTP ok pela 1ª vez)
- `Update stg to 5` — após verificação secundária
- `Corrigir volta stg 2` — user corrigiu email

---

## 3. Onboarding — OTP verificado com sucesso

**Arquivo:** `03-log-onboarding-otp-verified.json`
**Conectar após:** `Update stg to 5` e `Update stg to 6` — saída paralela

```
Verify OTP Code → [sucesso] → Update stg to 5 → (existente)
                                                → Log: otp_verified (NOVO)
```

---

## 4. Onboarding — OTP falhou

**Arquivo:** `04-log-onboarding-otp-failed.json`
**Conectar após:** `Msg Código Inválido` e `Msg Código Inválido1` — saída paralela

```
Verify OTP Code → [falha] → Msg Código Inválido → (existente)
                                                 → Log: otp_failed (NOVO)
```

---

## 5. Resumo de áudio

**Arquivo:** `05-log-audio-summary.json`
**Conectar após:** `Message a model` — saída paralela (junto com Send message5)

```
Message a model → Send message5 (existente)
               → Log: audio_summary (NOVO, paralelo)
```

Captura: `summary_text` = output do GPT-4.1-mini que resumiu o áudio.

---

## 6. Plano inativo

**Arquivo:** `06-log-plano-inativo.json`
**Conectar após:** `PLANO INATIVO` — saída paralela

```
If9 → [false/plano inativo] → PLANO INATIVO (envia msg WhatsApp)
                             → Log: plano.inativo (NOVO, paralelo)
```

Captura: user_phone, user_id, action_type="plano.inativo".

---

## Resumo

| # | Node | Conectar após | Duplicar? |
|---|------|-------------|-----------|
| 1 | Log: onboarding new_user | `Create a row1` | Não |
| 2 | Log: onboarding stg_change | Cada Update de stg | Sim, 5x |
| 3 | Log: otp_verified | `Update stg to 5` e `Update stg to 6` | Sim, 2x |
| 4 | Log: otp_failed | `Msg Código Inválido` e `Msg Código Inválido1` | Sim, 2x |
| 5 | Log: audio_summary | `Message a model` | Não |
| 6 | Log: plano.inativo | `PLANO INATIVO` | Não |

**Total: 6 JSONs, ~11 nodes no workflow (com duplicatas).**
