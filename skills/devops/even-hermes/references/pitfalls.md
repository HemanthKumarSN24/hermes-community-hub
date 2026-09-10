# 已知坑与排错 / Pitfalls & Troubleshooting

中英对照,每条一行。中文在前,English after。
Bilingual, one item per block — 中文 then English.

**范围**:只覆盖**部署**——把 Hermes 端服务跑起来、让插件连上时会遇到的问题。
**Scope**: **deployment only** — issues you hit while getting the Hermes-side services running and the plugin connected.

---

## 1. 插件报 `Failed to fetch`(眼镜端/手机端都一样)

**原因**:Hermes 某些版本里 `POST /api/sessions/{id}/chat/stream` 的 **200 SSE 响应没有 CORS 头**(aiohttp 的 CORS 中间件不处理 `StreamResponse`)。WebView 跨域,浏览器直接拒绝该响应。注意 404 之类的响应**反而带头**,别被误导。
**处理**:跑 `scripts/check-cors.ps1`;缺头就按 `SKILL.md` 步骤 3 给 `api_server.py` 的 `StreamResponse` 加 CORS 头,然后 `hermes gateway restart`。

**Cause**: on some Hermes builds the 200 SSE response of `/chat/stream` carries **no CORS header**
(aiohttp's CORS middleware skips `StreamResponse`); the cross-origin WebView then rejects it.
Plain 404 responses DO carry the header, which misleads.
**Fix**: run `scripts/check-cors.ps1`; if missing, patch the `StreamResponse` headers per step 3, then restart the gateway.

---

## 2. 升级 Hermes 之后又坏了(`hermes update` 覆盖补丁)

`hermes update` 会把 `api_server.py` 换成新版,**CORS 补丁会消失** → 插件又开始 `Failed to fetch`。
**处理**:每次升级后重跑 `scripts/check-cors.ps1`;必要时重新打补丁。

`hermes update` replaces `api_server.py` and **wipes the CORS patch** → `Failed to fetch` returns.
Re-run `check-cors.ps1` after every upgrade and re-apply the patch if needed.

---

## 3. 本地 STT 第一次转写就 500(`cublas64_12.dll` 找不到)

**原因**:Windows 上 ctranslate2 首次跑模型时要 dlopen `cublas64_12.dll` / `cudnn*.dll` / `cudart64_12.dll`。这些来自 nvidia pip wheels,位于 `<site-packages>/nvidia/*/bin`,**不在默认 PATH 里**。
**处理**:用 `scripts/start-stt.ps1` 启动(它会把 `nvidia/*/bin` 前置进 PATH);连 `cudart64_12.dll` 都缺时执行 `uv pip install nvidia-cuda-runtime-cu12`。
**注意**:只在 Python 里 `os.add_dll_directory()` **不一定够**(`scripts/server.py` 里两边都做了,双保险)。

**Cause**: on Windows ctranslate2 dlopens `cublas64_12.dll` / `cudnn*.dll` / `cudart64_12.dll` on first run;
they ship in the nvidia pip wheels under `<site-packages>/nvidia/*/bin` and are **not on PATH**.
**Fix**: always start via `scripts/start-stt.ps1` (prepends those dirs); if `cudart64_12.dll` is missing,
`uv pip install nvidia-cuda-runtime-cu12`. `os.add_dll_directory()` alone is not always enough.

---

## 4. 插件只在眼镜前台工作(别期待后台提醒)

Even Hub 插件**没有通知/推送接口**,而且**只能在眼镜前台运行**:息屏或切到后台时,WebView 被系统挂起,连网络请求都会停。所以"息屏时自动检测并提醒"这类功能是做不到的。需要提醒请走**插件之外**的渠道(例如让 Hermes 把消息推到手机上的即时通讯,再由 Even App 的通知设置同步给眼镜)。

The SDK exposes **no notification/push API** and the plugin is **foreground-only** (a backgrounded WebView is
suspended, network stalls). So "detect while the screen is off and notify" is not possible. If you need an
alert, use an **out-of-plugin** channel (e.g. Hermes pushing to a phone messenger, then Even App's
notification settings mirroring it to the glasses).

---

## 5. 手机 Even App 版本太旧,插件装不上/黑屏

新 SDK 打包会把**最低 Even App 版本**抬上去(例如 SDK 0.0.15 → **≥2.2.10**)。手机端 Even App 低于该版本时,插件可能装不上或打开即黑屏。
**处理**:把 Even App 升级到最新;仍然失败时确认插件 build 的最低版本要求。

A newer SDK raises the **minimum Even App version** (e.g. SDK 0.0.15 → **≥2.2.10**). An older Even App may
fail to install the plugin or show a black screen. Update Even App; if it still fails, check the build's
minimum version requirement.
