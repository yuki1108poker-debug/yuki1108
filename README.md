# yuki1108

このリポジトリを **ローカル環境で Claude Code から使う** ためのセットアップです。

## 1. 前提

- [Node.js](https://nodejs.org/) 18 以上（ネイティブインストーラを使う場合は不要）
- Claude の認証情報のどちらか
  - Claude の subscription（Pro / Max）でログイン、または
  - [Anthropic Console](https://console.anthropic.com/) の API キー

## 2. Claude Code をインストール

### 方法A: ネイティブインストーラ（推奨）

macOS / Linux:

```bash
curl -fsSL https://claude.ai/install.sh | bash
```

Windows（PowerShell）:

```powershell
irm https://claude.ai/install.ps1 | iex
```

### 方法B: npm でグローバルインストール

```bash
npm install -g @anthropic-ai/claude-code
```

### 方法C: インストールせずランナーで実行（px = ランナー の場合）

グローバルに入れず、都度最新を実行したいとき:

```bash
npx @anthropic-ai/claude-code
```

## 3. このリポジトリで起動

```bash
git clone <このリポジトリのURL>
cd yuki1108
claude          # 方法Cの場合は npx @anthropic-ai/claude-code
```

初回起動時に認証方法（subscription ログイン / API キー）を選びます。

## 4. プロキシ経由で使う場合（px = px-proxy の場合）

社内プロキシなどを越えて通信する必要があるときは、環境変数を設定してから起動します:

```bash
export HTTPS_PROXY="http://127.0.0.1:3128"   # px-proxy の待受ポートに合わせる
export HTTP_PROXY="http://127.0.0.1:3128"
claude
```

API ゲートウェイを挟む場合は `ANTHROPIC_BASE_URL` を指定します。

## メモ

- プロジェクトの共有メモリは [`CLAUDE.md`](./CLAUDE.md) に書きます（Claude Code が自動で読み込みます）。
- 参考: 公式ドキュメント <https://code.claude.com/docs/>
