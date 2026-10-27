import asyncio
import base64
import json
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from app.main import create_app  # noqa: E402
from app.prompting import render_user_prompt  # noqa: E402
from app.settings import Settings  # noqa: E402

SITUATION = {"exercise": "squat", "rep_index": 3, "phase": "bottom", "view": "oblique",
             "pose_quality": {"visibility": 0.934, "required_visible": True},
             "model_a": {"top_error": "knee_valgus", "top_prob": 0.8412,
                         "probs": {"correct": 0.08, "knee_valgus": 0.8412, "forward_lean": 0.04,
                                   "insufficient_depth": 0.02, "heel_lift": 0.0188}},
             "pose_features": {"knee_to_ankle_width": 0.71234, "trunk_lean_deg": 22.0, "heel_lift": None},
             "history": ["knee_valgus"]}


class FakeModels:
    def __init__(self, text=None, delay=0.0, exc=None, image=None):
        self.text, self.delay, self.exc, self.image = text, delay, exc, image
        self.calls = []

    async def generate_content(self, model, contents, config):
        self.calls.append(SimpleNamespace(model=model, contents=contents, config=config))
        await asyncio.sleep(self.delay)
        if self.exc:
            raise self.exc
        if self.image:
            part = SimpleNamespace(inline_data=SimpleNamespace(data=self.image, mime_type="image/png"))
            return SimpleNamespace(candidates=[SimpleNamespace(content=SimpleNamespace(parts=[part]))])
        return SimpleNamespace(text=self.text)


def fake_client(**kw):
    m = FakeModels(**kw)
    return SimpleNamespace(aio=SimpleNamespace(models=m)), m


def settings(**kw):
    base = dict(project="p", tuned_model="projects/p/locations/us-central1/endpoints/1", default_coach="tuned",
                api_key="", coach_timeout_s=0.5, image_timeout_s=0.5, static_dir="/nonexistent")
    base.update(kw)
    return Settings(**base)


GOOD = json.dumps({"action": "coach", "error": "knee_valgus", "cue": "Push your knees out over your toes.",
                   "explanation": "Knee width was 71% of ankle width.", "severity": "medium",
                   "visual_prompt": "Front view squat with knees over toes."})


def test_tuned_happy_path_and_prompt_format():
    client, m = fake_client(text=GOOD)
    api = TestClient(create_app(settings(), client=client))
    img = base64.b64encode(b"\xff\xd8fakejpeg").decode()
    r = api.post("/v1/coach", json={"situation": SITUATION, "image_jpeg_b64": img})
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["source"] == "gemini-tuned" and body["action"] == "coach" and body["cue"].startswith("Push")
    call = m.calls[0]
    assert call.model.endswith("/endpoints/1")
    parts = call.contents[0].parts
    assert parts[0].inline_data is not None  # image first, like training
    text = parts[1].text
    # normalized exactly like the training data (rounded, null preserved)
    assert '"top_prob": 0.841' in text and '"knee_to_ankle_width": 0.712' in text and '"heel_lift": null' in text
    assert call.config.response_mime_type is None  # no JSON mode for the tuned model


def test_prompt_matches_training_renderer():
    client, m = fake_client(text=GOOD)
    api = TestClient(create_app(settings(), client=client))
    api.post("/v1/coach", json={"situation": SITUATION})
    sent = m.calls[0].contents[0].parts[-1].text
    from app.schemas import Situation
    assert sent == render_user_prompt(Situation(**SITUATION).normalized())


def test_base_model_uses_json_mode():
    client, m = fake_client(text=GOOD)
    api = TestClient(create_app(settings(), client=client))
    r = api.post("/v1/coach", json={"situation": SITUATION, "model": "base"})
    assert r.json()["source"] == "gemini-base"
    assert m.calls[0].model == "gemini-2.5-flash"
    assert m.calls[0].config.response_mime_type == "application/json"


@pytest.mark.parametrize("kw,reason", [(dict(text="I think knees caved"), "fallback:invalid_output"),
                                       (dict(text=GOOD, delay=2.0), "fallback:timeout"),
                                       (dict(exc=RuntimeError("quota")), "fallback:RuntimeError")])
def test_fallbacks_never_leave_user_without_answer(kw, reason):
    client, _ = fake_client(**kw)
    r = TestClient(create_app(settings(), client=client)).post("/v1/coach", json={"situation": SITUATION})
    assert r.status_code == 200
    assert r.json()["source"] == reason and r.json()["action"] in ("coach", "praise", "hold", "reposition")


def test_long_cue_trimmed_and_hold_cleared():
    long = json.loads(GOOD)
    long["cue"] = " ".join(["knees"] * 20)
    client, _ = fake_client(text=json.dumps(long))
    r = TestClient(create_app(settings(), client=client)).post("/v1/coach", json={"situation": SITUATION})
    assert len(r.json()["cue"].split()) == 12 and "cue_too_long" in r.json()["problems"]
    hold = dict(json.loads(GOOD), action="hold")
    client, _ = fake_client(text=json.dumps(hold))
    r = TestClient(create_app(settings(), client=client)).post("/v1/coach", json={"situation": SITUATION})
    assert r.json()["cue"] == ""


def test_mock_mode_without_cloud():
    api = TestClient(create_app(settings(default_coach="mock", project="")))
    r = api.post("/v1/coach", json={"situation": SITUATION})
    assert r.json()["source"] == "mock" and r.json()["action"] == "coach"
    low = dict(SITUATION, pose_quality={"visibility": 0.3, "required_visible": False})
    assert api.post("/v1/coach", json={"situation": low}).json()["action"] == "reposition"


def test_validation_and_auth():
    api = TestClient(create_app(settings(api_key="secret", default_coach="mock")))
    assert api.post("/v1/coach", json={"situation": SITUATION}).status_code == 401
    ok = api.post("/v1/coach", json={"situation": SITUATION}, headers={"x-api-key": "secret"})
    assert ok.status_code == 200
    bad = dict(SITUATION, exercise="deadlift")
    assert api.post("/v1/coach", json={"situation": bad}, headers={"x-api-key": "secret"}).status_code == 422
    assert api.get("/healthz").json()["ok"]


def test_trainer_generate_then_cache_then_static(tmp_path):
    (tmp_path / "trainer").mkdir()
    (tmp_path / "trainer" / "squat__knee_valgus.png").write_bytes(b"PNGSTATIC")
    client, m = fake_client(image=b"PNGDATA")
    api = TestClient(create_app(settings(static_dir=str(tmp_path)), client=client))
    req = {"exercise": "squat", "error": "knee_valgus", "visual_prompt": "Front view squat, knees over toes."}
    r1 = api.post("/v1/trainer-image", json=req).json()
    assert r1["source"] == "generated" and base64.b64decode(r1["image_b64"]) == b"PNGDATA"
    assert "no text" in r1["prompt"] and m.calls[0].config.response_modalities == ["IMAGE"]
    assert api.post("/v1/trainer-image", json=req).json()["source"] == "cache"
    client2, _ = fake_client(exc=RuntimeError("down"))
    api2 = TestClient(create_app(settings(static_dir=str(tmp_path)), client=client2))
    r3 = api2.post("/v1/trainer-image", json=req).json()
    assert r3["source"] == "static" and base64.b64decode(r3["image_b64"]) == b"PNGSTATIC"
