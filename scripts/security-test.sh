#!/bin/bash
# OpenCrow セキュリティ検証スクリプト
# 全テストがPASSするまで本番利用しないこと

set -e
PASS=0
FAIL=0

echo "========================================="
echo " OpenCrow Security Verification"
echo " $(date)"
echo "========================================="
echo ""

# Test 1: OpenCrowが外部に直接アクセスできないこと
echo -n "[TEST 1] OpenCrow → 外部ネットワーク遮断... "
if docker exec opencrow-agent ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
  echo "FAIL (外部にアクセスできてしまう)"
  FAIL=$((FAIL+1))
else
  echo "PASS"
  PASS=$((PASS+1))
fi

# Test 2: LiteLLM稼働確認
echo -n "[TEST 2] LiteLLM ヘルスチェック... "
HEALTH=$(docker exec opencrow-agent curl -s http://litellm:4000/health 2>/dev/null || echo "ERROR")
if echo "$HEALTH" | grep -q "healthy"; then
  echo "PASS"
  PASS=$((PASS+1))
else
  echo "FAIL ($HEALTH)"
  FAIL=$((FAIL+1))
fi

# Test 3: 許可ドメインへのアクセス
echo -n "[TEST 3] Squid → 許可ドメイン通過... "
STATUS=$(docker exec opencrow-agent curl -s -o /dev/null -w '%{http_code}' -x http://squid:3128 https://github.com 2>/dev/null || echo "000")
if [ "$STATUS" = "200" ] || [ "$STATUS" = "301" ] || [ "$STATUS" = "302" ]; then
  echo "PASS (HTTP $STATUS)"
  PASS=$((PASS+1))
else
  echo "FAIL (HTTP $STATUS)"
  FAIL=$((FAIL+1))
fi

# Test 4: 非許可ドメインのブロック
echo -n "[TEST 4] Squid → 非許可ドメイン拒否... "
STATUS=$(docker exec opencrow-agent curl -s -o /dev/null -w '%{http_code}' -x http://squid:3128 https://facebook.com 2>/dev/null || echo "000")
if [ "$STATUS" = "403" ] || [ "$STATUS" = "000" ]; then
  echo "PASS (HTTP $STATUS - blocked)"
  PASS=$((PASS+1))
else
  echo "FAIL (HTTP $STATUS - not blocked)"
  FAIL=$((FAIL+1))
fi

# Test 5: APIキーがOpenCrowコンテナに存在しないこと
echo -n "[TEST 5] APIキー非露出... "
LEAKED=$(docker exec opencrow-agent env 2>/dev/null | grep "ANTHROPIC_API_KEY" || echo "")
if [ -z "$LEAKED" ]; then
  echo "PASS"
  PASS=$((PASS+1))
else
  echo "FAIL (APIキーがコンテナ内に露出)"
  FAIL=$((FAIL+1))
fi

# Test 6: コンテナがnon-rootで動作していること
echo -n "[TEST 6] non-root実行... "
USER=$(docker exec opencrow-agent whoami 2>/dev/null || echo "unknown")
if [ "$USER" != "root" ]; then
  echo "PASS (user: $USER)"
  PASS=$((PASS+1))
else
  echo "FAIL (root で実行されている)"
  FAIL=$((FAIL+1))
fi

# Test 7: LiteLLMポートがローカルのみ
echo -n "[TEST 7] LiteLLMポート ローカル限定... "
if lsof -i :4000 2>/dev/null | grep -v "127.0.0.1" | grep -q "LISTEN"; then
  echo "FAIL (外部に露出)"
  FAIL=$((FAIL+1))
else
  echo "PASS"
  PASS=$((PASS+1))
fi

echo ""
echo "========================================="
echo " Result: $PASS PASS / $FAIL FAIL"
echo "========================================="

if [ $FAIL -gt 0 ]; then
  echo ""
  echo "⚠️  FAILがあります。修正してから本番利用してください。"
  exit 1
else
  echo ""
  echo "✅ 全テストPASS。本番利用OKです。"
  exit 0
fi
