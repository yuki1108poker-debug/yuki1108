# start-claude.ps1 - FINAL
# One-shot launcher for Claude Code behind an NTLM corporate proxy (i-FILTER etc).
#
# What it does:
#   1) Start px (NTLM auth to upstream) if not already running
#   2) Wait until px is listening
#   3) Point the WINDOWS SYSTEM PROXY at px  <-- the decisive fix:
#      some of Claude Code's connections read the system proxy directly and
#      cannot speak NTLM, so they got raw 407 pages unless px is in that path too
#   4) Build a CA bundle from ALL cert stores (Root+CA, machine+user) and set
#      NODE_EXTRA_CA_CERTS so SSL-inspected TLS is trusted (no verification disabled)
#   5) Set proxy env vars, disable autoupdater (stay on Node-based build), launch claude
#
# Run:  powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\Desktop\start-claude.ps1"
# Tip:  create a .bat next to it for double-click launch (see repo README)
# Revert system proxy if you stop using px:
#   Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -Value "<original proxy:port>"

param(
    [string]$Proxy   = "192.168.221.3:8080",   # upstream corporate proxy
    [string]$PxDir   = "$HOME\Desktop\PX",      # folder containing px.exe / pxw.exe
    [int]   $Port    = 3128,                     # px listen port
    [string]$WorkDir = "$HOME"                   # folder claude opens in
)

$ErrorActionPreference = "Stop"
$pxUrl = "http://127.0.0.1:$Port"

# 1. Start px if not running (px.exe visible, pxw.exe windowless - prefer pxw)
if (-not (Get-Process px,pxw -ErrorAction SilentlyContinue)) {
    $pxExe  = Join-Path $PxDir "px.exe"
    $pxwExe = Join-Path $PxDir "pxw.exe"
    if (-not (Test-Path $pxExe)) { throw "px.exe not found: $pxExe (pass -PxDir)" }

    $ini = Join-Path $PxDir "px.ini"
    $needConfig = $true
    if (Test-Path $ini) {
        $c = Get-Content $ini -Raw
        if ($c -match [regex]::Escape($Proxy) -and $c -match "auth\s*=\s*NTLM") { $needConfig = $false }
    }
    if ($needConfig) {
        Write-Host "Configuring px (proxy=$Proxy, auth=NTLM)..." -ForegroundColor Cyan
        & $pxExe --proxy=$Proxy --auth=NTLM --save | Out-Null
    }

    $exe = if (Test-Path $pxwExe) { $pxwExe } else { $pxExe }
    Write-Host "Starting px: $exe" -ForegroundColor Cyan
    Start-Process -FilePath $exe -WorkingDirectory $PxDir -WindowStyle Minimized
}

# 2. Wait for px to listen
$ok = $false
for ($i = 0; $i -lt 10; $i++) {
    if (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue) { $ok = $true; break }
    Start-Sleep -Seconds 1
}
if ($ok) { Write-Host "px is listening on 127.0.0.1:$Port" -ForegroundColor Green }
else     { Write-Warning "px is not listening on port $Port - claude may fail" }

# 3. Point Windows system proxy at px (KEY FIX - some claude traffic uses this path)
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -Value "127.0.0.1:$Port"
Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 1
Write-Host "Windows system proxy -> 127.0.0.1:$Port" -ForegroundColor Green

# 4. CA bundle from ALL stores (corporate CA may live outside LocalMachine\Root)
$caFile = Join-Path $env:LOCALAPPDATA "claude-px-ca.pem"
Get-ChildItem Cert:\LocalMachine\Root, Cert:\LocalMachine\CA, Cert:\CurrentUser\Root, Cert:\CurrentUser\CA -ErrorAction SilentlyContinue |
  Sort-Object Thumbprint -Unique | ForEach-Object {
    "-----BEGIN CERTIFICATE-----`n" + [Convert]::ToBase64String($_.RawData, 'InsertLineBreaks') + "`n-----END CERTIFICATE-----"
  } | Set-Content -Encoding ascii $caFile
$env:NODE_EXTRA_CA_CERTS = $caFile

# 5. Env vars and launch
$env:HTTP_PROXY  = $pxUrl
$env:HTTPS_PROXY = $pxUrl
$env:DISABLE_AUTOUPDATER = "1"   # stay on Node-based build (Bun crashes on this VDI)
Set-Location $WorkDir
Write-Host "Starting Claude Code (proxy=$pxUrl, workdir=$WorkDir)" -ForegroundColor Green
claude
