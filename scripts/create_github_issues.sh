#!/usr/bin/env bash
# Creates labels, milestones and the starter issue list in both repos.
#   APP=org/formcoach-app MODELS=org/formcoach-models \
#   MARI=gh-user JOSH=gh-user BRENT=gh-user NICO=gh-user  ./scripts/create_github_issues.sh
# Requires `gh auth login`. Safe to re-run labels; issues are created each run, so run once.
set -euo pipefail
: "${APP:?set APP=owner/formcoach-app}" "${MODELS:?set MODELS=owner/formcoach-models}"
MARI=${MARI:-}; JOSH=${JOSH:-}; BRENT=${BRENT:-}; NICO=${NICO:-}

for R in "$APP" "$MODELS"; do
  for L in "model-a:1f77b4" "model-b:9467bd" "model-c:2ca02c" "model-d:e377c2" "app:ff7f0e" "backend:8c564b" "data:17becf" "eval:d62728" "docs:7f7f7f"; do
    gh label create "${L%%:*}" --color "${L##*:}" --repo "$R" --force >/dev/null
  done
  for M in "W1 setup:2026-10-26" "W2 data:2026-11-02" "W3 model A:2026-11-09" "W4 gemini:2026-11-16" "W5 evaluation:2026-11-23" "W7 final:2026-12-07"; do
    gh api "repos/$R/milestones" -f title="${M%%:*}" -f due_on="${M##*:}T23:59:00Z" >/dev/null 2>&1 || true
  done
done

issue() { # repo milestone labels assignee title body
  local a=(); [[ -n "$4" ]] && a=(--assignee "$4")
  gh issue create --repo "$1" --milestone "$2" --label "$3" ${a[@]+"${a[@]}"} --title "$5" --body "$6" >/dev/null && echo "created: $5"
}

issue "$MODELS" "W1 setup" data "$MARI" "Record pilot clips and validate extraction" "Two people, squat correct + knee_valgus. Run 01_extract_reps.py, check QA plots and crops."
issue "$MODELS" "W2 data" data "$MARI" "Record all participants" "Follow docs/data_collection_protocol.md. Track participants + consent privately."
issue "$MODELS" "W2 data" data "$MARI" "Extract, QA and split dataset" "01 + 02, rep_overrides.csv for bad reps, pin non-members to test. Post crosstab in this issue."
issue "$MODELS" "W3 model A" model-a "$MARI" "Train Model A baseline (probe) and fine-tuned" "03_train_model_a.py on Colab GPU. Save runs to Drive."
issue "$MODELS" "W3 model A" "model-a,eval" "$MARI" "Evaluate Model A + skeleton baseline" "04 + 04b. Confusion matrices, galleries, results table, failure discussion."
issue "$MODELS" "W3 model A" model-a "$MARI" "Export TFLite and hand to app" "05_export_tflite.py --fp16; check argmax agreement; copy to app assets."
issue "$MODELS" "W3 model A" model-b "$BRENT" "Build Gemini situations" "06 with real Model A preds. Share sheet, split review among the group."
issue "$MODELS" "W4 gemini" model-b "" "Review Gemini targets (everyone)" "Follow docs/gemini_labeling_guide.md. 100% of test rows; all conflict/uncertain/low_visibility rows."
issue "$MODELS" "W4 gemini" model-b "$BRENT" "Fine-tune Gemini on Vertex AI" "07 -> upload -> 08. Export loss curves from the console."
issue "$MODELS" "W4 gemini" "model-b,eval" "$BRENT" "Base vs tuned Gemini evaluation" "09_eval_gemini.py + blind A/B rating sheet."
issue "$APP" "W1 setup" app "$JOSH" "Generate platform folders, build on Android" "docs/platform_setup.md. Commit android/ ios/. flutter test must pass (parity)."
issue "$APP" "W1 setup" backend "$BRENT" "Deploy backend to Cloud Run (mock mode)" "Service account with Vertex AI User; API_KEY secret; budget alert."
issue "$APP" "W2 data" "app,model-c" "$JOSH" "Verify pose overlay alignment front/back camera" "Skeleton must sit on the body in both cameras; fix mirroring if not."
issue "$APP" "W3 model A" "app,model-a" "$JOSH" "Integrate Model A TFLite on device" "Check model loads, timing in release build, crops look right (debug dump a crop)."
issue "$APP" "W4 gemini" "app,model-b" "$BRENT" "Switch app to tuned Gemini endpoint" "Set TUNED_MODEL, DEFAULT_COACH=tuned; verify source=gemini-tuned in logs."
issue "$APP" "W4 gemini" model-d "$NICO" "Model D prompts + pre-generated images" "pregen_trainer_images.py; pick best per error; record failures."
issue "$APP" "W5 evaluation" "eval,model-d" "$NICO" "Model D evaluation (3 images x 10 errors, 2 raters)" "See docs/evaluation_protocol.md."
issue "$APP" "W5 evaluation" eval "$NICO" "Real-world test matrix + analyze_sessions" "All conditions; include base-coach sets; failures.csv walkthrough."
issue "$APP" "W5 evaluation" "eval,model-c" "$JOSH" "Model C reliability + latency in release build" "Pose fps, rep-count accuracy per condition, end-to-end latency."
issue "$APP" "W7 final" docs "$NICO" "Report PDF + README links" "Follow docs/report_outline.md."
issue "$APP" "W7 final" docs "" "Narrated demo video (unseen user, failures)" "Actual app with camera; no notebooks."
