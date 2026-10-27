# Plan and work split

Dates assume the final submission is around **Dec 7**; shift the weeks if your due date differs.
The course requires weekly progress that shows real technical work and **identifiable contributions from
every member**, so each person should commit and push their own area from their own GitHub account.

## Suggested ownership (swap freely)
| Member | Owns | Also |
|---|---|---|
| Marianna | Model A: data pipeline (`01`–`05`), training on Colab, Model A eval + data card | recording sessions |
| Joshua | Flutter app: camera, pose overlay, rep counting, UI, TTS, platform builds | Model C reliability tests |
| Brent | Backend on Cloud Run + Model B: situations, tuning job, base-vs-tuned eval | GCP project/billing |
| Nico | Model D (prompts, pre-generated images, D eval) + full-system evaluation + demo video | report assembly |

**Everyone:** records data, reviews ~¼ of the Gemini targets, rates the blind A/B sheet, runs test sets.

## Weeks
| Week | Dates | Goals | Done when |
|---|---|---|---|
| 1 | Oct 20–26 | Repos on GitHub, issues created, GCP project + billing + Vertex AI enabled, consent notes. App builds on one Android phone with **mock** coach. Backend deployed to Cloud Run (`DEFAULT_COACH=mock`). Record pilot clips (2 people) | Pilot clips pass `01` QA plots; app counts squats on a real phone |
| 2 | Oct 27–Nov 2 | Record everyone (8–12 people incl. ≥2 non-members). Extract, QA, split | `reps.csv` with all classes in train/val/test |
| 3 | Nov 3–9 | Train probe + finetune Model A; export TFLite into app. Build Gemini situations; start review | Model A test table + confusion matrices; app runs Model A on device |
| 4 | Nov 10–16 | Finish target review; tune Gemini; deploy tuned endpoint; run `09` base vs tuned. Pre-generate Model D images | Tuned model live in the app; Model B comparison numbers |
| 5 | Nov 17–23 | Real-world test matrix (`evaluation_protocol.md`), Model C/D evaluation, fix top failure causes | `eval_out/system_metrics.json` + failures walked through |
| 6 | Nov 24–30 | (Thanksgiving week: lighter) Second round of tests after fixes; latency measurements in release builds | Before/after numbers |
| 7 | Dec 1–7 | Report PDF, README links, narrated YouTube demo with unseen user and real failures, presentation | Submitted |

## Risks
- **Too few participants** → Model A overfits. Mitigate: recruit early, two takes per clip, augmentations, report per-participant accuracy honestly.
- **Gemini tuning model availability/quotas** change often → check the tunable model list in week 1; start the job early in week 4.
- **iOS build** needs a Mac; if nobody has one, demo on Android and say so.
- **Chest press pose quality** (lying down, arms crossing the body) may be poor → test in week 2; switch to a standing band press if needed and document it.
- **Cloud costs**: set a billing budget alert; tuning a Flash model on a few hundred examples is usually cheap, but check pricing first.
