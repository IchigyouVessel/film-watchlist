# 片单工具 · 本地服务（PowerShell 版，Windows 自带，无需安装任何东西）
#
#   作用：把数据存到 data\state.json，并把页面提供给浏览器
#   地址：http://127.0.0.1:8765/
#   关闭：关掉这个窗口即可
#
# 说明：用 TcpListener 直接实现 HTTP，不需要管理员权限，也不依赖 Python。
#      页面文件名是自动查找的（优先 index.html，其次 app.html / 片单工具.html，再不行扫目录里任意 .html），
#      所以这个文件被改名、或整个包改成英文文件名，都能正常用。

$ErrorActionPreference = 'Stop'

$Root      = $PSScriptRoot
$DataDir   = Join-Path $Root 'data'
$StatePath = Join-Path $DataDir 'state.json'
$BakPath   = Join-Path $DataDir 'state.bak.json'
$Port      = 8765
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Utf8      = [System.Text.Encoding]::UTF8

if (-not (Test-Path $DataDir)) {
    New-Item -ItemType Directory -Path $DataDir | Out-Null
    Write-Host "[init] 已创建数据目录 $DataDir"
}

# ---------- 自动找页面 ----------
$script:PagePath = $null
function Get-PagePath {
    if ($script:PagePath -and (Test-Path $script:PagePath)) { return $script:PagePath }
    foreach ($n in @('index.html', 'app.html', '片单工具.html')) {
        $p = Join-Path $Root $n
        if (Test-Path $p) { $script:PagePath = $p; return $p }
    }
    $any = Get-ChildItem -LiteralPath $Root -Filter '*.html' -File -ErrorAction SilentlyContinue |
           Select-Object -First 1
    if ($any) { $script:PagePath = $any.FullName; return $any.FullName }
    return $null
}

function Write-Response {
    param($Stream, [int]$Code, [string]$ContentType, [byte[]]$Body)

    $reasons = @{ 200 = 'OK'; 204 = 'No Content'; 400 = 'Bad Request'; 404 = 'Not Found'; 500 = 'Internal Server Error' }
    $reason  = $reasons[$Code]
    if (-not $reason) { $reason = 'OK' }
    if ($null -eq $Body) { $Body = New-Object byte[] 0 }

    $head = "HTTP/1.1 $Code $reason`r`n" +
            "Content-Type: $ContentType`r`n" +
            "Content-Length: $($Body.Length)`r`n" +
            "Access-Control-Allow-Origin: *`r`n" +
            "Access-Control-Allow-Methods: GET, POST, PUT, OPTIONS`r`n" +
            "Access-Control-Allow-Headers: Content-Type`r`n" +
            "Access-Control-Max-Age: 86400`r`n" +
            "Cache-Control: no-store`r`n" +
            "Connection: close`r`n`r`n"

    $hb = [System.Text.Encoding]::ASCII.GetBytes($head)
    try {
        $Stream.Write($hb, 0, $hb.Length)
        if ($Body.Length -gt 0) { $Stream.Write($Body, 0, $Body.Length) }
        $Stream.Flush()
    } catch { }
}

function Send-Json {
    param($Stream, [int]$Code, $Obj)
    $json = $Obj | ConvertTo-Json -Depth 30 -Compress
    Write-Response -Stream $Stream -Code $Code -ContentType 'application/json; charset=utf-8' -Body ($Utf8.GetBytes($json))
}

function Read-Request {
    param($Stream)

    $ms   = New-Object System.IO.MemoryStream
    $buf  = New-Object byte[] 16384
    $headEnd = -1
    $contentLength = 0

    while ($true) {
        $n = 0
        try { $n = $Stream.Read($buf, 0, $buf.Length) } catch { break }
        if ($n -le 0) { break }
        $ms.Write($buf, 0, $n)

        if ($headEnd -lt 0) {
            $arr = $ms.ToArray()
            for ($i = 0; $i -le $arr.Length - 4; $i++) {
                if ($arr[$i] -eq 13 -and $arr[$i + 1] -eq 10 -and $arr[$i + 2] -eq 13 -and $arr[$i + 3] -eq 10) {
                    $headEnd = $i + 4
                    break
                }
            }
            if ($headEnd -ge 0) {
                $head = [System.Text.Encoding]::ASCII.GetString($arr, 0, $headEnd)
                if ($head -match '(?im)^Content-Length:\s*(\d+)') { $contentLength = [int]$Matches[1] }
            }
        }
        if ($headEnd -ge 0 -and $ms.Length -ge ($headEnd + $contentLength)) { break }
        if ($ms.Length -gt 12MB) { break }
    }

    $all = $ms.ToArray()
    if ($headEnd -lt 0 -or $all.Length -lt 4) { return $null }

    $headText = [System.Text.Encoding]::ASCII.GetString($all, 0, $headEnd)
    $lines = $headText -split "`r`n"
    $parts = $lines[0] -split ' '
    if ($parts.Length -lt 2) { return $null }

    $bodyText = ''
    if ($contentLength -gt 0 -and $all.Length -ge ($headEnd + $contentLength)) {
        $bodyText = $Utf8.GetString($all, $headEnd, $contentLength)
    }

    return @{
        Method = $parts[0].ToUpper()
        Path   = ($parts[1] -split '\?')[0]
        Body   = $bodyText
    }
}

function Read-StateJson {
    if (-not (Test-Path $StatePath)) { return 'null' }
    try { return [System.IO.File]::ReadAllText($StatePath, $Utf8) } catch { return 'null' }
}

function Write-StateAtomic {
    param([string]$Json)

    if (Test-Path $StatePath) {
        try { Copy-Item -LiteralPath $StatePath -Destination $BakPath -Force } catch { }
    }
    $tmp = "$StatePath.tmp"
    [System.IO.File]::WriteAllText($tmp, $Json, $Utf8NoBom)
    Move-Item -LiteralPath $tmp -Destination $StatePath -Force
}

# ---------------- 启动 ----------------
$listener = $null
try {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
    $listener.Start()
} catch {
    Write-Host ""
    Write-Host "  [提示] 端口 $Port 已被占用，可能服务已经在运行。" -ForegroundColor Yellow
    Write-Host "         直接打开 http://127.0.0.1:$Port/ 即可。"
    Start-Sleep -Seconds 3
    exit 0
}

$foundPage = Get-PagePath
Write-Host ("=" * 56)
Write-Host " 片单工具 已启动（PowerShell 版，无需 Python）"
Write-Host " 地址 : http://127.0.0.1:$Port/"
Write-Host " 页面 : $(if ($foundPage) { $foundPage } else { '没找到 .html 文件！' })"
Write-Host " 数据 : $StatePath"
Write-Host " 关闭这个窗口即停止服务"
Write-Host ("=" * 56)

while ($true) {
    $client = $null
    try {
        $client = $listener.AcceptTcpClient()
        $client.ReceiveTimeout = 10000
        $stream = $client.GetStream()
        $stream.ReadTimeout = 10000

        $req = Read-Request -Stream $stream
        if ($null -eq $req) { $client.Close(); continue }

        $method = $req.Method
        $path   = $req.Path

        if ($method -eq 'OPTIONS') {
            Write-Response -Stream $stream -Code 204 -ContentType 'text/plain' -Body $null
        }
        elseif ($path -eq '/api/health') {
            $exists = Test-Path $StatePath
            $savedAt = $null
            if ($exists) { $savedAt = (Get-Item $StatePath).LastWriteTime.ToString('s') }
            Send-Json -Stream $stream -Code 200 -Obj ([ordered]@{
                ok        = $true
                service   = 'film'
                engine    = 'powershell'
                data_dir  = $DataDir
                has_state = $exists
                saved_at  = $savedAt
            })
        }
        elseif ($path -eq '/api/state' -and $method -eq 'GET') {
            $raw = Read-StateJson
            $payload = '{"ok":true,"state":' + $raw + '}'
            Write-Response -Stream $stream -Code 200 -ContentType 'application/json; charset=utf-8' -Body ($Utf8.GetBytes($payload))
        }
        elseif ($path -eq '/api/state' -and ($method -eq 'PUT' -or $method -eq 'POST')) {
            $bad = $false
            if ([string]::IsNullOrWhiteSpace($req.Body)) { $bad = $true }
            if (-not $bad) {
                try { $obj = $req.Body | ConvertFrom-Json } catch { $bad = $true }
                if (-not $bad -and ($null -eq $obj -or $null -eq $obj.themes)) { $bad = $true }
            }
            if ($bad) {
                Send-Json -Stream $stream -Code 400 -Obj ([ordered]@{ ok = $false; error = 'invalid state' })
            } else {
                try {
                    Write-StateAtomic -Json $req.Body
                    Send-Json -Stream $stream -Code 200 -Obj ([ordered]@{ ok = $true; bytes = $req.Body.Length; path = $StatePath })
                } catch {
                    Send-Json -Stream $stream -Code 500 -Obj ([ordered]@{ ok = $false; error = "$($_.Exception.Message)" })
                }
            }
        }
        elseif ($path -eq '/' -or $path -eq '/index.html' -or $path -eq '/app.html' -or $path -eq '/片单工具.html') {
            $pagePath = Get-PagePath
            if ($pagePath) {
                $bytes = [System.IO.File]::ReadAllBytes($pagePath)
                Write-Response -Stream $stream -Code 200 -ContentType 'text/html; charset=utf-8' -Body $bytes
            } else {
                $msg = "这个文件夹里没有 .html 文件。请把 index.html（或任意 .html）和 server.ps1 放在同一个文件夹里。"
                Write-Response -Stream $stream -Code 404 -ContentType 'text/plain; charset=utf-8' -Body ($Utf8.GetBytes($msg))
            }
        }
        elseif ($path -eq '/favicon.ico') {
            Write-Response -Stream $stream -Code 204 -ContentType 'text/plain' -Body $null
        }
        else {
            Send-Json -Stream $stream -Code 404 -Obj ([ordered]@{ ok = $false; error = 'not found' })
        }

        $client.Close()
    }
    catch {
        if ($client) { try { $client.Close() } catch { } }
        Start-Sleep -Milliseconds 20
    }
}
