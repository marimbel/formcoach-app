"""FormCoach backend (Cloud Run): Model B coaching + Model D trainer images.

Local dev without Google Cloud:   DEFAULT_COACH=mock uvicorn app.main:app --reload --port 8080
"""
from __future__ import annotations

import json
import logging
import time

from fastapi import Depends, FastAPI, Header, HTTPException, Request

from .coach import CoachService
from .prompting import PROMPT_VERSION
from .schemas import CoachRequest, CoachResponse, TrainerRequest, TrainerResponse
from .settings import Settings
from .trainer import TrainerService

log = logging.getLogger("formcoach")
logging.basicConfig(level=logging.INFO, format="%(message)s")


def make_client(s: Settings):
    if not s.project:
        return None
    from google import genai
    return genai.Client(vertexai=True, project=s.project, location=s.location)


def create_app(settings: Settings | None = None, client=None, image_client=None) -> FastAPI:
    s = settings or Settings()
    if client is None and s.default_coach != "mock":
        client = make_client(s)
    app = FastAPI(title="FormCoach API", version="1.0")
    app.state.coach = CoachService(s, client)
    app.state.trainer = TrainerService(s, image_client if image_client is not None else client)

    def auth(x_api_key: str | None = Header(default=None)):
        if s.api_key and x_api_key != s.api_key:
            raise HTTPException(status_code=401, detail="bad api key")

    @app.middleware("http")
    async def access_log(request: Request, call_next):
        t0 = time.perf_counter()
        resp = await call_next(request)
        # one JSON line per request -> Cloud Logging; used for the latency section of the report
        log.info(json.dumps({"path": request.url.path, "status": resp.status_code,
                             "ms": round((time.perf_counter() - t0) * 1000, 1)}))
        return resp

    @app.get("/healthz")
    def healthz():
        return {"ok": True, "default_coach": s.default_coach, "tuned_configured": bool(s.tuned_model),
                "prompt_version": PROMPT_VERSION}

    @app.post("/v1/coach", response_model=CoachResponse, dependencies=[Depends(auth)])
    async def coach(req: CoachRequest):
        out = await app.state.coach.coach(req)
        log.info(json.dumps({"event": "coach", "session": req.session_id, "exercise": req.situation.exercise,
                             "rep": req.situation.rep_index, "model_a": req.situation.model_a.top_error,
                             "action": out.action, "error": out.error, "source": out.source,
                             "model_ms": out.model_latency_ms}))
        return out

    @app.post("/v1/trainer-image", response_model=TrainerResponse, dependencies=[Depends(auth)])
    async def trainer_image(req: TrainerRequest):
        return await app.state.trainer.trainer_image(req)

    return app


app = create_app()
