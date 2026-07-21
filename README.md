# yuki1108

ローカル環境で開発するためのセットアップです。VS Code（`code` コマンド）で開き、
パッケージランナーで各種コマンドを実行できるようにしています。

## 必要なもの

- [Node.js](https://nodejs.org/)（LTS 推奨。このリポジトリは Node 22 で動作確認）
- [VS Code](https://code.visualstudio.com/) と `code` コマンド
  - macOS: VS Code を開き、コマンドパレット（`Cmd+Shift+P`）→
    「Shell Command: Install 'code' command in PATH」を実行
  - Windows: インストーラーで「PATH に追加」を選択（既定で有効）

## ローカルで開く

```bash
git clone <このリポジトリのURL>
cd yuki1108
code .          # VS Code で開く
```

## パッケージランナー（px）について

「px」は文脈により指すものが異なります。よく使う候補と、このリポジトリでの実行例:

| px の解釈 | インストール | 実行例 |
| --- | --- | --- |
| `npx`（npm 同梱のランナー） | Node.js に同梱 | `npx <package>` |
| `pnpm dlx`（`px` として alias されることあり） | `npm i -g pnpm` | `pnpm dlx <package>` |
| [px-proxy](https://github.com/genotrance/px)（HTTP プロキシ） | `pip install px-proxy` | `px --proxy=...` 経由で通信 |

> あなたの環境の「px」がどれかを教えてもらえれば、この節を確定版に置き換えます。

## スクリプト

```bash
npm install     # 依存関係をインストール
npm start       # アプリを起動（package.json の start を編集して使用）
```
