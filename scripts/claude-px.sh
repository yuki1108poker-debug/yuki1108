#!/usr/bin/env bash
# px（px-proxy）経由で Claude Code を起動する（macOS / Linux）。
# 事前に別ターミナルで `px` を起動しておくこと（既定 127.0.0.1:3128）。
set -euo pipefail

# px の待受アドレス。px を別ポートにしている場合はここを変更。
PX_ADDR="${PX_ADDR:-http://127.0.0.1:3128}"

export HTTP_PROXY="$PX_ADDR"
export HTTPS_PROXY="$PX_ADDR"
export http_proxy="$PX_ADDR"
export https_proxy="$PX_ADDR"

# 社内が SSL 検査をしている場合は、社内ルートCA(PEM)のパスを設定する。
# 例: export CORP_CA=/path/to/corp-root-ca.pem ./scripts/claude-px.sh
if [ -n "${CORP_CA:-}" ]; then
  export NODE_EXTRA_CA_CERTS="$CORP_CA"
fi

exec claude "$@"
