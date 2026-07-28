# yuki1108

社内ネットワーク（プロキシ）環境で、ローカルに **Claude Code** をインストールして使うための手順です。

> **結論から**: 社内プロキシは **接続先ドメインごとに認証要否が違う**ことがあります。
> 判定は必ず **実際に使う宛先（`api.anthropic.com`）** で行ってください。
> （例: npm レジストリは認証不要でも、`api.anthropic.com` は NTLM 認証必須、というケースが実在します）
>
> - 宛先が **認証不要** なら **px は不要**、プロキシに直結が最短。
> - 宛先が **認証必要（407）** なら **px（px-proxy）を `--auth=NTLM` で挟む**。← 本リポジトリのセットアップはこれで解決。
>   Node/Claude Code は NTLM を自前でできないため、px が Windows 資格情報で認証を肩代わりします。

---

## 0. 前提

- Windows + PowerShell
- 管理者権限は不要（すべてユーザー範囲で完結）

---

## 1. Node.js を入れる

PowerShell で確認:

```powershell
node -v
npm -v
```

「認識されません」なら未インストール。ブラウザで <https://nodejs.org/> から **LTS 版の Windows Installer (.msi)**
を入れて、**PowerShell を開き直して**再確認する（ブラウザは社内プロキシを自動で通る）。

### npm が「スクリプトの実行が無効」で止まる場合

`npm.ps1 を読み込むことができません`（`PSSecurityException`）が出たら、実行ポリシーをユーザー範囲で緩める:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned   # 確認は Y
```

（会社ポリシーで拒否される場合は `npm` の代わりに `npm.cmd` を使う）

---

## 2. 社内プロキシのアドレスを調べる

```powershell
Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" |
  Select-Object ProxyEnable, ProxyServer, AutoConfigURL
```

- `ProxyServer` に `<ホスト>:<ポート>`（例 `192.0.2.1:8080`）が出れば、それが社内プロキシ
- `AutoConfigURL`（PAC ファイル）が出る場合は、PAC が指す実プロキシを使う

以降、この値を `<PROXY>` と書きます（例: `http://192.0.2.1:8080`）。

---

## 3. プロキシが「認証必要」か判定する

**必ず本命の宛先 `api.anthropic.com` で確認する**（ドメインごとに要否が違うため）:

```powershell
curl.exe --ssl-no-revoke -x <PROXY> https://api.anthropic.com -sS -o NUL -w "%{http_code}`n"
```

- **`200`/`404` など** → 認証不要。→ **4A（px 不要・直結）** へ
- **`407`**（Proxy Authentication Required）→ 認証必要。→ **4B（px 経由）** へ

認証必要（407）だった場合、この PC が NTLM シングルサインオンでプロキシを通れるかを確認しておく
（`--proxy-user :` は現在の Windows ユーザーの資格情報を使う指定）:

```powershell
curl.exe --ssl-no-revoke --proxy-ntlm --proxy-user : -x <PROXY> https://api.anthropic.com -sS -o NUL -w "%{http_code}`n"
```

- ここで `200`/`404` が返れば NTLM SSO は通る → **4B の `--auth=NTLM` で px を設定すれば解決**。

---

## 4A. 認証不要の場合（推奨・px 不要）

npm をプロキシに直結して Claude Code を入れる:

```powershell
npm config set proxy       <PROXY>
npm config set https-proxy <PROXY>
npm install -g @anthropic-ai/claude-code
```

実行時もプロキシを使うので、環境変数を設定して起動する（下記「6. 起動」）。

---

## 4B. 認証必要の場合（px を挟む）

px が認証を肩代わりする。**`--auth=NTLM` を必ず付ける**のが要点
（`auth` 未指定=ANY だと認証がうまく噛み合わず **502** になることがある。認証方式を NTLM に固定する）:

```powershell
Get-Process px*,pxw* -ErrorAction SilentlyContinue | Stop-Process -Force
cd "$HOME\Desktop\PX"
.\px.exe --proxy=<ホスト:ポート> --auth=NTLM --save   # 例: --proxy=192.0.2.1:8080
.\px.exe                                              # この窓は開いたまま（設定は px.ini に保存済み）
```

> 上流プロキシが Negotiate/Kerberos の場合は `--auth=NEGOTIATE` など、`Proxy-Authenticate` が返す方式に合わせる。

別の窓で、px 経由で本命に出られるか確認してから npm を入れる:

```powershell
curl.exe --ssl-no-revoke -x http://127.0.0.1:3128 https://api.anthropic.com -sS -o NUL -w "%{http_code}`n"  # 407/502 以外ならOK
npm config set proxy       http://127.0.0.1:3128
npm config set https-proxy http://127.0.0.1:3128
npm install -g @anthropic-ai/claude-code
```

> **ワンコマンド起動**: `scripts/start-claude.ps1` を使うと「px 起動確認 → 無ければ設定して起動 →
> SSL検査(ESET等)向け証明書対策 → 環境変数を px に向けて claude 起動」まで自動化できる。
> ```powershell
> .\scripts\start-claude.ps1                      # 既定（proxy=192.168.221.3:8080）
> .\scripts\start-claude.ps1 -Proxy 10.0.0.1:8080 # プロキシ/場所を変える場合
> ```
> 単純に環境変数だけ設定する軽量版は `scripts/claude-px.ps1` / `scripts/claude-px.sh`。
>
> **px のデバッグ**: `.\px.exe --debug` で前面起動すると、各リクエストの上流とのやり取り
> （`CONNECT`、`407`、`Proxy-Authenticate` の方式、認証結果）が見えて原因特定が速い。

---

## 5. SSL インスペクション（証明書差し替え）がある場合のみ

`npm install` が `self-signed certificate` / `unable to get local issuer certificate` で失敗する場合、
社内が TLS を検査しています。Windows のルート証明書をまとめて PEM 化し、npm に信頼させる:

```powershell
$out = "$HOME\Desktop\corp-ca-bundle.pem"
Get-ChildItem Cert:\LocalMachine\Root | ForEach-Object {
  $b = [Convert]::ToBase64String($_.RawData, 'InsertLineBreaks')
  "-----BEGIN CERTIFICATE-----`n$b`n-----END CERTIFICATE-----"
} | Set-Content -Encoding ascii $out
npm config set cafile "$out"
$env:NODE_EXTRA_CA_CERTS = "$out"
```

> 検証を無効化する `strict-ssl false` / `NODE_TLS_REJECT_UNAUTHORIZED=0` は通信が保護されなくなるため
> 常用しないこと（切り分け目的の一時使用のみ）。

---

## 6. 起動と認証

```powershell
$env:HTTP_PROXY  = <PROXY>     # 直結なら社内プロキシ、px経由なら http://127.0.0.1:3128
$env:HTTPS_PROXY = <PROXY>
claude --version               # 例: 2.1.216 (Claude Code)
claude                         # 初回は認証（ログイン or API キー）
```

`claude` が「認識されません」の場合は PATH 反映待ち。PowerShell を開き直す
（bin は `%APPDATA%\npm` = `C:\Users\<ユーザー>\AppData\Roaming\npm`）。

### 毎回プロキシを打たなくて済むように（任意）

```powershell
[Environment]::SetEnvironmentVariable("HTTP_PROXY",  "<PROXY>", "User")
[Environment]::SetEnvironmentVariable("HTTPS_PROXY", "<PROXY>", "User")
```

---

## トラブルシューティング

| 症状 | 原因 / 対処 |
| --- | --- |
| `claude` が「認識されません」 | 未インストール、または PATH 未反映。`npm list -g @anthropic-ai/claude-code` で確認し、無ければ再インストール。あれば PowerShell を開き直す。 |
| `npm.ps1 を読み込めない`（PSSecurityException） | 実行ポリシー。`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`、または `npm.cmd` を使う。 |
| `ECONNREFUSED 127.0.0.1:3128` | px を使う設定なのに px が起動していない。px を起動する。**そもそも認証不要なら px をやめて直結（4A）にする。** |
| `ECONNRESET` / `failed to receive handshake` | px の上流プロキシが未設定で外に中継できていない。`--proxy=` を設定（4B）。**認証不要なら直結（4A）が確実。** |
| px 経由で全部 `502 (CONNECT tunnel failed)` | px の認証方式が噛み合っていない。`--auth=NTLM`（環境に合わせ NEGOTIATE 等）を付けて px を再起動（4B）。`.\px.exe --debug` でログ確認。 |
| px 経由で `ERR_SOCKET_CLOSED` / 直結で `407` | その宛先はプロキシ認証が必要。直結ではなく px 経由（4B）にする。判定は 3 章のとおり **api.anthropic.com** で行う。 |
| `CRYPT_E_REVOCATION_OFFLINE` | curl（schannel）の失効確認が外に出られない。切り分け時は `curl.exe --ssl-no-revoke` を使う（npm/Node は失効確認しないので通常影響なし）。 |
| 証明書エラー（self-signed 等） | 社内 SSL インスペクション。手順 5 で CA を信頼させる。 |
| `postinstall`/`allow-scripts` の警告 | 通常は動作に支障なし。起動時に部品不足が出たら `npm approve-scripts @anthropic-ai/claude-code` → `npm rebuild -g @anthropic-ai/claude-code`。 |
| 起動直後に `Bun has crashed` / `Segmentation fault` | 実行エンジン Bun が常駐ソフトのDLL注入で落ちている。特に **VMware Horizon 等の VDI**（`ctiuser.dll` が注入される）で発生。→ 下記「VDI で Bun がクラッシュする場合」。 |

---

## VDI（VMware Horizon 等）で Bun がクラッシュする場合

Claude Code 2.x は実行エンジンに **Bun** を使う（`bin/claude.exe` は 265MB の Bun コンパイル済みバイナリ）。
VMware Horizon などの VDI では、エージェントの DLL（例 `C:\Windows\System32\ctiuser.dll`, 提供元 VMware）が
プロセスに注入され、**Bun が起動直後に Segmentation fault で落ちる**。`claude -p "..."`（ヘッドレス）でも落ちる。

診断:

```powershell
# クラッシュログに出る DLL の提供元を確認
Get-ChildItem -Path "C:\Windows" -Recurse -Filter ctiuser.dll -Force -ErrorAction SilentlyContinue |
  Select-Object FullName, @{n='会社';e={$_.VersionInfo.CompanyName}}
```

### 回避策: Node ベースの版に固定する（Bun を使わない）

この環境でも **Node 自体は正常に動く**（`node -v` / `npm install` は落ちない）。Claude Code は
**2.1.112 以前が Node ベース（`bin` = `cli.js`）**、2.1.114 以降が Bun バイナリ。最後の Node 版に固定すれば回避できる。

```powershell
npm install -g @anthropic-ai/claude-code@2.1.112     # 最後の Node ベース版
[Environment]::SetEnvironmentVariable("DISABLE_AUTOUPDATER","1","User")  # Bun版へ戻らないよう自動更新を無効化
```

> ⚠️ その後 `@latest` に更新すると Bun 版に戻って再発する。更新は 2.1.112 以下にとどめる。

### 他の選択肢

- **IT に依頼**: VDI（VMware Horizon）側で `claude.exe` / `node.exe` への DLL 注入を除外してもらう（最新の Bun 版を使いたい場合）。
- **Web 版**: <https://claude.ai/code>（設定不要。ローカルではないが即利用可）。

---

## 認証プロキシが多接続で 407 になる場合（i-FILTER 等・IT 対応必須）

px の NTLM が単発リクエスト（`curl`）では通る（`200`/`401`/`404`）のに、Claude Code のチャットだけ
**`407` = 認証に失敗**（例: Digital Arts i-FILTER のブロックページ）になることがある。

原因: **認証プロキシが負荷分散（複数ノード）構成**だと、NTLM は「接続ごと・ノードごと」に認証が必要なため、
Claude Code が張る多数の同時接続の一部が別ノードに振られて認証に失敗する（ブロック応答の IP がリクエストごとに
変動するのが目印。例 `172.17.10.214` / `172.17.12.119`）。**これはクライアント側では解決できない。**

対処: **IT に依頼**して、以下を i-FILTER 等の **プロキシ認証の対象外（バイパス/ホワイトリスト）** にしてもらう。

- `api.anthropic.com` / `claude.ai` / `console.anthropic.com`

暫定: Web 版 <https://claude.ai/code> を使う（プロキシ認証の影響を受けない）。

---

- プロジェクトの共有メモリは [`CLAUDE.md`](./CLAUDE.md)（Claude Code が自動で読み込む）
- 公式ドキュメント: <https://code.claude.com/docs/>
