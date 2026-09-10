<#
  Even Hermes — 启动本地语音识别(STT)服务 / start the local speech-to-text server.

  中:启动一个 OpenAI 兼容的 STT 服务(默认 127.0.0.1:8765),供插件在手机端配置页里填写。
     首次运行会下载模型(默认 medium)。推荐 GPU;纯 CPU 也能跑,只是慢。
  EN: Starts an OpenAI-compatible STT endpoint (default 127.0.0.1:8765) for the plugin's
     phone-side settings page. The model is downloaded on first run (default: medium).
     A GPU is recommended; CPU works but is slower.

  用法 / Usage:
    .\start-stt.ps1                                  # 默认 medium / 8765 / 0.0.0.0
    .\start-stt.ps1 -Model large-v3 -Port 8765
    .\start-stt.ps1 -Model medium -Device cpu -Compute int8
    .\start-stt.ps1 -ApiKey "your-long-random-key"   # 手机端就要填同一个 key(公网/LAN 必填!)
    .\start-stt.ps1 -ModelDir D:\stt-models -NoMirror

  预装 / Prerequisites:
    uv tool install faster-whisper-server      # 或用普通 venv: pip install fastapi uvicorn faster-whisper
    # 缺 cudart64_12.dll 时 / if cudart64_12.dll is missing:
    uv pip install nvidia-cuda-runtime-cu12
#>
param(
  [string]$Model   = "medium",
  [int]   $Port    = 8765,
  [string]$Bind    = "0.0.0.0",
  [string]$ModelDir = "",                                  # 模型缓存目录 / HF cache dir
  [string]$ApiKey  = "",                                   # 留空=不校验(仅 127.0.0.1 允许) / empty = no auth (loopback only)
  [switch]$AllowNoKey,                                     # 显式接受无鉴权(危险,慎用) / explicitly allow no auth (dangerous)
  [ValidateSet("cuda", "cpu")][string]$Device = "cuda",
  [string]$Compute = "",                                   # 默认 cuda→float16, cpu→int8
  [string]$Language = "zh",
  [switch]$NoMirror                                        # 不用国内镜像 / skip the HF mirror
)

$ErrorActionPreference = "Stop"

if (-not $ModelDir -or $ModelDir -eq "") {
  $ModelDir = Join-Path $env:USERPROFILE "stt-models"
}
if (-not $Compute -or $Compute -eq "") {
  $Compute = if ($Device -eq "cuda") { "float16" } else { "int8" }
}

# ---------------------------------------------------------------------------
# 1) 找到 faster-whisper 的 python(优先 uv tool 安装位置,其次 PATH 上的 python)
# ---------------------------------------------------------------------------
$toolRoot = Join-Path $env:APPDATA "uv\tools\faster-whisper-server"
$py = Join-Path $toolRoot "Scripts\python.exe"
if (-not (Test-Path $py)) { $py = Join-Path $toolRoot "bin\python" }
if (-not (Test-Path $py)) { $py = "python" }

# ---------------------------------------------------------------------------
# 2) 关键:把 nvidia/*/bin 加进 PATH
#    否则 ctranslate2 找不到 cublas64_12.dll / cudnn*.dll / cudart64_12.dll,
#    服务会在第一次转写时报 500(日志里是 "Could not locate cublas64_12.dll")。
# ---------------------------------------------------------------------------
$nvRoot = Join-Path $toolRoot "Lib\site-packages\nvidia"
if (Test-Path $nvRoot) {
  Get-ChildItem $nvRoot -Directory | ForEach-Object {
    foreach ($sub in @("bin", "lib")) {
      $p = Join-Path $_.FullName $sub
      if (Test-Path $p) { $env:PATH = "$p;$env:PATH" }
    }
  }
  Write-Host "[stt] nvidia DLL dirs added to PATH" -ForegroundColor DarkGray
} else {
  Write-Host "[stt] no nvidia wheel dir found - CPU-only install?" -ForegroundColor DarkYellow
}

# ---------------------------------------------------------------------------
# 3) 模型缓存 / 下载加速 / 鉴权
# ---------------------------------------------------------------------------
$env:HF_HOME = $ModelDir
$env:HF_HUB_DISABLE_XET = "1"
if (-not $NoMirror -and -not $env:HF_ENDPOINT) { $env:HF_ENDPOINT = "https://hf-mirror.com" }
$env:STT_MODEL   = $Model
$env:STT_DEVICE  = $Device
$env:STT_COMPUTE = $Compute
$env:STT_LANGUAGE = $Language
if ($ApiKey) { $env:STT_API_KEY = $ApiKey }
if ($AllowNoKey) { $env:STT_ALLOW_NO_KEY = "1" }
$env:STT_HOST = $Bind

# 安全闸门提示:非环回监听且没有 key - server.py 会拒绝启动(除非 -AllowNoKey)
$loopback = @("127.0.0.1", "localhost", "::1") -contains $Bind
if (-not $ApiKey -and -not $loopback -and -not $AllowNoKey) {
  Write-Host ""
  Write-Host "！未设置 -ApiKey 且监听地址不是 127.0.0.1 —— 服务会拒绝启动。" -ForegroundColor Red
  Write-Host "  STT_API_KEY is empty while binding to $Bind - the server will refuse to start." -ForegroundColor Red
  Write-Host "  加 -ApiKey \"<长随机 key>\",或 -Bind 127.0.0.1,或显式 -AllowNoKey。" -ForegroundColor Red
  Write-Host ""
}
$env:STT_PORT = "$Port"

$serverPy = Join-Path $PSScriptRoot "server.py"
if (-not (Test-Path $serverPy)) { throw "server.py not found next to this script: $serverPy" }

$lan = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } |
        Select-Object -First 1 -ExpandProperty IPAddress)

Write-Host ""
Write-Host "STT 服务 / STT server" -ForegroundColor Cyan
Write-Host "  model   : $Model  ($Device/$Compute)"
Write-Host "  listen  : $Bind`:$Port"
Write-Host "  cache   : $ModelDir"
Write-Host "  auth    : $(if ($ApiKey) { 'API key required' } else { 'no key (LAN only)' })"
Write-Host "  手机端填 / phone settings:" -ForegroundColor Yellow
Write-Host "    Base URL : http://$lan`:$Port      (局域网 / LAN)$(if ($Bind -eq '127.0.0.1') { '   <-- 注意:仅本机可访问 / localhost only!' })"
Write-Host "    API key  : $(if ($ApiKey) { $ApiKey } else { '(留空 / leave empty)' })"
Write-Host "    Model    : $Model"
Write-Host ""
Write-Host "按 Ctrl+C 停止 / press Ctrl+C to stop" -ForegroundColor DarkGray
Write-Host ""

& $py -m uvicorn server:app --app-dir $PSScriptRoot --host $Bind --port $Port
