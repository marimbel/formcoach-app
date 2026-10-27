#!/usr/bin/env python3
"""Pre-generate one Model D illustration per (exercise, error) into static/trainer/.

These are baked into the container and served when live generation is slow or fails, so the
Visual Trainer screen always has something to show. Review every image by eye before committing:
discard ones with wrong anatomy or wrong form, and note them in the report as Model D failures.

    GOOGLE_CLOUD_PROJECT=your-project python scripts/pregen_trainer_images.py [--n 3]
"""
from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from app.coaching_kb import CUES  # noqa: E402
from app.schemas import TrainerRequest  # noqa: E402
from app.settings import Settings  # noqa: E402
from app.trainer import TrainerService, build_prompt  # noqa: E402


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=2, help="candidates per error; pick the best by hand")
    args = ap.parse_args()
    s = Settings()
    from google import genai
    svc = TrainerService(s, genai.Client(vertexai=True, project=s.project, location=s.location))
    out = Path(s.static_dir) / "trainer" / "candidates"
    out.mkdir(parents=True, exist_ok=True)
    for (exercise, error) in CUES:
        prompt = build_prompt(TrainerRequest(exercise=exercise, error=error))
        for k in range(args.n):
            res = await svc.generate(prompt)
            if not res:
                print(f"FAILED {exercise}/{error}")
                continue
            data, mime = res
            ext = "jpg" if "jpeg" in mime else "png"
            p = out / f"{exercise}__{error}__{k}.{ext}"
            p.write_bytes(data)
            print("wrote", p)
    print(f"Pick one per error and save it as static/trainer/<exercise>__<error>.png")


if __name__ == "__main__":
    asyncio.run(main())
