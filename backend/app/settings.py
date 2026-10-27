"""Configuration from environment variables (set them on Cloud Run with --set-env-vars)."""
from __future__ import annotations

import os
from dataclasses import dataclass, field


def _b(name: str, default: bool) -> bool:
    return os.getenv(name, str(default)).lower() in ("1", "true", "yes")


@dataclass
class Settings:
    project: str = field(default_factory=lambda: os.getenv("GOOGLE_CLOUD_PROJECT", ""))
    location: str = field(default_factory=lambda: os.getenv("GOOGLE_CLOUD_LOCATION", "us-central1"))
    # Model B: tuned endpoint "projects/.../locations/.../endpoints/..." from 08_tune_gemini.py
    tuned_model: str = field(default_factory=lambda: os.getenv("TUNED_MODEL", ""))
    base_model: str = field(default_factory=lambda: os.getenv("BASE_MODEL", "gemini-2.5-flash"))
    # Model D: pretrained image generator
    image_model: str = field(default_factory=lambda: os.getenv("IMAGE_MODEL", "gemini-2.5-flash-image"))
    # "tuned" | "base" | "mock" (mock = rule-based drafts, no GCP needed: for app development)
    default_coach: str = field(default_factory=lambda: os.getenv("DEFAULT_COACH", "tuned"))
    api_key: str = field(default_factory=lambda: os.getenv("API_KEY", ""))
    coach_timeout_s: float = field(default_factory=lambda: float(os.getenv("COACH_TIMEOUT_S", "6")))
    image_timeout_s: float = field(default_factory=lambda: float(os.getenv("IMAGE_TIMEOUT_S", "30")))
    send_image: bool = field(default_factory=lambda: _b("SEND_IMAGE_TO_GEMINI", True))
    static_dir: str = field(default_factory=lambda: os.getenv("STATIC_DIR", os.path.join(os.path.dirname(__file__), "..", "static")))
