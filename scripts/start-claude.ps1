# start-claude.ps1
# 社内プロキシ環境で、ローカルの Claude Code をワンコマンドで起動する最終版。
#   1) px が動いているか確認 → 動いていなければ設定して起動
#   2) px の待受を確認
#   3) SSL 検査環境（ESET 等）向けに、Windows のルート証明書を Node に信頼させる（検証は無効化しない）
#   4) 環境変数を px に向けて claude を起動
#
# 前提: px 導入済み / Node.js + Claude Code 導入済み（Bun クラッシュ環境では Node 版 2.1.112 を推奨）
# 使い方: PowerShell で  .\scripts\start-claude.ps1
#         社内プロキシや px の場所が違う場合は引数で上書き:
#         .\scripts\start-claude.ps1 -Proxy 10.0.0.1:8080 -PxDir "C:\Tools\px"

param(
    [string]$Proxy  = "192.168.221.3:8080",   # px の上流（社内プロキシ）
    [string]$PxDir  = "$HOME\Desktop\PX",      # px 本体の場所
    [int]   $Port   = 3128,                     # px の待受ポート
    [switch]$SkipCert                           # 証明書対策をスキップしたいとき
)

$ErrorActionPreference = "Stop"
$pxUrl  = "http://127.0.0.1:$Port"
$pxExe  = Join-Path $PxDir "px.exe"
$pxwExe = Join-Path $PxDir "pxw.exe"
$ini    = Join-Path $PxDir "px.ini"

# --- 1. px を起動（動いていなければ） ---
if (-not (Get-Process px -ErrorAction SilentlyContinue)) {
    if (-not (Test-Path $pxExe)) {
        throw "px.exe が見つかりません: $pxExe （-PxDir で px の場所を指定してください）"
    }

    # px.ini に「上流プロキシ + NTLM 認証」が無ければ設定して保存
    $needConfig = $true
    if (Test-Path $ini) {
        $c = Get-Content $ini -Raw
        if ($c -match ("server\s*=\s*" + [regex]::Escape($Proxy)) -and $c -match "auth\s*=\s*NTLM") {
            $needConfig = $false
        }
    }
    if ($needConfig) {
        Write-Host "px を設定します (proxy=$Proxy, auth=NTLM)..." -ForegroundColor Cyan
        & $pxExe --proxy=$Proxy --auth=NTLM --save | Out-Null
    }

    # 窓なし版(pxw.exe)があればそれで、無ければ px.exe を別プロセスで起動
    $exe = if (Test-Path $pxwExe) { $pxwExe } else { $pxExe }
    Write-Host "px を起動します: $exe" -ForegroundColor Cyan
    Start-Process -FilePath $exe -WorkingDirectory $PxDir
    Start-Sleep -Seconds 2
} else {
    Write-Host "px は既に起動しています。" -ForegroundColor Green
}

# --- 2. px の待受を確認 ---
$listening = $false
for ($i = 0; $i -lt 6; $i++) {
    if (Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue) {
        $listening = $true; break
    }
    Start-Sleep -Seconds 1
}
if ($listening) {
    Write-Host "px は 127.0.0.1:$Port で待受中です。" -ForegroundColor Green
} else {
    Write-Warning "px がポート $Port で待受を確認できません。px の状態を確認してください。"
}

# --- 3. 証明書対策（ESET 等の SSL 検査環境向け。検証は無効化しない） ---
if (-not $SkipCert) {
    $caFile = Join-Path ([Environment]::GetFolderPath('Desktop')) "corp-ca-bundle.pem"
    Write-Host "ルート証明書バンドルを書き出します: $caFile" -ForegroundColor Cyan
    (Get-ChildItem Cert:\LocalMachine\Root | ForEach-Object {
        "-----BEGIN CERTIFICATE-----`n" +
        [Convert]::ToBase64String($_.RawData, 'InsertLineBreaks') +
        "`n-----END CERTIFICATE-----"
    }) | Set-Content -Encoding ascii $caFile
    $env:NODE_EXTRA_CA_CERTS = $caFile
}

# --- 4. 環境変数を px に向けて Claude Code 起動 ---
$env:HTTP_PROXY  = $pxUrl
$env:HTTPS_PROXY = $pxUrl
Write-Host "Claude Code を起動します (proxy=$pxUrl)" -ForegroundColor Green
claude
