# start-claude.ps1
# One-command launcher for Claude Code behind a corporate proxy.
#   1) Start px if it is not running (configure NTLM upstream if needed)
#   2) Verify px is listening
#   3) Trust Windows root CAs in Node (for SSL-inspection tools like ESET). Does NOT disable verification.
#   4) Point proxy env vars at px and launch claude
#
# Requirements: px installed / Node.js + Claude Code installed
#   (on Bun-crash environments, pin the Node-based build: npm i -g @anthropic-ai/claude-code@2.1.112)
# Usage (execution policy may be locked down, so use Bypass):
#   powershell -ExecutionPolicy Bypass -File "$HOME\Desktop\start-claude.ps1"

param(
    [string]$Proxy  = "192.168.221.3:8080",   # upstream corporate proxy (px server)
    [string]$PxDir  = "$HOME\Desktop\PX",      # folder that contains px.exe
    [int]   $Port   = 3128,                     # px listen port
    [switch]$SkipCert                           # skip the certificate step
)

$ErrorActionPreference = "Stop"
$pxUrl  = "http://127.0.0.1:$Port"
$pxExe  = Join-Path $PxDir "px.exe"
$pxwExe = Join-Path $PxDir "pxw.exe"
$ini    = Join-Path $PxDir "px.ini"

# 1. Start px if not running
if (-not (Get-Process px -ErrorAction SilentlyContinue)) {
    if (-not (Test-Path $pxExe)) { throw "px.exe not found: $pxExe (pass -PxDir to point at px)" }

    $needConfig = $true
    if (Test-Path $ini) {
        $c = Get-Content $ini -Raw
        if ($c -match ("server\s*=\s*" + [regex]::Escape($Proxy)) -and $c -match "auth\s*=\s*NTLM") { $needConfig = $false }
    }
    if ($needConfig) {
        Write-Host "Configuring px (proxy=$Proxy, auth=NTLM)..." -ForegroundColor Cyan
        & $pxExe --proxy=$Proxy --auth=NTLM --save | Out-Null
    }

    $exe = if (Test-Path $pxwExe) { $pxwExe } else { $pxExe }
    Write-Host "Starting px: $exe" -ForegroundColor Cyan
    Start-Process -FilePath $exe -WorkingDirectory $PxDir
    Start-Sleep -Seconds 2
} else {
    Write-Host "px is already running." -ForegroundColor Green
}

# 2. Verify px is listening
$listening = $false
for ($i = 0; $i -lt 6; $i++) {
    if (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue) { $listening = $true; break }
    Start-Sleep -Seconds 1
}
if ($listening) { Write-Host "px is listening on 127.0.0.1:$Port" -ForegroundColor Green }
else { Write-Warning "px is not listening on port $Port. Check px." }

# 3. Certificate handling for SSL inspection (ESET etc). Does NOT disable verification.
if (-not $SkipCert) {
    $caFile = Join-Path ([Environment]::GetFolderPath('Desktop')) "corp-ca-bundle.pem"
    Write-Host "Writing root CA bundle: $caFile" -ForegroundColor Cyan
    (Get-ChildItem Cert:\LocalMachine\Root | ForEach-Object {
        "-----BEGIN CERTIFICATE-----`n" + [Convert]::ToBase64String($_.RawData, 'InsertLineBreaks') + "`n-----END CERTIFICATE-----"
    }) | Set-Content -Encoding ascii $caFile
    $env:NODE_EXTRA_CA_CERTS = $caFile
}

# 4. Point env vars at px and launch Claude Code
$env:HTTP_PROXY  = $pxUrl
$env:HTTPS_PROXY = $pxUrl
Write-Host "Starting Claude Code (proxy=$pxUrl)" -ForegroundColor Green
claude
