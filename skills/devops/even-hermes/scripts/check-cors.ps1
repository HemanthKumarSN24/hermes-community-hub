<#
  Even Hermes — 检查 Hermes gateway 的 /chat/stream 是否带 CORS 头
               check whether /api/sessions/{id}/chat/stream sends CORS headers.

  为什么 / Why: 插件的手机 WebView 是跨域调用 gateway。某些 Hermes 版本里
  POST /api/sessions/{id}/chat/stream 的 200 SSE 响应没有 CORS 头(aiohttp 的 CORS
  中间件不处理 StreamResponse),浏览器会直接拒绝跨域响应,插件就报 Failed to fetch。
  注意:400/404 这类错误响应反而带头(走中间件),所以必须确认拿到的是 200 流式响应,
  否则会把失败当成“通过”。

  The plugin phone WebView calls the gateway cross-origin. In some Hermes builds the
  200 SSE response from /chat/stream carries NO CORS header (aiohttp CORS middleware
  does not touch StreamResponse), so the WebView rejects it and the plugin shows
  Failed to fetch - while 400/404 responses DO carry the header, so a failed request
  must not be mistaken for a passing check.

  用法 / Usage:
    .\check-cors.ps1 -BaseUrl http://127.0.0.1:8642 -ApiKey <your key>
    .\check-cors.ps1 -BaseUrl https://hermes.example.com -ApiKey <key> -SessionId abc123

  说明 / Note: 未指定 -SessionId 时会新建一个临时会话做探测(会真的触发一次极小的
  agent turn),结束后自动删除。
  Without -SessionId a throwaway session is created for the probe (it fires a tiny
  agent turn) and deleted afterwards.

  退出码 / Exit codes: 0 = 正常 OK | 1 = 缺 CORS 头 needs the patch | 2 = 无法验证 cannot verify
#>
param(
  [Parameter(Mandatory=$true)][string]$BaseUrl,
  [Parameter(Mandatory=$true)][string]$ApiKey,
  [string]$SessionId = "",
  [int]$MaxSeconds = 15,
  [switch]$KeepProbeSession
)

$ErrorActionPreference = 'Stop'
$BaseUrl = $BaseUrl.TrimEnd('/')

Add-Type -AssemblyName System.Net.Http | Out-Null
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

function Send-Probe {
  param(
    [string]$Method,
    [string]$Url,
    [string]$Json
  )
  $handler = New-Object System.Net.Http.HttpClientHandler
  $handler.AllowAutoRedirect = $true
  $client = New-Object System.Net.Http.HttpClient($handler)
  $client.Timeout = [TimeSpan]::FromSeconds($MaxSeconds)
  $req = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::new($Method), $Url)
  $req.Headers.TryAddWithoutValidation('Authorization', 'Bearer ' + $ApiKey) | Out-Null
  $req.Headers.TryAddWithoutValidation('Origin', 'http://localhost') | Out-Null
  $req.Headers.TryAddWithoutValidation('Accept', 'text/event-stream') | Out-Null
  if ($Json) {
    $req.Content = New-Object System.Net.Http.StringContent($Json, [System.Text.Encoding]::UTF8, 'application/json')
  }
  $result = [ordered]@{ status = 0; cors = ''; contentType = ''; text = ''; error = '' }
  try {
    # ResponseHeadersRead:拿到响应头就返回,不等待整个流结束
    $resp = $client.SendAsync($req, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
    $result.status = [int]$resp.StatusCode
    $allow = $null
    if ($resp.Headers.TryGetValues('Access-Control-Allow-Origin', [ref]$allow)) { $result.cors = ($allow -join ',') }
    if ($resp.Content.Headers.ContentType) { $result.contentType = $resp.Content.Headers.ContentType.MediaType }
    if ($resp.Content.Headers.ContentType -and $resp.Content.Headers.ContentType.MediaType -ne 'text/event-stream') {
      try { $result.text = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult() } catch { }
    } else {
      # 是 SSE:读一点点数据就断开,证明真的是流式
      try {
        $stream = $resp.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $buf = New-Object byte[] 256
        $n = $stream.Read($buf, 0, $buf.Length)
        if ($n -gt 0) { $result.text = ([System.Text.Encoding]::UTF8.GetString($buf, 0, $n)) }
        $stream.Dispose()
      } catch { }
    }
    $resp.Dispose()
  } catch {
    $result.error = $_.Exception.Message
  } finally {
    $client.Dispose()
    $handler.Dispose()
  }
  return [pscustomobject]$result
}

function Show-Result($label, $r) {
  Write-Host ''
  Write-Host ('== ' + $label + ' ==') -ForegroundColor Cyan
  if ($r.error) { Write-Host ('  请求失败 / request failed: ' + $r.error) -ForegroundColor Red; return }
  Write-Host ('  status       : ' + $r.status)
  Write-Host ('  content-type : ' + $r.contentType)
  Write-Host ('  access-control-allow-origin : ' + $(if ($r.cors) { $r.cors } else { '(missing / 缺失)' })) -ForegroundColor $(if ($r.cors) { 'Green' } else { 'Red' })
  if ($r.text) {
    $one = ($r.text -split "`n")[0]
    Write-Host ('  first bytes  : ' + $one.Substring(0, [Math]::Min(90, $one.Length))) -ForegroundColor DarkGray
  }
}

# ---- 找一个会话做探测;没有就新建一个(结束删掉) --------------------------------
$createdSession = $false
if (-not $SessionId) {
  Write-Host '新建临时会话做探测 / creating a throwaway session for the probe ...' -ForegroundColor Cyan
  $c = Send-Probe -Method 'POST' -Url ($BaseUrl + '/api/sessions') -Json '{}'
  if ($c.status -eq 201 -or $c.status -eq 200) {
    try { $SessionId = ([regex]::Match($c.text, '"id"\s*:\s*"([^"]+)"').Groups[1].Value) } catch { }
    if (-not $SessionId) {
      # 有些部署只在 header/别处给 id,回退到列表接口
      $l = Send-Probe -Method 'GET' -Url ($BaseUrl + '/api/sessions?limit=1') -Json ''
      $SessionId = ([regex]::Match($l.text, '"id"\s*:\s*"([^"]+)"').Groups[1].Value)
    }
    $createdSession = $true
  } else {
    Write-Host ('无法创建会话 / could not create a session (status ' + $c.status + ') ' + $c.error) -ForegroundColor Red
    Write-Host '检查 BaseUrl / ApiKey / gateway 是否在跑。' -ForegroundColor Red
    exit 2
  }
}
Write-Host ('探测会话 / probe session: ' + $SessionId) -ForegroundColor DarkGray

$stream = Send-Probe -Method 'POST' -Url ($BaseUrl + '/api/sessions/' + $SessionId + '/chat/stream') -Json '{"message":"cors probe"}'
Show-Result 'POST /api/sessions/{id}/chat/stream' $stream

if ($createdSession -and -not $KeepProbeSession) {
  $null = Send-Probe -Method 'DELETE' -Url ($BaseUrl + '/api/sessions/' + $SessionId) -Json ''
  Write-Host '(已删除临时会话 / probe session deleted)' -ForegroundColor DarkGray
}

$control = Send-Probe -Method 'POST' -Url ($BaseUrl + '/v1/responses') -Json '{"model":"hermes-agent","input":"cors probe","stream":true}'
Show-Result '对照 / control: POST /v1/responses' $control

Write-Host ''
$is200 = ($stream.status -eq 200)
$isSse = ($stream.contentType -eq 'text/event-stream')
if (-not ($is200 -and $isSse)) {
  Write-Host '无法验证 / CANNOT VERIFY: 没拿到 200 流式响应(见上)。' -ForegroundColor Yellow
  Write-Host '无法验证 / CANNOT VERIFY: did not get a 200 text/event-stream response.' -ForegroundColor Yellow
  Write-Host '  提示:确认 BaseUrl / API key / gateway;也可能该会话正忙,稍后重试。' -ForegroundColor Yellow
  exit 2
}
if ($stream.cors) {
  Write-Host 'OK  /chat/stream 是 200 流式响应且带 CORS 头 —— 插件可以直接调用。' -ForegroundColor Green
  Write-Host 'OK  /chat/stream returned 200 + CORS headers - the plugin can call it.' -ForegroundColor Green
  exit 0
}
Write-Host 'FAIL /chat/stream 是 200 流式响应但缺少 access-control-allow-origin —— 插件会报 Failed to fetch。' -ForegroundColor Red
Write-Host 'FAIL 200 SSE response has NO access-control-allow-origin -> the plugin shows Failed to fetch.' -ForegroundColor Red
Write-Host '  修复:按 SKILL.md 步骤 3 给 api_server.py 的 StreamResponse 补 CORS 头,再 hermes gateway restart。' -ForegroundColor Yellow
Write-Host '  Fix: patch the StreamResponse headers (SKILL.md step 3), then hermes gateway restart.' -ForegroundColor Yellow
exit 1
