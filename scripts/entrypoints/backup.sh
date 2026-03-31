BACKUP_DIR=~/Downloads/openclaw-$(date +%F)

rsync -az --delete \
  --exclude='.git' \
  ubuntu@my-vps:/home/ubuntu/.openclaw/ \
  "$BACKUP_DIR/"