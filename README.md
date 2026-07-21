# yuki1108

社内ネットワーク（認証プロキシ）が原因でローカルの **Claude Code** が接続できない問題を、
**px（px-proxy）** 経由にすることで解消し、ローカルで Claude Code を使えるようにするセットアップです。

## 仕組み

```
Claude Code  ──HTTPS_PROXY──▶  px (127.0.0.1:3128)  ──認証付き──▶  社内プロキシ  ──▶  インターネット
```

Claude Code は環境変数 `HTTPS_PROXY` を見て通信します。これを px の待受アドレスに向ければ、
px が社内プロキシの認証（NTLM / Kerberos など）を肩代わりして通してくれます。

## 前提

- Claude Code がインストール済み（未の場合は下記「補足」参照）
- px（px-proxy）がインストール済み

## 1. px を起動する

px を起動すると既定で `127.0.0.1:3128` で待ち受けます。

```bash
px            # 別ターミナルで起動したままにする
```

> 初回は上流の社内プロキシを設定します。Windows のプロキシ設定を自動検出できることが多いですが、
> うまくいかない場合は `px --proxy=<社内プロキシ:ポート> --save` で `px.ini` に保存できます。

## 2. Claude Code を px 経由で起動する

### macOS / Linux

```bash
export HTTP_PROXY="http://127.0.0.1:3128"
export HTTPS_PROXY="http://127.0.0.1:3128"
# 社内が SSL 検査をしている場合のみ（下記参照）
# export NODE_EXTRA_CA_CERTS="/path/to/corp-root-ca.pem"
claude
```

同梱スクリプトでまとめて実行:

```bash
./scripts/claude-px.sh
```

### Windows（PowerShell）

```powershell
$env:HTTP_PROXY  = "http://127.0.0.1:3128"
$env:HTTPS_PROXY = "http://127.0.0.1:3128"
# 社内が SSL 検査をしている場合のみ
# $env:NODE_EXTRA_CA_CERTS = "C:\certs\corp-root-ca.pem"
claude
```

同梱スクリプトでまとめて実行:

```powershell
./scripts/claude-px.ps1
```

## 3. SSL 検査（証明書差し替え）対策

px を通しても次のようなエラーが出る場合、社内プロキシが TLS を検査していて、
Claude Code（Node）が社内の証明書を信頼していないのが原因です。

```
Error: self-signed certificate in certificate chain
Error: unable to get local issuer certificate
```

対処: 社内のルートCA証明書（PEM 形式）を用意し、`NODE_EXTRA_CA_CERTS` にパスを指定します。

- Windows: 証明書ストアの社内ルートCAを「Base-64 (.cer/.pem)」でエクスポート
- そのパスを上記スクリプト／環境変数の `NODE_EXTRA_CA_CERTS` に設定

> 注意: `NODE_TLS_REJECT_UNAUTHORIZED=0` で検証を無効化する方法は、通信が保護されなくなるため
> 使わないでください。必ず CA 証明書を追加する方法で解決します。

## 4. うまくいかないときの確認

```bash
# px 経由で外に出られるか（200 が返れば OK）
curl -x http://127.0.0.1:3128 https://api.anthropic.com -sS -o /dev/null -w "%{http_code}\n"
```

- `curl` が通るのに `claude` が失敗する → 証明書（手順3）を確認
- `curl` も失敗する → px の上流プロキシ設定（手順1）を確認

## 補足: Windows でゼロからインストールする手順（社内プロキシ環境）

`claude` が「認識されません」と出る場合はまだ未インストールです。次の順で入れます。

### ① Node.js を入れる

`node -v` / `npm -v` が「認識されません」なら Node.js が未インストールです。

1. ブラウザで <https://nodejs.org/> を開く（ブラウザは社内プロキシを自動で通る）
2. **LTS 版**の **Windows Installer (.msi) 64-bit** をダウンロードして実行（既定のままでOK）
3. **PowerShell を開き直して** `node -v` / `npm -v` が表示されることを確認

### ② npm を px 経由に向ける

```powershell
npm config set proxy       http://127.0.0.1:3128
npm config set https-proxy http://127.0.0.1:3128
# SSL 検査環境なら社内ルートCA(PEM)も指定
# npm config set cafile "C:\certs\corp-root-ca.pem"
```

### ③ Claude Code を入れる

```powershell
npm install -g @anthropic-ai/claude-code
```

インストール後は PowerShell を開き直し、本書「2. Claude Code を px 経由で起動する」に進む。

### 参考: macOS / Linux のネイティブインストーラ

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

---

- プロジェクトの共有メモリは [`CLAUDE.md`](./CLAUDE.md)（Claude Code が自動で読み込みます）
- 公式ドキュメント: <https://code.claude.com/docs/>
