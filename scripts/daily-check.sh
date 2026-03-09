#!/bin/bash
# OpenCrow 日次セキュリティチェック

echo "=== OpenCrow Daily Check ==="
echo "Date: $(date)"
echo ""

# コンテナ稼働状況
echo "--- Containers ---"
docker compose -f ~/opencrow-macmini-setup/config/docker-compose.yml ps --format "table {{.Name}}\t{{.Status}}"
echo ""

# ポート露出
echo "--- Port Check ---"
if lsof -i :4000 2>/dev/null | grep -v "127.0.0.1" | grep -q "LISTEN"; then
  echo "⚠️  CRITICAL: LiteLLM port exposed!"
else
  echo "OK: LiteLLM bound to localhost only"
fi
echo ""

# Squidブロックログ
echo "--- Blocked Requests (last 10) ---"
docker exec opencrow-squid grep "DENIED" /var/log/squid/access.log 2>/dev/null | tail -10 || echo "No blocks"
echo ""

# ディスク使用量
echo "--- Disk Usage ---"
du -sh ~/opencrow-macmini-setup/workspace 2>/dev/null || echo "workspace: empty"
du -sh ~/opencrow-macmini-setup/sessions 2>/dev/null || echo "sessions: empty"
