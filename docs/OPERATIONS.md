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

## Optional image-first runtime

```sh
SKIP_OPENCLAW_IMAGE_BUILD=1 OPENCLAW_IMAGE=ghcr.io/example/openclaw:tag sh ./build.sh
```
