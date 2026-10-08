# mnemosyne-docker

[mnemosyne-memory](https://pypi.org/project/mnemosyne-memory/) の MCP サーバーを Docker で動かし、Claude Code から使うための構成です。

## 構成

| ファイル | 内容 |
| --- | --- |
| `Dockerfile` | `mnemosyne-memory[mcp,embeddings]` を入れて `mnemosyne mcp --transport sse` を起動 |
| `compose.yml` | ポート `127.0.0.1:8765` を公開し、`./data` を `/data` にマウント |
| `.env` | 認証トークン `MNEMOSYNE_MCP_TOKEN`(Git 管理しないこと) |
| `data/` | メモリの保存先(埋め込みモデルのキャッシュ `data/cache/fastembed` を含む) |

## セットアップ

トークンを生成して `.env` に保存します。

```bash
(umask 077; echo "MNEMOSYNE_MCP_TOKEN=$(openssl rand -hex 32)" > .env)
```

起動します。

```bash
docker compose up -d --build
```

## 動作確認

```bash
set -a && . ./.env && set +a

# トークンなし: 401
curl -s -o /dev/null -w '%{http_code}\n' --max-time 3 http://127.0.0.1:8765/sse

# トークンあり: 200 と event: endpoint が返る
curl -s -i --max-time 3 -H "Authorization: Bearer $MNEMOSYNE_MCP_TOKEN" http://127.0.0.1:8765/sse
```

## Claude Code への登録

```bash
set -a && . ./.env && set +a
claude mcp add --transport sse --scope user mnemosyne http://127.0.0.1:8765/sse \
  --header "Authorization: Bearer $MNEMOSYNE_MCP_TOKEN"
```

- `--scope user` なので全プロジェクトで使えます。
- トークンは `~/.claude.json` に平文で保存されます。
- 登録後は `/mcp` で再接続するか、Claude Code を再起動してください。

確認と削除:

```bash
claude mcp list
claude mcp remove --scope user mnemosyne
```

`.env` のトークンを変えたら、コンテナを再作成(`docker compose up -d`)し、削除してから登録し直します。

## 注意点

- **トランスポートは `sse` のみ**: mnemosyne 3.15.1 の `mnemosyne mcp` は `stdio` と `sse` しか受け付けません。`streamable-http` を指定すると起動に失敗します。
- **トークンは必須**: コンテナ内では `0.0.0.0` にバインドする必要があり、mnemosyne は非ループバックへのバインド時に `MNEMOSYNE_MCP_TOKEN` がないと起動を拒否します。
- **公開範囲はローカルのみ**: ホスト側は `127.0.0.1:8765` にだけ公開しています。
- **`MNEMOSYNE_MCP_ALLOWED_HOSTS`**: `compose.yml` に残っていますが、3.15.1 では参照されておらず効果がありません。

## ベクトル検索

`embeddings` extra で `fastembed` と `sqlite-vec` が入るため、ベクトル検索が有効です(`sqlite-vec` は extra に含まれるので個別の `pip install` は不要)。

- 埋め込みモデルは日本語に強い多言語モデル `intfloat/multilingual-e5-large`(1024 次元)です。`compose.yml` の `MNEMOSYNE_EMBEDDING_MODEL` で指定しています。fastembed には日本語専用モデルがないため、これを選んでいます。
- E5 系モデルは接頭辞が必要なので、`MNEMOSYNE_EMBEDDING_QUERY_PREFIX="query: "` と `MNEMOSYNE_EMBEDDING_DOC_PREFIX="passage: "` も設定しています。
- モデルは初回利用時にダウンロードされ、`data/cache/fastembed` に保存されます(約 2.2GB、初回は数分かかります)。再ビルドしても再ダウンロードされません。
- 実行時のメモリ使用量は約 1.6GB です。

### モデルを変えるとき

`data/config.yaml` は初回起動時に環境変数から生成され、以後は環境変数より優先されます。そのため、既存の `data/` があるときは `compose.yml` の変更だけでは反映されません。次の手順で切り替えます。

```bash
docker compose up -d
docker compose exec mnemosyne mnemosyne config set embedding_model <モデル名>
docker compose exec mnemosyne mnemosyne config set embedding_dim <次元数>
docker compose exec mnemosyne mnemosyne reindex --yes
docker compose restart
```

## 運用

```bash
docker compose logs -f     # ログ
docker compose down        # 停止
```

`mnemosyne-memory` を最新版に上げるときは、キャッシュを使わずに再ビルドします(`--build` だけだと pip のレイヤーがキャッシュされ、更新されません)。

```bash
docker compose build --no-cache
docker compose up -d
```
