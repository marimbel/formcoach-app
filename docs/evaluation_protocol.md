# Evaluation protocol

The course grades evaluation heavily and requires failures to be shown. This is how each part is measured.

## Model A (formcoach-models)
Held-out **test participants** only. `04_eval_model_a.py` gives rep-level accuracy, macro P/R/F1, per-class report,
per-exercise confusion matrices, learning curves, success/failure galleries, and the **pretrained (frozen
backbone) vs fine-tuned** table. `04b_feature_baseline.py` gives the skeleton-only comparison.
Discuss: which classes get confused and why (view angle? acted vs. real errors? clothing?).

## Model B (formcoach-models)
`09_eval_gemini.py` on human-reviewed test situations from unseen participants: **base vs tuned** on JSON validity,
schema compliance, action accuracy, error accuracy, cue length, number grounding, latency, per case type
(natural / uncertain / conflict / low_visibility). Plus the blind A/B rating sheet (each group member rates
correctness and clarity 1–5). Export the training/validation loss curves from the Vertex AI console.

## Model C (pretrained, not fine-tuned: test reliability)
From session logs and short dedicated clips: pose fps, % of sessions with reposition prompts, and **rep-count
accuracy** (counted vs. performed) per condition. Show screenshots of failure cases (occlusion, baggy clothes,
lying down for chest press).

## Model D (pretrained: judge outputs)
For each of the 10 error types, generate 3 images. Two raters mark each: right exercise? shows the fix? anatomy
plausible? Report the % passing and show the worst ones.

## Full system: real-camera test matrix
Each set: one performer, one exercise, one acted condition for the whole set (5–8 reps), with the scenario label
typed on the Home screen first: `p11_squat_knee_valgus_dimlight_n8` (`n8` = reps actually performed).

| Condition (`<condition>` token) | Squat | Lunge | Chest press |
|---|---|---|---|
| `bright` indoor | correct + each error | correct + each error | correct + each error |
| `dimlight` | correct + 2 errors | correct + 1 error | correct + 1 error |
| `outdoor` | correct + 1 error | correct + 1 error | – |
| `clutter` (busy background / person walking behind) | correct + 1 error | – | – |
| `occlusion` (chair blocking a leg/arm) | correct | correct | correct |
| `far` (≈4 m) and `close` (≈1.2 m) | correct + 1 error | – | – |
| `unseen` (new person + new room, never in training) | correct + 2 errors | correct + 1 error | correct + 1 error |

Run some sets with the **Base** coach toggle too, so the end-to-end effect of fine-tuning is visible.

Copy the session JSON logs off the phone (Summary → Copy session log, or the app documents folder) into
`eval_logs/`, then:
```bash
python scripts/analyze_sessions.py eval_logs/*.json --out eval_out
```
This answers the rubric questions directly:
- *Does it accomplish the task?* `system_accuracy`, `error_detection_rate`, `false_alarm_rate`
- *Where do errors propagate / which component fails most?* `failure_blame` (C: pose/visibility, A: wrong class,
  B: overrode a correct A or held, backend/fallback) and `failures.csv`
- *Response time?* `end_to_end_ms_p50/p95` (+ per-stage numbers in each log's `stats`)
- *Realistic conditions?* everything again `by_condition`
- *What if one model is wrong?* pick 3–4 rows from `failures.csv` and walk through what each model said.

Also film the phone screen during several sets for the demo video, including at least one failure.
