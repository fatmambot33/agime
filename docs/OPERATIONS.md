# Operations

## Deploy/update paths

- First deploy: `setup.sh`
- Ongoing deploy: `sync.sh`
- In-place maintenance deploy: `update.sh`

## Backup

```sh
sh ./backup.sh
```

## Restore

```sh
RESTORE_ARCHIVE=./openclaw-backup-YYYYmmdd-HHMMSS.tar.gz \
RESTORE_ROOT=/ \
RESTORE_FORCE=1 \
sh ./restore.sh
```

`restore.sh` refuses `/` restores unless `RESTORE_FORCE=1`.

## Image runtime policy

agime pulls the official OpenClaw image (`ghcr.io/openclaw/openclaw:latest`) during deploy.
