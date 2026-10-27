"""Request/response contract between the Flutter app and the backend."""
from __future__ import annotations

import math
from typing import Literal

from pydantic import BaseModel, Field

Exercise = Literal["squat", "lunge", "chest_press"]


class PoseQuality(BaseModel):
    visibility: float = Field(ge=0, le=1)
    required_visible: bool


class ModelAResult(BaseModel):
    top_error: str
    top_prob: float = Field(ge=0, le=1)
    probs: dict[str, float]


class Situation(BaseModel):
    """Exactly the evidence used in the fine-tuning examples (see prompting.render_user_prompt)."""
    exercise: Exercise
    rep_index: int = Field(ge=1)
    phase: str = "bottom"
    view: str = "unknown"
    pose_quality: PoseQuality
    model_a: ModelAResult
    pose_features: dict[str, float | None] = {}
    history: list[str] = Field(default_factory=list, max_length=3)

    def normalized(self) -> dict:
        """Round like the training data so the prompt text matches what the tuned model saw."""
        d = self.model_dump()
        d["pose_quality"]["visibility"] = round(d["pose_quality"]["visibility"], 2)
        d["model_a"]["top_prob"] = round(d["model_a"]["top_prob"], 3)
        d["model_a"]["probs"] = {k: round(v, 3) for k, v in d["model_a"]["probs"].items()}
        d["pose_features"] = {k: (None if v is None or (isinstance(v, float) and math.isnan(v)) else round(v, 3))
                              for k, v in d["pose_features"].items()}
        return d


class CoachRequest(BaseModel):
    session_id: str = ""
    situation: Situation
    image_jpeg_b64: str | None = Field(default=None, max_length=400_000)
    model: Literal["tuned", "base", "mock"] | None = None


class CoachResponse(BaseModel):
    action: Literal["coach", "praise", "reposition", "hold"]
    error: str | None = None
    cue: str = ""
    explanation: str = ""
    severity: Literal["low", "medium", "high"] | None = None
    visual_prompt: str | None = None
    source: str  # gemini-tuned | gemini-base | mock | fallback:<reason>
    model_latency_ms: float | None = None
    problems: list[str] = []


class TrainerRequest(BaseModel):
    exercise: Exercise
    error: str
    visual_prompt: str | None = Field(default=None, max_length=600)


class TrainerResponse(BaseModel):
    image_b64: str | None
    mime_type: str = "image/png"
    source: str  # generated | cache | static | none
    prompt: str
    latency_ms: float
