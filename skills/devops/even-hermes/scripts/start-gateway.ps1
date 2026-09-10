<#
  Even Hermes — 检查并启动 / 重启 Hermes gateway(插件要用的 HTTP API,默认 8642)
               check & start (or restart) the Hermes gateway that serves the HTTP API.

  中:插件通过 http://<主机>:8642 调用 Hermes(API_SERVER_KEY 鉴权)。本脚本会:
      1) 打印 gateway 状态;2) 需要时重启它;3) 用 /health 验证端口真的在监听。
  EN: The plugin talks to Hermes over http://<host>:8642 (auth: API_SERVER_KEY).
      This script (1) prints gateway status, (2) restarts it when asked, and
      (3) verifies the port actually answers on /health.

  用法 / Usage:
    .\start-gateway.ps1                 # 状态 + 健康检查 / status + health check
    .\start-gateway.ps1 -Restart        # 重启后再检查 / restart then check
    .\start-gateway.ps1 -Port 8642
#>
param(
  [switch]$Restart,
  [int]$Port = 8642
)

$ErrorActionPreference = "Continue"

$hermes = Get-Command hermes -ErrorAction SilentlyContinue
if (-not $hermes) {
  Write-Host '找不到 hermes 命令 — 请先安装 Hermes Agent 并确保它在 PATH 里。' -ForegroundColor Red
  Write-Host 'hermes command not found - install Hermes Agent and make sure it is on PATH.' -ForegroundColor Red
  exit 2
}

if ($Restart) {
  Write-Host '重启 gateway / restarting gateway ...' -ForegroundColor Cyan
  hermes gateway restart
  Start-Sleep -Seconds 4
}

Write-Host ''
Write-Host '== hermes gateway status ==' -ForegroundColor Cyan
hermes gateway status

Write-Host ''
Write-Host "== 端口检查 / port check: 127.0.0.1:$Port ==" -ForegroundColor Cyan
try {
  $r = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 6 -UseBasicParsing
  Write-Host "[OK] health: HTTP $($r.StatusCode)  $($r.Content)" -ForegroundColor Green
} catch {
  Write-Host "[XX] 无法访问 /health: $($_.Exception.Message)" -ForegroundColor Yellow
  Write-Host '     试试 / try: hermes gateway restart' -ForegroundColor Yellow
}

$lan = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
        Select-Object -First 1 -ExpandProperty IPAddress)

Write-Host ''
Write-Host '手机端 Base URL 可填 / phone Base URL options:' -ForegroundColor Cyan
Write-Host "  局域网 / LAN      : http://$lan`:$Port"
Write-Host "  本机调试 / local  : http://127.0.0.1:$Port"
Write-Host '  远程 / remote     : https://<你的隧道域名>  (见 SKILL.md 步骤 4)' -ForegroundColor DarkGray
Write-Host ''
Write-Host 'API key 来自 Hermes 的 .env:变量名 API_SERVER_KEY(配置目录: hermes config path)。' -ForegroundColor DarkGray
Write-Host 'API key lives in Hermes .env as API_SERVER_KEY (config dir: hermes config path).' -ForegroundColor DarkGray
