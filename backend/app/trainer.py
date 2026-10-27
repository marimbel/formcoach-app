"""Model D: pretrained Gemini image model that draws the corrected form.

Only text goes to the image model (exercise, error and Gemini's visual_prompt); the user's photo is
never sent, so the illustration is a generic adult, not the user. Results are cached in memory, and
pre-generated images in static/trainer/ (scripts/pregen_trainer_images.py) are the fallback when
generation is slow or fails.
"""
from __future__ import annotations

import asyncio
import base64
import hashlib
import time
from collections import OrderedDict
from pathlib import Path

from .coaching_kb import visual_prompt as default_visual_prompt
from .schemas import TrainerRequest, TrainerResponse
from .settings import Settings

STYLE = (" Style: clean flat instructional fitness illustration, one adult figure, neutral grey background, "
         "full body visible, no text, no logos, no brand names.")


def build_prompt(req: TrainerRequest) -> str:
    try:
        base = req.visual_prompt or default_visual_prompt(req.exercise, req.error)
    except KeyError:
        base = f"Correct {req.exercise.replace('_', ' ')} form."
    return base.strip() + STYLE


class TrainerService:
    def __init__(self, settings: Settings, client=None, cache_size: int = 64):
        self.s = settings
        self.client = client
        self.cache: OrderedDict[str, tuple[bytes, str]] = OrderedDict()
        self.cache_size = cache_size

    def _static(self, exercise: str, error: str) -> tuple[bytes, str] | None:
        for ext, mime in (("png", "image/png"), ("jpg", "image/jpeg")):
            p = Path(self.s.static_dir) / "trainer" / f"{exercise}__{error}.{ext}"
            if p.exists():
                return p.read_bytes(), mime
        return None

    async def generate(self, prompt: str) -> tuple[bytes, str] | None:
        from google.genai import types
        resp = await self.client.aio.models.generate_content(
            model=self.s.image_model, contents=prompt,
            config=types.GenerateContentConfig(response_modalities=["IMAGE"],
                                               image_config=types.ImageConfig(aspect_ratio="3:4")))
        for cand in resp.candidates or []:
            for part in (cand.content.parts if cand.content else []) or []:
                if part.inline_data and part.inline_data.data:
                    return part.inline_data.data, part.inline_data.mime_type or "image/png"
        return None

    async def trainer_image(self, req: TrainerRequest) -> TrainerResponse:
        t0 = time.perf_counter()
        prompt = build_prompt(req)
        key = hashlib.sha1(f"{req.exercise}|{req.error}|{prompt}".encode()).hexdigest()

        def done(data_mime, source):
            data, mime = data_mime if data_mime else (None, "image/png")
            return TrainerResponse(image_b64=base64.b64encode(data).decode() if data else None, mime_type=mime,
                                   source=source, prompt=prompt, latency_ms=(time.perf_counter() - t0) * 1000)

        if key in self.cache:
            self.cache.move_to_end(key)
            return done(self.cache[key], "cache")
        if self.client is not None:
            try:
                out = await asyncio.wait_for(self.generate(prompt), timeout=self.s.image_timeout_s)
                if out:
                    self.cache[key] = out
                    if len(self.cache) > self.cache_size:
                        self.cache.popitem(last=False)
                    return done(out, "generated")
            except Exception:
                pass
        st = self._static(req.exercise, req.error)
        return done(st, "static" if st else "none")
