# Documentation report outline (maps to the course's required sections)

1. **Project overview**: problem, users, why CV (proposal §1–3, updated).
2. **System architecture**: diagram + model table from `docs/architecture.md` (Model / Purpose / Input / Output / Location / Customization / Next step), and why each model is needed.
3. **Installation / setup**: `docs/platform_setup.md`, backend deploy commands, models repo README.
4. **Data**: data card per model: sources, collection protocol, # participants/videos/reps/crops, labels, preprocessing, split table per class, limitations, biases, relabelled reps. Gemini data: # situations per case type, how targets were written/reviewed.
5. **Model A specs + results**: architecture, training config (`run_config.json`), learning curves, test table **probe vs fine-tuned** (+ skeleton baseline), confusion matrices, per-participant accuracy, success and failure galleries with reasons.
6. **Model B (Gemini fine-tuning) specs + results**: base model, JSONL format, epochs/adapter/LR, loss curves, **base vs tuned** metrics overall and per case type, blind A/B ratings, example good/bad replies, discussion.
7. **Additional models (C, D)**: specs; C reliability (fps, rep-count accuracy, failure screenshots); D rated outputs incl. bad generations.
8. **Mobile app GUI + specs**: screenshots of the 4 screens, failure UI (reposition banner, offline, no Model A), accessibility (speech, large text, haptics).
9. **Cloud / backend specs**: endpoints, schemas, fallback logic, auth, region, costs, logging.
10. **Testing / evaluation**: model metrics + full-system results from `analyze_sessions.py`: by condition, error propagation (`failure_blame`), latency p50/p95, tuned vs base end to end.
11. **Results discussion**: outcomes, failures (with screenshots), limitations, what you'd do next.
12. **Reproducing the system**: step list across both repos.
13. **Demo video link**, **References**.
