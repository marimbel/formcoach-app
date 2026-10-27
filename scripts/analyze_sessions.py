#!/usr/bin/env python3
"""Full-system evaluation from the app's session logs (copied off the phone).

    python scripts/analyze_sessions.py logs/*.json --out eval_out

Before each test set, type a scenario label on the Home screen (Testing options) like
    p11_squat_knee_valgus_dimlight_n8
    <participant>_<exercise>_<performed error>_<condition>_n<reps actually performed>
The performer acts out that error (or 'correct') for the whole set, so every rep has a known truth.

Outputs:
  system_metrics.json  overall + per condition: system accuracy, false alarms, misses, rep-count error,
                       latency percentiles, fallback rate
  failures.csv         every wrong rep with the stage blamed (see `blame`)
  per_rep.csv          everything, for your own pivot tables
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ERRORS = {
    "squat": ["correct", "knee_valgus", "forward_lean", "insufficient_depth", "heel_lift"],
    "lunge": ["correct", "knee_alignment", "forward_lean", "insufficient_depth"],
    "chest_press": ["correct", "elbow_flare", "uneven_arms", "partial_rom"],
}


def parse_scenario(label: str, exercise: str) -> dict | None:
    m = re.match(r"^(?P<p>[a-z0-9]+)_(?P<rest>.+)$", label.strip().lower())
    if not m or not m.group("rest").startswith(exercise + "_"):
        return None
    rest = m.group("rest")[len(exercise) + 1:]
    for err in sorted(ERRORS[exercise], key=len, reverse=True):
        if rest == err or rest.startswith(err + "_"):
            tail = rest[len(err) + 1:]
            n = re.search(r"(?:^|_)n(\d+)$", tail)
            cond = re.sub(r"(?:^|_)n\d+$", "", tail) or "default"
            return {"participant": m.group("p"), "truth": err, "condition": cond,
                    "true_reps": int(n.group(1)) if n else None}
    return None


def system_output(reply: dict) -> str:
    a = reply.get("action")
    if a == "coach":
        return reply.get("error") or "unknown"
    if a == "praise":
        return "correct"
    return a or "none"  # hold / reposition


def judge(truth: str, out: str) -> bool:
    if truth == "correct":
        return out in ("correct", "hold")  # no false alarm
    return out == truth


def blame(truth: str, out: str, model_a_top: str, model_a_p: float, reply: dict, model_a_loaded: bool) -> str:
    """Which stage caused a wrong rep (heuristic, explain it in the report)."""
    src = reply.get("source", "")
    if out == "reposition":
        return "C:pose/visibility"
    if not src.startswith("gemini") and src != "mock":
        return "backend/fallback"
    if not model_a_loaded:
        return "A:not_loaded"
    if model_a_top != truth:
        return "A:wrong_class" if out == model_a_top or out in ("hold",) else "A+B:both_wrong"
    return "B:overrode_correct_A" if out != "hold" else "B:held_despite_correct_A"


def pct(v, q):
    if not v:
        return None
    s = sorted(v)
    return s[round((len(s) - 1) * q)]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("logs", nargs="+", type=Path)
    ap.add_argument("--out", type=Path, default=Path("eval_out"))
    args = ap.parse_args()
    rows, sessions = [], []
    for p in args.logs:
        d = json.loads(p.read_text())
        sc = parse_scenario(d.get("scenario", ""), d["exercise"])
        if sc is None:
            print(f"skip {p.name}: scenario label {d.get('scenario')!r} not parseable", file=sys.stderr)
            continue
        sessions.append({"file": p.name, **sc, "exercise": d["exercise"], "coach_model": d.get("coach_model"),
                         "counted_reps": len(d["reps"]), "stats": d.get("stats", {})})
        for r in d["reps"]:
            reply = r.get("reply") or {}
            ma = r["situation"]["model_a"]
            out = system_output(reply)
            ok = judge(sc["truth"], out)
            rows.append({"file": p.name, "exercise": d["exercise"], "coach_model": d.get("coach_model"), **sc,
                         "rep": r["rep"], "model_a_top": ma["top_error"], "model_a_prob": round(ma["top_prob"], 3),
                         "model_a_correct": ma["top_error"] == sc["truth"], "system_out": out, "system_correct": ok,
                         "source": reply.get("source"), "blame": "" if ok else blame(sc["truth"], out, ma["top_error"], ma["top_prob"], reply, r.get("model_a_loaded", True)),
                         "cue": reply.get("cue"), "coach_ms": r.get("coach_ms"), "end_to_end_ms": r.get("end_to_end_ms"),
                         "model_a_ms": r.get("model_a_ms")})
    if not rows:
        sys.exit("no usable sessions")
    args.out.mkdir(parents=True, exist_ok=True)

    def summarize(rs, ss):
        errs = [r for r in rs if r["truth"] != "correct"]
        corr = [r for r in rs if r["truth"] == "correct"]
        count_err = [abs(s["counted_reps"] - s["true_reps"]) for s in ss if s["true_reps"] is not None]
        return {
            "reps": len(rs),
            "system_accuracy": sum(r["system_correct"] for r in rs) / len(rs),
            "model_a_accuracy": sum(r["model_a_correct"] for r in rs) / len(rs),
            "error_detection_rate": (sum(r["system_correct"] for r in errs) / len(errs)) if errs else None,
            # correct reps where the app claimed an error (reposition is "no judgment", not a false alarm)
            "false_alarm_rate": (sum(r["system_out"] not in ("correct", "hold", "reposition") for r in corr) / len(corr)) if corr else None,
            "reposition_rate": sum(r["system_out"] == "reposition" for r in rs) / len(rs),
            "fallback_rate": sum(not str(r["source"]).startswith("gemini") for r in rs) / len(rs),
            "rep_count_abs_error_mean": (sum(count_err) / len(count_err)) if count_err else None,
            "end_to_end_ms_p50": pct([r["end_to_end_ms"] for r in rs if r["end_to_end_ms"] is not None], 0.5),
            "end_to_end_ms_p95": pct([r["end_to_end_ms"] for r in rs if r["end_to_end_ms"] is not None], 0.95),
            "failure_blame": dict(Counter(r["blame"] for r in rs if r["blame"])),
        }

    by_cond = defaultdict(list)
    for r in rows:
        by_cond[r["condition"]].append(r)
    metrics = {"overall": summarize(rows, sessions),
               "by_condition": {c: summarize(rs, [s for s in sessions if s["condition"] == c]) for c, rs in by_cond.items()},
               "by_exercise": {e: summarize([r for r in rows if r["exercise"] == e], [s for s in sessions if s["exercise"] == e])
                               for e in sorted({r["exercise"] for r in rows})},
               "by_coach_model": {m: summarize([r for r in rows if r["coach_model"] == m], [s for s in sessions if s["coach_model"] == m])
                                  for m in sorted({str(r["coach_model"]) for r in rows})}}
    (args.out / "system_metrics.json").write_text(json.dumps(metrics, indent=1))
    keys = list(rows[0].keys())
    with open(args.out / "per_rep.csv", "w", newline="") as f:
        w = csv.DictWriter(f, keys)
        w.writeheader()
        w.writerows(rows)
    with open(args.out / "failures.csv", "w", newline="") as f:
        w = csv.DictWriter(f, keys)
        w.writeheader()
        w.writerows(r for r in rows if not r["system_correct"])
    print(json.dumps(metrics["overall"], indent=1))


if __name__ == "__main__":
    main()
