---
name: even-hermes
description: "Deploy the Hermes-side services (gateway, CORS fix, tunnel, local STT) that the Even Hermes G2 glasses plugin needs."
version: 1.0.0
author:
  name: "Pb-207"
  github: "Pb-207"
tags: [even-realities, smart-glasses, hermes, speech-to-text, faster-whisper, cloudflare-tunnel, plugin-setup]
category: devops
platforms: [macos, linux, windows]
published: 2026-09-10
license: MIT
metadata:
  hermes:
    related_skills: [hermes-remote-api-exposure]
    icon: 🕶️
    readme_url: "https://github.com/Pb-207/Even-Hermes"
---

# Even Hermes — 安装与配置指南 / Setup Guide

**Even Hermes** 让 Even Realities G2 智能眼镜变成 Hermes 的随身入口:眼镜端列会话、说话提问、流式看回复;手机端配置与打字。

**Even Hermes** turns Even Realities G2 glasses into a pocket front-end for Hermes: list
sessions, talk, and read streamed replies on the glasses; configure and type on the phone.

> **语言 / Language** — 本文件是中英双语。**只输出用户偏好的那一种语言**,不要两种都念。
> This file is bilingual. **Serve only the user's preferred language** — never read both halves aloud.
>
> **自动引导 / Auto-guidance** — 用户安装/首次使用后,按下面的 **6 步**逐条引导:每条先解释清楚 → 征求同意 → 再执行;用户拒绝就跳过并继续下一条。
> After install / first use, walk the user through the **6 steps** below: explain → ask consent → act.
> If they decline a step, skip it and move on.

| # | 中文 | English |
|---|------|---------|
| 1 | 运行逻辑 | How it works |
| 2 | 配置 gateway(含安全提示) | Configure the gateway (with security notes) |
| 3 | 检查/修复 CORS bug | Check & fix the CORS bug |
| 4 | 远程访问(内网穿透) | Remote access (tunnel) |
| 5 | 语音识别:本地部署或云 API | Speech-to-text: local or cloud |
| 6 | 手机端配置与使用 | Phone setup & usage |

## Overview

Deployment companion for the **Even Hermes** plugin (Even Realities G2 smart glasses as a front-end
for your own Hermes agent). This skill gets the Hermes-side services running — the gateway HTTP API,
the CORS fix the phone WebView needs, optional remote access, and speech-to-text — and then walks
through the phone setup. Every step is explained first, then confirmed before it is applied.
本 skill 负责把 Hermes 端服务配好(网关 API、WebView 需要的 CORS 修复、可选的远程访问、语音识别),
再完成手机端配置;每一步都会先解释、征得同意后再执行。

## Prerequisites

- Hermes Agent installed, with `hermes` on PATH and access to its config dir / `.env`.
- Optional: a GPU for local speech-to-text (CPU works, slower); `cloudflared` for remote access;
  `uv` (or a plain venv) for the bundled faster-whisper server.
- 依赖:Hermes 已安装;本地语音识别建议有 GPU(CPU 也可);远程访问需 cloudflared。

## Verification

- Gateway: `curl -s http://127.0.0.1:8642/health` responds.
- CORS fix: `scripts/check-cors.ps1 -BaseUrl <gateway> -ApiKey <key>` exits `0`.
- Speech-to-text: `curl -s http://127.0.0.1:8765/health` returns `{"status":"ok", ...}`.
- End to end: save the phone settings page, list sessions on the glasses, talk, and read a streamed reply.
- 验收:网关 /health 有响应;check-cors 退出 0;STT /health 正常;手机端保存后能在眼镜上列会话、说话、看到流式回复。

**脚本 / Scripts** — `scripts/start-gateway.ps1`、`scripts/start-stt.ps1`、`scripts/check-cors.ps1`、`scripts/server.py`
**排错 / Troubleshooting** — `references/pitfalls.md`

**安装本 skill / Installing this skill** — 把整个 `even-hermes-skill/` 目录复制到 `~/.hermes/skills/even-hermes/`(或 `$HERMES_HOME/skills/`),Hermes 会在需要时自动加载。
Copy this whole folder to `~/.hermes/skills/even-hermes/` (or `$HERMES_HOME/skills/`) so Hermes loads it automatically.

**脚本运行环境 / Script runtime** — 脚本是 **Windows PowerShell 5.1+**(`.ps1`,已带 UTF-8 BOM,中文注释不会乱码);非 Windows 请按正文里的命令手工执行(STT 服务本身是纯 Python)。
The scripts target **Windows PowerShell 5.1+** (`.ps1`, UTF-8 BOM so Chinese comments do not garble). On other OSes run the equivalent commands from the step text — the STT server itself is plain Python.

---

# 中文指南

## 步骤 1 · 运行逻辑(先讲清楚这个)

用一两句话让用户明白:

- 插件是个**网页应用**,运行在**手机的 Even App 内置浏览器(WebView)**里;
- **眼镜只是"屏幕 + 麦克风"**——插件把文字推到眼镜的文本容器上显示,并按眼镜的按键/滑动做出反应;
- 完整链路:眼镜上选一个**桌面会话** → 单击镜腿说话 → 音频送到 **STT 服务**转成文字 → 文字发给 **Hermes gateway** 的 `POST /api/sessions/{id}/chat/stream` → 回复**逐字流式**回到眼镜,而且**续接同一个桌面会话**(手机/电脑上的历史是互通的);
- **手机端**同一页面下方还有输入框:可以直接打字、加图片发送,效果和语音一样;
- 一句话:**眼镜 = 麦克风 + 屏幕;手机 = 配置 + 打字;Hermes = 大脑;STT = 耳朵。**

## 步骤 2 · 配置 Hermes gateway(先征求同意)

先说明:**插件必须能访问 Hermes 的 HTTP API(默认 8642 端口),并用 `.env` 里的 `API_SERVER_KEY` 鉴权**。问用户是否现在配置。

得到同意后:

1. 确认 gateway 在跑:`. scripts/start-gateway.ps1`(它会打印状态、重启、并做 `/health` 检查);
2. 找到 **API key**:Hermes 的 `.env` 里 `API_SERVER_KEY`(`hermes config path` 能看到配置目录);
3. 记录两个值,第 6 步填进手机端:
   - **Base URL**:局域网通常是 `http://<本机IP>:8642`
   - **API key**:`API_SERVER_KEY` 的值

**安全注意事项(务必告知)**:

- key 要够长、够随机(≥32 字符),**不要**截图/贴聊天/写进代码库;
- **不要把 8642 直接暴露到公网**;远程访问请走步骤 4 的隧道;
- 优先在**局域网**内用;确需公网时:隧道 + 强 key,并考虑限流/白名单;
- 怀疑泄露就换 key:改 `.env` 的 `API_SERVER_KEY` → `hermes gateway restart`;
- 插件只通过 `Authorization` 头鉴权、不带 cookie,所以 CORS 可以放宽到 `*`(见步骤 3),但这**不代表**可以把服务裸奔在公网。

## 步骤 3 · 检查并修复 CORS bug(先检查,再征求同意)

**背景**:某些 Hermes 版本里,`POST /api/sessions/{id}/chat/stream` 返回的 **200 SSE 响应没有 CORS 头**(aiohttp 的 CORS 中间件不处理 `StreamResponse`)。手机 WebView 是跨域调用,浏览器会**直接拒绝**这个响应,插件就报 `Failed to fetch`。更迷惑的是:404 之类的普通响应**反而带头**,所以很容易误判成网络问题。

1. **检查**:`.\scripts\check-cors.ps1 -BaseUrl <你的 gateway 地址> -ApiKey <key>`
   - 退出码 `0` = 正常;`1` = **缺少 CORS 头,需要修复**。
2. **修复(征得同意后)**:编辑 `hermes-agent/gateway/platforms/api_server.py`,给 `/chat/stream` 的 `StreamResponse` **手工加上 CORS 头**(它不走中间件),然后 `hermes gateway restart`:

```python
# 在该 StreamResponse 的 headers 字典里(通常在 "X-Accel-Buffering" 附近)补上:
headers = {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    "X-Accel-Buffering": "no",
    "access-control-allow-origin": "*",
    "access-control-allow-headers": "Authorization, Content-Type, Idempotency-Key, X-Hermes-Session-Id",
    "access-control-allow-methods": "POST, OPTIONS",
}
```

3. **复检**:再跑一次 `check-cors.ps1` 确认返回 `0`。
4. ⚠️ **`hermes update` 会覆盖这个补丁** —— 每次升级 Hermes 之后**重新检查一遍**。

## 步骤 4 · 远程访问(询问是否需要)

如果用户只在**同一局域网**用,直接跳过。

需要在外网/蜂窝网络用 → 引导配置 **Cloudflare 命名隧道**(免费、不用开公网端口):

1. `cloudflared tunnel login` → 浏览器授权你的域名;
2. `cloudflared tunnel create hermes` → 记下 tunnel id 和凭证 json;
3. 写 `config.yml`:
   ```yaml
   tunnel: hermes
   credentials-file: C:\Users\<you>\.cloudflared\<tunnel-id>.json
   ingress:
     - hostname: hermes.example.com
       service: http://127.0.0.1:8642
     - service: http_status:404
   ```
4. `cloudflared tunnel route dns hermes hermes.example.com`;
5. 装成服务:Windows 上 `cloudflared service install`(Linux:`cloudflared service install` 或 systemd);
6. 手机端 Base URL 填 `https://hermes.example.com`。

**安全提醒**:隧道只用到 443;**不要**在插件里填 `http://` 明文地址;仍然要强 key;可选给域名加 WAF/限流。
**替代方案**:Tailscale / ZeroTier(私网互联)、或自建反向代理 + TLS 证书。同类思路也适用于 STT 服务(步骤 5 若需外网访问)。

## 步骤 5 · 语音识别(STT):问用户二选一

**A. 本地部署(免费、隐私好、推荐有 GPU 的机器)**

- 启动:`.\scripts\start-stt.ps1 -Model medium -ApiKey <自定一个 key>`(默认监听 `0.0.0.0:8765`);
- 首次运行会下载模型(脚本默认用 `hf-mirror.com` 加速,可 `-NoMirror` 关掉);
- 手机端填:`Base URL = http://<本机IP>:8765`、`API key = 上面设置的`、`Model = medium`;
- **关键坑**:必须把 `nvidia/*/bin` 加进 `PATH`(脚本已自动处理),否则 ctranslate2 找不到 `cublas64_12.dll`、`cudnn*.dll`、`cudart64_12.dll`,第一次转写就 500;缺 `cudart64_12.dll` 时 `uv pip install nvidia-cuda-runtime-cu12`;
- 没 GPU 也行:`. scripts/start-stt.ps1 -Device cpu -Compute int8`(慢一些)。
- **安全(必读)**:STT 一旦**能被本机以外访问**(隧道、或 `-Bind 0.0.0.0`),就**必须**设置 `-ApiKey`;否则**任何人**都能免费用你的 GPU 转写、并看到转写内容。`start-stt.ps1` 默认绑定 `0.0.0.0`,因此在**没设 key 时服务会拒绝启动**。只在本机用 → `-Bind 127.0.0.1`;确实要无鉴权 → 显式加 `-AllowNoKey`(危险)。

**B. 用云 API(不想本机跑模型)**

- 申请任意 **OpenAI 兼容**的语音转写端点(OpenAI `whisper-1`、或自建的兼容服务);
- 手机端填该 `Base URL`、`API key`、`Model`;
- 注意:音频会上传到你选的服务商,按需评估隐私。

## 步骤 6 · 手机端配置与使用(最后教学)

**配置**(Even App 打开插件 → 配置页):

| 字段 | 填什么 |
|------|--------|
| Hermes 网关 → Base URL | `http://<本机IP>:8642` 或隧道域名 |
| Hermes 网关 → API key | `.env` 里的 `API_SERVER_KEY` |
| Hermes 网关 → 模型 | 默认 `hermes-agent`(可留空) |
| 语音识别 → Base URL / key / model | 步骤 5 里选定的那套 |
| 语言 | 「中文 / English」按钮(同时决定**眼镜端菜单与提示**的语言) |

每次改完点 **「保存并启动」**;配置页底部有**操作指南**,内容随语言切换。

**使用**:

- 眼镜端:单击镜腿 → 进入「桌面端」→ 上下滑动选会话 → 单击进入(可「+ 新建会话」);
- 说话:单击开始、再单击结束;识别到的文字会直接发给 Hermes;
- 回复在此页**逐字流式**显示;双击镜腿 → 回到历史对话;
- **菜单**:在会话列表页「**点击后点按**」镜腿呼出系统菜单 → 里面有「**删除会话**」→ 再点一次确认;
- 手机端:输入框可打字(回车换行、`Ctrl/Cmd+Enter` 或点「发送」),「**+ 图片**」可附图片一起发(需要模型有视觉能力)。

**验收**:①眼镜端能列出桌面会话;②说话后眼镜端逐字出回复且与桌面会话历史互通;③手机端打字/发图同样能触发回复;④配置页中英切换、菜单语言跟随。

---

# English

## Step 1 · How it works (explain this first)

Keep it to a few sentences:

- The plugin is a **web app running inside the Even App's WebView on the phone**;
- The **glasses are only "screen + microphone"** — the plugin pushes text into glasses text containers and reacts to temple gestures;
- Full path: pick a **desktop session** on the glasses → press the temple to talk → audio goes to the **STT service** → text goes to the **Hermes gateway** (`POST /api/sessions/{id}/chat/stream`) → the reply **streams back word by word** and **continues that same desktop session** (history is shared with desktop/phone);
- The **phone page** has a text box too: type or attach an image — same effect as voice;
- In one line: **glasses = mic + screen; phone = config + typing; Hermes = the brain; STT = the ears.**

## Step 2 · Configure the Hermes gateway (ask consent first)

Explain that the plugin must reach the **Hermes HTTP API (default port 8642)** and authenticate
with `API_SERVER_KEY` from Hermes' `.env`. Ask whether to set it up now.

Once agreed:

1. Make sure the gateway runs: `.\scripts\start-gateway.ps1` (prints status, can restart, then health-checks `/health`);
2. Find the **API key**: `API_SERVER_KEY` in Hermes' `.env` (`hermes config path` shows the config dir);
3. Note the two values for step 6:
   - **Base URL** — usually `http://<host-ip>:8642` on a LAN
   - **API key** — the `API_SERVER_KEY` value

**Security notes (state them clearly)**:

- Use a long random key (≥32 chars); never screenshot/paste it into chats or commit it;
- **Do not expose 8642 straight to the internet** — for remote use follow step 4 (tunnel);
- Prefer LAN-only; if you must go public: tunnel + strong key, plus rate limiting / allow-lists if you can;
- Rotate on suspicion: change `API_SERVER_KEY` in `.env` → `hermes gateway restart`;
- The plugin authenticates with an `Authorization` header and sends no cookies, which is why CORS can stay `*` (step 3) — that does **not** mean the service may run wide open.

## Step 3 · Check & fix the CORS bug (check first, then ask consent)

**Background**: in some Hermes builds the **200 SSE response of `POST /api/sessions/{id}/chat/stream` carries no CORS header** (aiohttp's CORS middleware does not touch `StreamResponse`). The phone WebView calls cross-origin, so the browser **rejects** that response and the plugin reports `Failed to fetch`. Confusingly, plain responses such as 404 **do** carry the header — easy to misdiagnose as a network problem.

1. **Check**: `.\scripts\check-cors.ps1 -BaseUrl <your gateway> -ApiKey <key>`
   - exit `0` = fine, exit `1` = **missing CORS header, needs the fix**.
2. **Fix (after consent)**: edit `hermes-agent/gateway/platforms/api_server.py` and add CORS headers **manually** to that `StreamResponse`, then `hermes gateway restart`:

```python
# inside the StreamResponse headers dict (usually near "X-Accel-Buffering"):
headers = {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache",
    "X-Accel-Buffering": "no",
    "access-control-allow-origin": "*",
    "access-control-allow-headers": "Authorization, Content-Type, Idempotency-Key, X-Hermes-Session-Id",
    "access-control-allow-methods": "POST, OPTIONS",
}
```

3. **Re-check** with `check-cors.ps1` until it exits `0`.
4. ⚠️ **`hermes update` overwrites this patch** — re-check after every Hermes upgrade.

## Step 4 · Remote access (ask whether it's needed)

Skip entirely if the user only uses it on the **same LAN**.

For mobile/cellular use, set up a **Cloudflare named tunnel** (free, no inbound ports):

1. `cloudflared tunnel login` → authorize your domain;
2. `cloudflared tunnel create hermes` → note the tunnel id and credentials json;
3. write `config.yml`:
   ```yaml
   tunnel: hermes
   credentials-file: C:\Users\<you>\.cloudflared\<tunnel-id>.json
   ingress:
     - hostname: hermes.example.com
       service: http://127.0.0.1:8642
     - service: http_status:404
   ```
4. `cloudflared tunnel route dns hermes hermes.example.com`;
5. install as a service: `cloudflared service install` (Windows), or systemd on Linux;
6. set the phone Base URL to `https://hermes.example.com`.

**Security**: the tunnel needs only 443; never put a plain `http://` public address in the plugin;
keep the key strong; optionally add WAF / rate limiting on the domain.
**Alternatives**: Tailscale / ZeroTier (private mesh), or your own reverse proxy with TLS.
The same approach works if you need remote access to the STT service from step 5.

## Step 5 · Speech-to-text: offer the two options

**A. Local deployment (free, private, best with a GPU)**

- Start: `.\scripts\start-stt.ps1 -Model medium -ApiKey <pick-a-key>` (listens on `0.0.0.0:8765`);
- The model downloads on first run (the script uses `hf-mirror.com` for speed; `-NoMirror` to skip);
- Phone settings: `Base URL = http://<host-ip>:8765`, `API key = the one you set`, `Model = medium`;
- **Critical pitfall**: the `nvidia/*/bin` directories must be on `PATH` (the script does this) or
  ctranslate2 cannot load `cublas64_12.dll` / `cudnn*.dll` / `cudart64_12.dll` and the first
  transcription fails with a 500; if `cudart64_12.dll` is missing: `uv pip install nvidia-cuda-runtime-cu12`;
- No GPU? `. scripts/start-stt.ps1 -Device cpu -Compute int8` (slower, still works).
- **Security (must read)**: if the STT endpoint is reachable **beyond localhost** (tunnel, or `-Bind 0.0.0.0`), you **must** set `-ApiKey`. Otherwise **anyone** can use your GPU for transcription and read the transcripts. `start-stt.ps1` binds `0.0.0.0` by default, so with no key the server **refuses to start**. Local-only → `-Bind 127.0.0.1`; if you really want no auth → pass `-AllowNoKey` explicitly (dangerous).

**B. Cloud API (no local model)**

- Get an **OpenAI-compatible** transcription endpoint (OpenAI `whisper-1`, or a self-hosted compatible one);
- Fill its `Base URL`, `API key`, `Model` in the phone settings;
- Note: audio leaves your machine — evaluate privacy accordingly.

## Step 6 · Phone setup & usage (the walkthrough)

**Configure** (open the plugin in the Even App → settings page):

| Field | Value |
|-------|-------|
| Hermes gateway → Base URL | `http://<host-ip>:8642` or your tunnel domain |
| Hermes gateway → API key | `API_SERVER_KEY` from `.env` |
| Hermes gateway → Model | default `hermes-agent` (may be left as-is) |
| Speech-to-text → Base URL / key / model | whichever you chose in step 5 |
| Language | the 中文 / English buttons — they also set the **glasses menu & hint** language |

Tap **"Save & launch"** after changes; the settings page ends with a built-in usage guide that follows the language switch.

**Use it**:

- Glasses: press the temple → open "Desktop" → swipe to pick a session → press to enter (or "+ new session");
- Talk: press to start, press again to stop; the transcript is sent to Hermes;
- The reply **streams word by word** on that page; double-press the temple to go back to the history;
- **Menu**: on the session list, **tap then press-and-hold** the temple for the system menu → it contains
  **"Delete session"** → tap once more to confirm;
- Phone: type in the box (Enter = newline, `Ctrl/Cmd+Enter` or the Send button to send), or **"+ image"** to attach images (the model needs vision).

**Acceptance**: ① sessions list on the glasses; ② talking streams a reply and shares history with the desktop session; ③ phone typing/image also triggers a reply; ④ language switch works and the menu follows it.
