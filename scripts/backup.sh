BACKUP_DIR=~/Downloads/openclaw-$(date +%F)
rsync -avz --exclude='.git' ubuntu@my-vps:/home/ubuntu/.openclaw/workspace "$BACKUP_DIR"