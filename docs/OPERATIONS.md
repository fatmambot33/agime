# Operations

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

Safety rail: `restore.sh` refuses restore to `/` unless `RESTORE_FORCE=1`.

## Update

```sh
sh ./update.sh
```

Key flags:

- `GIT_PULL=auto|1|0`
- `RUN_BACKUP=1|0`
- `RUN_BUILD=1|0`
- `BACKUP_OUTPUT=/path/to/archive.tar.gz`

## Image-first deployments (optional)

`build.sh` supports prebuilt images:

```sh
SKIP_OPENCLAW_IMAGE_BUILD=1 OPENCLAW_IMAGE=ghcr.io/example/openclaw:tag sh ./build.sh
```

This remains optional and is intentionally not the primary default path.
