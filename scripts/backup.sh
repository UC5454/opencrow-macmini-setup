#!/bin/bash
# OpenCrow 暗号化バックアップ

AGE_KEY=~/opencrow-macmini-setup/credentials/age-key.txt
BACKUP_DIR=~/opencrow-macmini-setup/backups
DATE=$(date +%Y%m%d)

if [ ! -f "$AGE_KEY" ]; then
  echo "age鍵が見つかりません。先に作成してください:"
  echo "  age-keygen -o $AGE_KEY"
  exit 1
fi

mkdir -p "$BACKUP_DIR"

PUBKEY=$(grep "public key" "$AGE_KEY" | awk '{print $NF}')

tar czf - \
  ~/opencrow-macmini-setup/config \
  ~/opencrow-macmini-setup/skills \
  ~/opencrow-macmini-setup/sessions \
  2>/dev/null | \
  age -r "$PUBKEY" > "$BACKUP_DIR/backup-${DATE}.tar.gz.age"

echo "Backup created: $BACKUP_DIR/backup-${DATE}.tar.gz.age"
echo "Size: $(du -h "$BACKUP_DIR/backup-${DATE}.tar.gz.age" | cut -f1)"
