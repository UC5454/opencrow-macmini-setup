---
name: web
description: Web検索・ページ取得（許可ドメインのみ）
---

## Web操作

Squidプロキシ経由でWebアクセスが可能。
許可ドメインリスト（config/allowlist.txt）に載っているサイトのみアクセスできる。

### 使い方
- `curl -x http://squid:3128 <URL>` でページ取得
- `lynx -dump <URL>` でテキスト抽出

### 制限事項
- 許可リスト外のドメインはブロックされる
- SNS、銀行、決済サイトへのアクセスは不可
