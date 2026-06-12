# CLAUDE.md - VBC Stats API Project Guide

このファイルは AI アシスタント（Claude）がこのコードベースを効果的に理解・操作するためのガイドです。

## プロジェクト概要

**VBC Stats API** は VirBiCoin ノードの隣で動作し、JSON-RPC でチェーン情報を取得して
[VBC Stats](https://github.com/virbicoin/vbc-stats) ダッシュボードへ WebSocket で
送信するレポーターエージェントです。

[eth-net-intelligence-api](https://github.com/cubedro/eth-net-intelligence-api) の
フォークで、WebSocket クライアント（Primus）を現行の VBC Stats サーバーと同じバージョン
（Primus 8 / ws 8）に更新しています。

> **フォークの理由**: VBC Stats サーバーは Primus 8 / ws 8 で動作します。アップストリームの
> エージェントは Primus 4 / ws 1 で、メジャーバージョンが非互換のため大半の接続が認証前に
> 切断され、ノードが古いブロックで止まって見える問題がありました。本フォークはクライアントを
> Primus 8 / ws 8 に更新してこれを解消します。

ビルトインの ethstats レポーターを持たないノード（例: OpenVirBiCoin / Ovbc）向けです。
VirBiCoin の Go クライアント（Gvbc）は組み込みレポーターで直接報告するため、本エージェントは
不要です。

### 技術スタック

- **ランタイム**: Node.js 20+
- **WebSocket**: Primus 8（`primus-emit`, `primus-spark-latency` プラグイン）
- **トランスポート**: ws 8
- **RPC クライアント**: web3 0.x（レガシー JSON-RPC）
- **プロセス管理**: pm2 / systemd

## プロジェクト構造

```
vbc-stats-api/
├── app.js              # エントリポイント（Node インスタンス生成・シグナル処理）
├── app.json            # pm2 用プロセス定義（プレースホルダのみ）
├── lib/
│   ├── node.js         # 本体（web3 接続・Primus 接続・report ロジック）
│   └── utils/          # ユーティリティ
├── bin/                # 配布・更新スクリプト
├── public/
│   └── VBC.svg         # ロゴ
├── Dockerfile
└── package.json
```

## よく使うコマンド

```bash
# 依存インストール
npm install

# 起動（環境変数を設定してから）
npm start

# pm2 で起動
pm2 start app.json
```

## アーキテクチャ

`app.js` が `lib/node.js` の `Node` を生成し、以下の流れで動作します:

1. `startWeb3Connection()` — web3 0.x で `RPC_HOST:RPC_PORT` の JSON-RPC へ接続
2. `init()` — ノード情報取得 → `startSocketConnection()` → フィルタ設定
3. `startSocketConnection()` — `WS_SERVER` へ Primus 8 ソケットで接続
4. `setupSockets()` — `open` で `hello` を送信して認証、`ready` で報告開始
5. チェーンヘッド/ペンディングの変化を検知し `block` / `pending` / `stats` を emit

### VBC Stats サーバーとのプロトコル

- `hello` — `{ id, info, secret }` で認証（`secret` はサーバーの `WS_SECRET` と一致必須）
- `block` / `pending` / `stats` — ノードの状態を報告
- `node-ping` / `latency` — レイテンシ計測

## 重要な実装パターン

### 1. Primus 8 互換性

- Primus 8 では `createSocket` の `timeout` オプションが**削除**されている（指定すると例外）
- reconnect 系イベント（`reconnect scheduled` / `reconnected` / `reconnect failed` /
  `reconnect timeout` / `online` / `offline` / `timeout`）は Primus 8 でも有効
- クライアントとサーバーの Primus メジャーバージョンは**必ず一致**させる（4↔8 は非互換）

### 2. 数値の文字列送信

web3 0.x は `gasPrice` などを文字列で返すことがある（例: `'0'`）。受信側（VBC Stats）は
`parseInt` で数値化するため許容されるが、新規実装では型に注意する。

## コーディング規約

- ES5 ベースの既存スタイルを踏襲（`var`, prototype メソッド）。アップストリーム由来の
  コードは大幅なリファクタを避ける
- 接続・認証・報告の各段でログを出す（`VERBOSITY` で制御）

## 環境変数

| 変数              | 説明                                                  |
| ----------------- | ----------------------------------------------------- |
| `RPC_HOST`        | ノードの JSON-RPC ホスト                              |
| `RPC_PORT`        | ノードの JSON-RPC ポート                              |
| `LISTENING_PORT`  | ノードの P2P ポート（表示のみ）                       |
| `INSTANCE_NAME`   | ダッシュボードに表示されるノード名                    |
| `CONTACT_DETAILS` | 連絡先（任意）                                        |
| `WS_SERVER`       | VBC Stats サーバー URL（例: `wss://stats.virbicoin.com`） |
| `WS_SECRET`       | 共有シークレット（サーバーの `WS_SECRET` と一致必須） |
| `VERBOSITY`       | ログレベル（`0` 静音 … `3` 全ログ）                   |

## デプロイ（systemd）

`StartLimitIntervalSec` / `StartLimitBurst` は **`[Service]` ではなく `[Unit]`
セクション**に記述する（`[Service]` に書くと無視され警告が出る）。詳細は README を参照。

## セキュリティ

1. **WS_SECRET**: 認証情報。リポジトリにコミットせず環境変数で設定。漏洩時はローテーション
2. **app.json**: プレースホルダのみをコミット。実シークレットを含めない
3. **.gitignore**: `app.json`（実設定）, `config.js`, `*.pem`, `node_modules` を除外

## コミット署名（GPG）

このリポジトリのコミットは GPG 署名が有効な場合があります。AI エージェントはパスフレーズを
代理入力できないため、gpg-agent のキャッシュが切れていると `git commit` が署名失敗で中断する
ことがあります。

- 署名が切れているときは、ユーザーがターミナルで一度パスフレーズを入力してください
  （`export GPG_TTY=$(tty)` を設定してから `echo test | gpg --clearsign`）。一度入力すれば
  gpg-agent がしばらくキャッシュします。
- `pinentry-curses` を使う環境では温める前に `export GPG_TTY=$(tty)` を実行し、`gpg
  --clearsign` の出力を `>/dev/null` へ捨てないでください（pinentry が tty を奪えず幽霊化する
  原因になります）。
- パスフレーズは秘密情報です。AI エージェントへ渡したりディスクへ保存したりしないでください。

## 関連リポジトリ

VirBiCoin エコシステムは以下のリポジトリで構成されています:

| リポジトリ                        | 役割                                             | ローカルパス             | URL                                                                                          |
| --------------------------------- | ------------------------------------------------ | ------------------------ | -------------------------------------------------------------------------------------------- |
| **virbicoin.com**                 | 公式 Web サイト（メインサイト）                  | `../virbicoin.com`       | [github.com/virbicoin/virbicoin.com](https://github.com/virbicoin/virbicoin.com)             |
| **go-virbicoin**                  | メインクライアント（Gvbc, Go 実装）              | `../go-virbicoin`        | [github.com/virbicoin/go-virbicoin](https://github.com/virbicoin/go-virbicoin)               |
| **open-virbicoin**                | Rust クライアント（Ovbc, OpenEthereum フォーク） | `../openvirbicoin`       | [github.com/virbicoin/open-virbicoin](https://github.com/virbicoin/open-virbicoin)           |
| **vbc-stats**                     | ネットワーク統計ダッシュボード                   | `../vbc-stats`           | [github.com/virbicoin/vbc-stats](https://github.com/virbicoin/vbc-stats)                     |
| **vbc-stats-api** ← 本リポジトリ | VBC Stats 用ノードレポーターエージェント         | `../vbc-stats-api`       | [github.com/virbicoin/vbc-stats-api](https://github.com/virbicoin/vbc-stats-api)             |
| **vbc-explorer**                  | ブロックチェーンエクスプローラー                 | `../vbc-explorer`        | [github.com/virbicoin/vbc-explorer](https://github.com/virbicoin/vbc-explorer)               |
| **open-virbicoin-pool**           | マイニングプール                                 | `../open-virbicoin-pool` | [github.com/virbicoin/open-virbicoin-pool](https://github.com/virbicoin/open-virbicoin-pool) |
| **vbc-rpc**                       | RPC ノードステータス & JSON-RPC プロキシ         | `../vbc-rpc`             | [github.com/virbicoin/vbc-rpc](https://github.com/virbicoin/vbc-rpc)                         |

### 依存関係

- **vbc-stats-api** → **go-virbicoin** / **open-virbicoin**: ノードの JSON-RPC からチェーン
  情報を取得
- **vbc-stats-api** → **vbc-stats**: 取得した情報を Primus 8 WebSocket で送信
- **vbc-stats** ← **go-virbicoin**: Gvbc は組み込み ethstats レポーターで直接報告するため、
  本エージェントは不要（主に Ovbc 向け）

## ライセンス

LGPL-3.0（アップストリームから継承）。詳細は [LICENSE](LICENSE) を参照。
