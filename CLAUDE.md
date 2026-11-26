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
├── app.json.example    # pm2 用プロセス定義の例（コピーして app.json にする。app.json は git 管理外）
├── lib/
│   ├── node.js         # 本体（web3 接続・Primus 接続・report ロジック）
│   └── utils/          # ユーティリティ
├── public/
│   └── VBC.svg         # ロゴ
├── Dockerfile          # このリポジトリからイメージを作る（設定は環境変数）
└── package.json
```

## よく使うコマンド

```bash
# 依存インストール
npm install

# 起動（環境変数を設定してから）
npm start

# pm2 で起動（app.json.example をコピーして app.json を作ってから）
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

### 3. ノード再起動後のフィルター再設定

web3 0.x の `eth.filter('latest' / 'pending')` はノード側に状態を持つ。ノードが再起動すると
フィルターは消え、ポーリングは毎回エラーになる。停止が短く（数秒）、5 秒ごとの `getStats` が
失敗しないまま戻った場合は `setInactive()` → `reconnectWeb3()` の経路に入らないため、
フィルターのコールバックがエラーを受けたら `filterFailed()` から `reconnectWeb3()` を呼んで
作り直す。以前はエラーを無視して `hash` が undefined のまま `getBlock` を呼び、
`Invalid params: invalid type: null` を 1 秒に 2 回出し続けた（2026-11-25 の TK02。ovbc を
6 秒で再起動した後、レポーターを再起動するまで報告が止まった）。

`reconnectWeb3()` は同期ウォッチャー（`web3.eth.isSyncing`）を残して web3 をリセットし、続く
`init()` → `setWatches()` がもう 1 つ登録する。`setWatches()` は登録の前に、前のウォッチャー
（`this.syncWatch`）を `stopWatching()` で止める。止めないと再接続のたびに 1 つ増え、同期の
開始・終了を増えた数だけ処理して、フィルターも同じ組数を張る。

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

設定は `EnvironmentFile=`（root だけが読める 600 のファイル）で渡し、`Environment=WS_SECRET=...` を
ユニットファイルに書かない（ユニットファイルは `systemctl cat` で誰でも読める）。本番の Ovbc 6 台は
ユニット `ovbc-netstats` が `EnvironmentFile=/etc/ovbc-netstats.env` で `node app.js` を起動している。

`bin/`・`processes-ec2.json`・`.travis.yml`（アップストリームの Ethereum 用。eth / geth を PPA から入れ、
`kill -9` で node を全停止する）と、上流の旧エージェントを clone していた Dockerfile は 2026-11 に
削除・置き換えた。

## セキュリティ

1. **WS_SECRET**: 認証情報。リポジトリにコミットせず環境変数で設定。漏洩時はローテーション
2. **app.json**: git 管理外（実設定）。テンプレートの `app.json.example` はプレースホルダのみで、実シークレットを含めない
3. **.gitignore**: `app.json`, `config.js`, `*.pem`, `node_modules` を除外（`.dockerignore` も `app.json` と `*.env` をイメージに入れない）

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

| リポジトリ | 役割 | ローカルパス | URL |
|-----------|------|-------------|-----|
| **virbicoin.com** | 公式 Web サイト（メインサイト。private） | `../virbicoin.com` | [github.com/virbicoin/virbicoin.com](https://github.com/virbicoin/virbicoin.com) |
| **go-virbicoin** | メインクライアント（Gvbc, Go 実装） | `../go-virbicoin` | [github.com/virbicoin/go-virbicoin](https://github.com/virbicoin/go-virbicoin) |
| **open-virbicoin** | Rust クライアント（Ovbc, OpenEthereum フォーク） | `../open-virbicoin` | [github.com/virbicoin/open-virbicoin](https://github.com/virbicoin/open-virbicoin) |
| **vbc-explorer** | ブロックチェーンエクスプローラー（DEX・Launchpad・ブリッジ画面を含む） | `../vbc-explorer` | [github.com/virbicoin/vbc-explorer](https://github.com/virbicoin/vbc-explorer) |
| **vbc-stats** | ネットワーク統計ダッシュボード | `../vbc-stats` | [github.com/virbicoin/vbc-stats](https://github.com/virbicoin/vbc-stats) |
| **vbc-stats-api** ← 本リポジトリ | VBC Stats 用ノードレポーター（組み込みレポーターのない Ovbc 向け） | `../vbc-stats-api` | [github.com/virbicoin/vbc-stats-api](https://github.com/virbicoin/vbc-stats-api) |
| **vbc-pool** | マイニングプール | `../vbc-pool` | [github.com/virbicoin/vbc-pool](https://github.com/virbicoin/vbc-pool) |
| **vbc-rpc** | RPC ノードステータスページ（公開 RPC・WebSocket の案内） | `../vbc-rpc` | [github.com/virbicoin/vbc-rpc](https://github.com/virbicoin/vbc-rpc) |
| **vbc-hash** | Ethash アルゴリズム実装（C/Go バインディング） | `../vbc-hash` | [github.com/virbicoin/vbc-hash](https://github.com/virbicoin/vbc-hash) |

### 依存関係

- **go-virbicoin** と **open-virbicoin**: 同じ VirBiCoin ネットワーク（chainId 329）の 2 つのクライアント実装（Gvbc は Go、Ovbc は Rust）。報酬・フォークブロックなどコンセンサスに関わる変更は必ず両方に同時に入れる
- **vbc-explorer** → ノードの JSON-RPC（Gvbc / Ovbc）。内部取引の索引は Parity 形式の `trace_transaction` を使うため Ovbc が必要（本番の explorer は Ovbc の IPC ソケットを読む）
- **vbc-stats** ← Gvbc は組み込みの ethstats レポーター（`--ethstats`）で直接報告し、Ovbc は **vbc-stats-api** を介して報告する
- **vbc-pool** → ノードの JSON-RPC（Gvbc / Ovbc。本番は両方）から作業を取得し、ブロックの確定と支払いを行う。シェアの検証は `proxy/miner.go` の純 Go 実装で、vbc-hash には依存しない
- **vbc-rpc** → 各ノードの JSON-RPC（8329）に状態を問い合わせるだけ。公開 RPC（rpc.virbicoin.com）への POST は nginx がノードへ中継し、このアプリを通らない
- **vbc-hash**: このワークスペースのどのリポジトリも import していない（Gvbc は `consensus/ethash`、vbc-pool は `proxy/miner.go` の自前実装）
- **virbicoin.com**: 静的サイト（他リポジトリへのリンクのみ）
- 公開リポジトリなので、private のリポジトリはこの表に載せていない（virbicoin.com は公開 Web サイトのソースとして載せる）。公開 README からは virbicoin.com の GitHub ではなく Web サイト（https://www.virbicoin.com）にリンクする

## ライセンス

LGPL-3.0（アップストリームの package.json の表記を継承）。LGPL は GPL に追加の許可を足したものなので、[LICENSE](LICENSE)（GPL-3.0 の全文）と [COPYING.LESSER](COPYING.LESSER)（LGPL-3.0 の全文）の両方を置く（go-ethereum / go-virbicoin と同じ構成。2026-11 までは GPL の全文だけで、表記と食い違っていた）。なお上流の LICENSE も GPL-3.0 の全文だけで、GitHub は上流を GPL-3.0 と表示する。
