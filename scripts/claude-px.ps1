# px（px-proxy）経由で Claude Code を起動する（Windows / PowerShell）。
# 事前に別ウィンドウで `px` を起動しておくこと（既定 127.0.0.1:3128）。

# プロキシの待受アドレス。既定は px（127.0.0.1:3128）。
# 認証不要な社内プロキシに直結する場合は PX_ADDR にそのアドレスを指定する。
#   例: $env:PX_ADDR="http://192.0.2.1:8080"; ./scripts/claude-px.ps1
$PxAddr = if ($env:PX_ADDR) { $env:PX_ADDR } else { "http://127.0.0.1:3128" }

$env:HTTP_PROXY  = $PxAddr
$env:HTTPS_PROXY = $PxAddr

# 社内が SSL 検査をしている場合は、社内ルートCA(PEM)のパスを設定する。
# 例: $env:CORP_CA = "C:\certs\corp-root-ca.pem"; ./scripts/claude-px.ps1
if ($env:CORP_CA) {
    $env:NODE_EXTRA_CA_CERTS = $env:CORP_CA
}

claude @args
