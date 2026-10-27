"""Model B: fine-tuned Gemini coach, with a rule-based fallback so the app never goes silent."""
from __future__ import annotations

import asyncio
import base64
import random
import time

from .coaching_kb import draft_response
from .prompting import SYSTEM_INSTRUCTION, parse_response, render_user_prompt
from .schemas import CoachRequest, CoachResponse
from .settings import Settings

FIELDS = ("action", "error", "cue", "explanation", "severity", "visual_prompt")


class CoachService:
    def __init__(self, settings: Settings, client=None):
        self.s = settings
        self.client = client  # google.genai.Client, or a fake in tests
        self._rng = random.Random()

    def _model_for(self, which: str) -> str | None:
        if which == "tuned":
            return self.s.tuned_model or None
        if which == "base":
            return self.s.base_model
        return None

    async def _gemini(self, model: str, situation: dict, image: bytes | None, json_mode: bool) -> str:
        from google.genai import types
        parts = []
        if image:  # same order as the training examples: image, then evidence text
            parts.append(types.Part.from_bytes(data=image, mime_type="image/jpeg"))
        parts.append(types.Part.from_text(text=render_user_prompt(situation)))
        cfg = dict(system_instruction=SYSTEM_INSTRUCTION, temperature=0.2, max_output_tokens=512,
                   thinking_config=types.ThinkingConfig(thinking_budget=0))
        if json_mode:
            cfg["response_mime_type"] = "application/json"
        resp = await self.client.aio.models.generate_content(
            model=model, contents=[types.Content(role="user", parts=parts)],
            config=types.GenerateContentConfig(**cfg))
        return resp.text or ""

    def _fallback(self, situation: dict, reason: str, latency=None, problems=None) -> CoachResponse:
        d = draft_response(situation, self._rng)
        return CoachResponse(**{k: d.get(k) for k in FIELDS}, source=reason, model_latency_ms=latency,
                             problems=problems or [])

    async def coach(self, req: CoachRequest) -> CoachResponse:
        situation = req.situation.normalized()
        which = req.model or self.s.default_coach
        model = self._model_for(which)
        if which == "mock":
            return self._fallback(situation, "mock")
        if model is None or self.client is None:
            return self._fallback(situation, f"fallback:{which}_not_configured")
        image = base64.b64decode(req.image_jpeg_b64) if (req.image_jpeg_b64 and self.s.send_image) else None
        t0 = time.perf_counter()
        try:
            text = await asyncio.wait_for(self._gemini(model, situation, image, json_mode=(which == "base")),
                                          timeout=self.s.coach_timeout_s)
        except asyncio.TimeoutError:
            return self._fallback(situation, "fallback:timeout", (time.perf_counter() - t0) * 1000)
        except Exception as e:  # quota, auth, network
            return self._fallback(situation, f"fallback:{type(e).__name__}", (time.perf_counter() - t0) * 1000)
        ms = (time.perf_counter() - t0) * 1000
        obj, problems = parse_response(text)
        hard = {"not_json", "not_object", "bad_action", "cue_not_string"}
        if obj is None or hard & set(problems):
            return self._fallback(situation, "fallback:invalid_output", ms, problems)
        if "cue_too_long" in problems:
            obj["cue"] = " ".join(obj["cue"].split()[:12])
        if obj.get("action") == "hold":
            obj["cue"] = ""
        if obj.get("severity") not in ("low", "medium", "high"):
            obj["severity"] = None
        return CoachResponse(**{k: obj.get(k) for k in FIELDS}, source=f"gemini-{which}", model_latency_ms=ms,
                             problems=problems)
