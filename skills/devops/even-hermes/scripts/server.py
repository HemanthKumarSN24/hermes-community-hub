"""OpenAI-compatible + WebSocket real-time STT server (faster-whisper) for Even Hermes.

REST:  GET  /health
       GET  /v1/models
       POST /v1/audio/transcriptions        (multipart file=..., OpenAI-compatible)
WS:    /{path}  send a config JSON message, then stream 16 kHz / 16-bit / mono PCM;
       the server replies with Deepgram-style ``{"type":"Results","is_final":...}``
       (a partial every ~1 s, and a final on silence/disconnect).

Env vars
--------
STT_API_KEY   optional. When set, HTTP requests must send ``Authorization: Bearer <key>``.
              When unset, requests without a key are allowed ONLY while the server is
              bound to a loopback address — see the startup guard below.
STT_HOST      bind address                                (default: 0.0.0.0)
STT_ALLOW_NO_KEY  set to 1/true/yes to allow an empty STT_API_KEY even on a
                  non-loopback bind (DANGEROUS: anyone who can reach the port).
STT_MODEL     whisper model name or local path            (default: medium)
STT_DEVICE    cuda | cpu                                  (default: cuda)
STT_COMPUTE   float16 | int8_float16 | int8 | ...         (default: float16 on cuda, int8 on cpu)
STT_LANGUAGE  default language hint for WS                (default: zh)
"""
import os
import sys
import glob
import json
import wave
import io
import time
import asyncio
import tempfile
import threading

# ---------------------------------------------------------------------------
# CUDA runtime DLLs. On Windows ctranslate2 dlopens cublas64_12.dll / cudnn*.dll /
# cudart64_12.dll when the model first runs; with the nvidia pip wheels they live
# under <site-packages>/nvidia/*/bin, so we register those directories explicitly.
# (Belt-and-braces: start-stt.ps1 also prepends them to PATH.)
# ---------------------------------------------------------------------------
def _register_nvidia_dlls() -> list[str]:
    roots: list[str] = []
    for base in (os.path.dirname(sys.executable), os.path.dirname(os.path.dirname(sys.executable))):
        for sp in (os.path.join(base, "Lib", "site-packages"), os.path.join(base, "lib", "site-packages")):
            if os.path.isdir(sp):
                roots.append(sp)
    added: list[str] = []
    for sp in roots:
        for pat in ("nvidia/*/bin", "nvidia/*/lib"):
            for d in glob.glob(os.path.join(sp, pat)):
                try:
                    os.add_dll_directory(d)
                    added.append(d)
                except OSError:
                    pass
    return added


_REGISTERED_DLL_DIRS = _register_nvidia_dlls()

from fastapi import FastAPI, UploadFile, File, Header, HTTPException, WebSocket  # noqa: E402
from fastapi.middleware.cors import CORSMiddleware  # noqa: E402
from faster_whisper import WhisperModel  # noqa: E402

API_KEY = os.environ.get("STT_API_KEY", "")
STT_HOST = os.environ.get("STT_HOST", "0.0.0.0")
STT_ALLOW_NO_KEY = os.environ.get("STT_ALLOW_NO_KEY", "").strip().lower() in ("1", "true", "yes", "on")


def _is_loopback(host: str) -> bool:
    h = (host or "").strip().strip("[]").lower()
    return h in ("127.0.0.1", "localhost", "::1", "0:0:0:0:0:0:0:1") or h.startswith("127.")


# --------------------------------------------------------------------------
# Startup guard: with no API key and a non-loopback bind (LAN / tunnel), anyone
# who can reach the port can burn this machine's GPU and read transcripts.
# Refuse to start unless the operator explicitly opts out.
# --------------------------------------------------------------------------
if not API_KEY and not _is_loopback(STT_HOST) and not STT_ALLOW_NO_KEY:
    print(
        "[stt] REFUSING TO START: STT_HOST=" + str(STT_HOST) + " is not loopback but STT_API_KEY is empty.\n"
        "[stt] 拒绝启动:监听地址不是环回地址,却没有设置 STT_API_KEY ——\n"
        "[stt]   局域网/公网里任何人都能用这台机器转写(消耗 GPU、读走转写内容)。\n"
        "[stt] 三种解决办法 / pick one:\n"
        "[stt]   1) 设置 key:      start-stt.ps1 -ApiKey \"<long-random-key>\"\n"
        "[stt]   2) 只本机监听:    start-stt.ps1 -Bind 127.0.0.1\n"
        "[stt]   3) 显式接受无鉴权: start-stt.ps1 -AllowNoKey",
        file=sys.stderr, flush=True,
    )
    raise SystemExit(1)
MODEL = os.environ.get("STT_MODEL", "medium")
DEVICE = os.environ.get("STT_DEVICE", "cuda")
COMPUTE = os.environ.get("STT_COMPUTE", "float16" if DEVICE == "cuda" else "int8")
DEFAULT_LANGUAGE = os.environ.get("STT_LANGUAGE", "zh") or None

app = FastAPI(title="even-hermes-local-stt")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

_model = None
_lock = threading.Lock()


def get_model() -> WhisperModel:
    global _model
    if _model is None:
        with _lock:
            if _model is None:
                print(f"[stt] loading {MODEL} on {DEVICE}/{COMPUTE} ...", flush=True)
                _model = WhisperModel(MODEL, device=DEVICE, compute_type=COMPUTE)
                print("[stt] model ready", flush=True)
    return _model


def _transcribe_pcm(pcm: bytes, language: str | None = None) -> str:
    """16 kHz / 16-bit / mono PCM bytes -> text."""
    if not pcm:
        return ""
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(16000)
        w.writeframes(pcm)
    path = None
    try:
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            f.write(buf.getvalue())
            path = f.name
        lang = None if (language in ("", "auto", None)) else language
        segs, _info = get_model().transcribe(path, beam_size=1, language=lang)
        return "".join(s.text for s in segs).strip()
    finally:
        if path:
            try:
                os.unlink(path)
            except OSError:
                pass


def check_auth(authorization: str | None) -> None:
    """No key configured -> allow (LAN). Key configured -> must match."""
    if not API_KEY:
        return
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "authorization failed")
    if authorization.split(" ", 1)[1].strip() != API_KEY:
        raise HTTPException(401, "authorization failed")


@app.get("/health")
def health():
    return {
        "status": "ok",
        "model": MODEL,
        "device": DEVICE,
        "compute": COMPUTE,
        "dll_dirs": len(_REGISTERED_DLL_DIRS),
        "auth_required": bool(API_KEY),
    }


@app.get("/v1/models")
def models(authorization: str = Header(None)):
    check_auth(authorization)
    return {"object": "list", "data": [{"id": MODEL, "object": "model"}]}


@app.post("/v1/audio/transcriptions")
async def transcribe(file: UploadFile = File(...), authorization: str = Header(None)):
    check_auth(authorization)
    data = await file.read()
    if not data:
        raise HTTPException(400, "empty audio")
    with tempfile.NamedTemporaryFile(suffix=file.filename or ".wav", delete=False) as f:
        f.write(data)
        path = f.name
    try:
        segs, info = get_model().transcribe(path, beam_size=1)
        text = "".join(s.text for s in segs).strip()
        print(f"[REST-STT] lang={info.language} text={text!r}", flush=True)
        return {"text": text}
    finally:
        try:
            os.unlink(path)
        except OSError:
            pass


def _dg_result(text: str, is_final: bool, utterance_index: int = -1) -> str:
    return json.dumps({
        "type": "Results",
        "is_final": is_final,
        "channel": {"alternatives": [{"transcript": text}]},
        "utterance_index": utterance_index,
    })


@app.websocket("/{path:path}")
async def ws_stt(websocket: WebSocket, path: str):
    """Config JSON first, then 16 kHz PCM frames; partials every ~1 s, final on silence."""
    await websocket.accept()
    audio = bytearray()
    language = DEFAULT_LANGUAGE or "zh"
    chunks = 0
    last_partial = ""
    print(f"[WS] connected path=/{path}", flush=True)

    async def send_transcript(final: bool) -> None:
        nonlocal last_partial
        if not audio:
            return
        text = await asyncio.to_thread(_transcribe_pcm, bytes(audio), language)
        if text and (final or text != last_partial):
            last_partial = text
            try:
                await websocket.send_text(_dg_result(text, final))
                print(f"[STT] {'FINAL' if final else 'PARTIAL'} {time.time():.0f} text={text[:30]!r}", flush=True)
            except Exception as e:  # noqa: BLE001
                print("[STT] send err", e, flush=True)

    try:
        while True:
            try:
                m = await asyncio.wait_for(websocket.receive(), timeout=0.7)
            except asyncio.TimeoutError:
                print("[WS] silence -> final", flush=True)
                await send_transcript(True)
                break
            t = m.get("type", "")
            if t == "websocket.disconnect":
                print("[WS] disconnect -> final", flush=True)
                await send_transcript(True)
                break
            data = m.get("bytes") or m.get("text") or b""
            if isinstance(data, str):
                print("[WS] config", data[:200], flush=True)
                try:
                    cfg = json.loads(data).get("config", {})
                    raw = str(cfg.get("language") or DEFAULT_LANGUAGE or "zh")
                    language = "zh" if raw.lower().startswith("zh") else ("zh" if raw.lower() == "auto" else raw)
                except Exception:  # noqa: BLE001
                    pass
                try:
                    await websocket.send_text(json.dumps({"type": "Started"}))
                except Exception as e:  # noqa: BLE001
                    print("[WS] started err", e, flush=True)
            else:
                audio += data
                chunks += 1
                if chunks % 20 == 0:            # ~1 s at 50 ms frames
                    await send_transcript(False)
    except Exception as e:  # noqa: BLE001
        print("[WS] err", e, flush=True)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=os.environ.get("STT_HOST", "0.0.0.0"), port=int(os.environ.get("STT_PORT", "8765")))
