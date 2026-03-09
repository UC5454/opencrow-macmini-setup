# OpenCrow on Mac mini — リモート24時間稼働セットアップ

Mac miniにOpenCrowを導入し、スマホ・別PCからチャットで指示を出せる24時間AIエージェント環境を構築する。

## OpenCrowとは

[OpenCrow](https://github.com/pinpox/opencrow)は、Matrix（暗号化チャット）経由でAIコーディングエージェント（pi）を操作するブリッジ。
スマホのElementアプリからメッセージを送るだけでAIが動く。セッション永続化・自動コンパクション対応。

## アーキテクチャ

```
┌───────────────────────────────────────────────────┐
│  Mac mini（常時稼働）                                │
│                                                     │
│  Docker Network (隔離)                              │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐      │
│  │ OpenCrow  │→→│ LiteLLM   │→→│ Anthropic │      │
│  │ + pi      │  │ APIプロキシ │  │ API       │      │
│  │ 内部のみ   │  │ キー管理    │  └───────────┘      │
│  └─────┬─────┘  └───────────┘                      │
│        ↕                                            │
│  ┌───────────┐  ┌───────────┐                      │
│  │ Squid     │  │ GDrive    │                      │
│  │ 許可制     │  │ MCP       │                      │
│  │ Proxy     │  │ 限定アクセス │                      │
│  └───────────┘  └───────────┘                      │
│                                                     │
│  Tailscale VPN ←── スマホ / 別PC                     │
│  Matrix ←── Element アプリ                           │
└───────────────────────────────────────────────────┘
```

**セキュリティ**: OpenCrowコンテナは外部ネットワークに直接アクセス不可。LiteLLM（APIキー管理）とSquid（ドメイン許可制）を経由する多層防御。

---

## 必要なもの

| 項目 | 要件 |
|------|------|
| Mac mini | Apple Silicon, メモリ16GB以上 |
| macOS | Sequoia 15.x 以降 |
| Anthropic | Claude Max契約 or APIキー |
| GitHub | アカウント（このリポジトリ用） |

---

## セットアップ手順

### Step 1: Mac mini 基本準備（10分）

```bash
# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 必須ツール
brew install --cask docker
brew install tailscale age jq

# Docker Desktop → Settings → General → "Start Docker Desktop when you log in" ON
# Docker Desktop → Settings → Resources → Memory: 8GB以上
```

### Step 2: このリポジトリをクローン（1分）

```bash
cd ~
git clone https://github.com/UC5454/opencrow-macmini-setup.git
cd opencrow-macmini-setup
```

### Step 3: 認証情報のセットアップ（5分）

```bash
# 認証ディレクトリの権限設定
chmod 700 credentials

# Anthropic APIキー
cat > credentials/anthropic.env << 'EOF'
ANTHROPIC_API_KEY=sk-ant-ここにキーを貼る
EOF
chmod 600 credentials/anthropic.env
```

#### Matrix アカウント作成

1. https://app.element.io でアカウント作成（ボット用）
2. Settings → Help & About → Access Token をコピー

```bash
# Matrixトークン
cat > credentials/matrix.env << 'EOF'
OPENCROW_MATRIX_HOMESERVER=https://matrix.org
OPENCROW_MATRIX_USER_ID=@your-bot-name:matrix.org
OPENCROW_MATRIX_ACCESS_TOKEN=syt_ここにトークン
OPENCROW_ALLOWED_USERS=@your-main-account:matrix.org
EOF
chmod 600 credentials/matrix.env
```

> **重要**: `OPENCROW_ALLOWED_USERS` に自分のメインアカウントを設定。ボットに指示を出せるのはここに書いたユーザーのみ。

#### Google Drive（オプション）

Google Driveにアクセスさせる場合のみ:

1. [Google Cloud Console](https://console.cloud.google.com) → 新プロジェクト作成
2. Drive API 有効化 → サービスアカウント作成 → JSONキーをダウンロード
3. **アクセスさせたいフォルダだけ**をサービスアカウントに共有

```bash
mkdir -p credentials/gdrive-token
cp ~/Downloads/your-service-account.json credentials/gdrive-token/credentials.json
chmod 600 credentials/gdrive-token/credentials.json
```

### Step 4: LiteLLMマスターキーの変更（1分）

```bash
# config/litellm-config.yaml を編集
# master_key を任意の文字列に変更する
vim config/litellm-config.yaml
```

### Step 5: 起動（2分）

```bash
cd config
docker compose up -d

# ログ確認
docker compose logs -f opencrow
```

### Step 6: セキュリティ検証（3分）

**全テストがパスするまで本番利用しないこと。**

```bash
bash ../scripts/security-test.sh
```

個別に確認する場合:

```bash
# 1. OpenCrowが外部に直接アクセスできないこと
docker exec opencrow-agent ping -c 1 8.8.8.8
# → タイムアウト = OK

# 2. LiteLLM経由でAPI接続できること
docker exec opencrow-agent curl -s http://litellm:4000/health
# → {"status": "healthy"} = OK

# 3. 許可ドメインのみ通ること
docker exec opencrow-agent curl -x http://squid:3128 -I https://github.com
# → 200 = OK
docker exec opencrow-agent curl -x http://squid:3128 -I https://facebook.com
# → 403 = OK（ブロックされている）

# 4. APIキーがOpenCrowコンテナに存在しないこと
docker exec opencrow-agent env | grep ANTHROPIC_API_KEY
# → 空 = OK
```

### Step 7: Matrixから動作確認（2分）

1. スマホ or PCで [Element](https://app.element.io) を開く
2. ボットアカウントにDMを送信
3. `!help` → コマンド一覧が返ればOK
4. `Hello` → piが応答すればOK

---

## スマホからリモート操作する方法

### 方法A: Element チャット（推奨・誰でも使える）

これが一番シンプル。技術知識不要。

1. スマホに **Element** アプリをインストール（[iOS](https://apps.apple.com/app/element/id1083446067) / [Android](https://play.google.com/store/apps/details?id=im.vector.app)）
2. 自分のメインアカウントでログイン
3. ボットにDMを送信 → AIが動く

```
あなた: 「売上レポートのスプレッドシートを作って」
ボット: （piが処理）→ 結果を返信
```

**できること**:
- テキストで指示 → AIが実行
- 画像・ファイルの送信 → AIが読み取り・処理
- `!stop` で処理中断
- `!restart` でセッションリセット
- `!compact` でコンテキスト圧縮

### 方法B: Tailscale + SSH（管理者用）

Mac miniに直接SSHしてDocker操作やログ確認ができる。

#### Tailscale セットアップ

**Mac mini側:**
```bash
# Tailscaleインストール & 起動
brew install --cask tailscale
# Tailscale.app を起動 → ログイン

# SSH有効化
sudo systemsetup -setremotelogin on
tailscale up --ssh
```

**スマホ側:**
1. Tailscaleアプリをインストール → 同じアカウントでログイン
2. [Termius](https://apps.apple.com/app/termius/id549039908)（iOS）or [JuiceSSH](https://play.google.com/store/apps/details?id=com.sonelli.juicessh)（Android）をインストール
3. 接続先: `mac-mini`（Tailscaleのホスト名）

```bash
# スマホのSSHクライアントから
ssh mac-mini

# ログ確認
docker compose -f ~/opencrow-macmini-setup/config/docker-compose.yml logs --tail 50

# コンテナ再起動
docker compose -f ~/opencrow-macmini-setup/config/docker-compose.yml restart opencrow
```

**別PC側:**
同様にTailscaleをインストール → `ssh mac-mini` で接続。

---

## Mac miniの常時稼働設定

```bash
# スリープ無効化
sudo pmset -a disablesleep 1
sudo pmset -a sleep 0

# 電源復旧時の自動起動
sudo pmset -a autorestart 1

# Docker Desktop 自動起動: Settings → General → "Start Docker Desktop when you log in"

# OpenCrow自動起動: docker compose の restart: unless-stopped で対応済み
```

---

## ディレクトリ構成

```
opencrow-macmini-setup/
├── README.md                    # このファイル
├── config/
│   ├── docker-compose.yml       # メイン構成（4コンテナ）
│   ├── litellm-config.yaml      # APIプロキシ設定
│   ├── squid.conf               # ドメイン許可制プロキシ
│   ├── allowlist.txt            # 許可ドメインリスト
│   └── soul.md                  # AIの行動規範
├── credentials/                 # 機密情報（.gitignore済み）
│   ├── anthropic.env
│   ├── matrix.env
│   └── gdrive-token/
├── scripts/
│   ├── security-test.sh         # セキュリティ検証
│   ├── daily-check.sh           # 日次監視
│   └── backup.sh                # 暗号化バックアップ
├── skills/                      # AIスキル定義
│   ├── gdrive/SKILL.md
│   └── web/SKILL.md
└── .gitignore
```

---

## セキュリティ設計（7層防御）

| 層 | 対策 | 守るもの |
|----|------|---------|
| 1. ネットワーク隔離 | Docker internal network | データ漏洩 |
| 2. APIキー分離 | LiteLLMのみ保持 | APIキー漏洩 |
| 3. ドメイン許可制 | Squid deny-by-default | 不正外部通信 |
| 4. コンテナ権限最小化 | CAP全DROP, non-root, read-only | 権限昇格 |
| 5. Drive限定アクセス | サービスアカウント + 専用フォルダ | 他データアクセス |
| 6. ユーザー制限 | ALLOWED_USERS | 第三者からの注入 |
| 7. ログ可視化 | SHOW_TOOL_CALLS + Squidログ | 不審挙動の検知 |

---

## 運用コマンド

```bash
# 起動
cd ~/opencrow-macmini-setup/config && docker compose up -d

# 停止
docker compose down

# ログ確認
docker compose logs -f opencrow

# 全コンテナ再起動
docker compose restart

# セキュリティチェック
bash ~/opencrow-macmini-setup/scripts/security-test.sh

# 日次監視
bash ~/opencrow-macmini-setup/scripts/daily-check.sh

# バックアップ
bash ~/opencrow-macmini-setup/scripts/backup.sh

# 完全リセット（壊れた時）
docker compose down -v && docker compose up -d
```

---

## トラブルシューティング

| 問題 | 対処 |
|------|------|
| ボットが応答しない | `docker compose logs opencrow` でエラー確認。`docker compose restart opencrow` |
| APIエラー | `docker compose logs litellm` 確認。`credentials/anthropic.env` のキーが正しいか |
| Matrixに接続できない | `credentials/matrix.env` のトークン確認。Element上でボットがオンラインか確認 |
| Squidでブロックされる | `config/allowlist.txt` にドメイン追加 → `docker compose restart squid` |
| Mac miniにSSHできない | Tailscaleが両方のデバイスで接続中か確認。`tailscale status` |
| ディスクが埋まった | `docker system prune -f` + セッションログ削除 |

---

## 参考リンク

- [OpenCrow (GitHub)](https://github.com/pinpox/opencrow)
- [pi coding agent](https://github.com/can1357/oh-my-pi)
- [LiteLLM](https://github.com/BerriAI/litellm)
- [Element (Matrix client)](https://element.io)
- [Tailscale](https://tailscale.com)
- [OpenClaw Security Hardening Guide](https://aimaker.substack.com/p/openclaw-security-hardening-guide)
