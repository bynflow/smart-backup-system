# backup-smart

**Smart incremental backup + versioning (modified & deleted) with auto-cleanup and systemd timers.**

A simple Bash script that uses [rclone](https://rclone.org/) to perform incremental backups of multiple source directories, with automatic versioning of **modified** and **deleted** files and configurable retention.

---

## Features

* **Incremental sync** of specified source directories to a remote location.
* **Automatic versioning** of:

  * Modified files (previous versions moved to `history/modified/YYYY-MM-DD`).
  * Deleted files (moved to `history/deleted/YYYY-MM-DD`).
* **Retention policy**: purge history older than *RETENTION\_DAYS*.
* **Log rotation** of backup logs.
* **Automatic scheduling** via `systemd` user timers:

  * Regular backups every 3 hours.
  * On-boot backup \~10 minutes after login/boot.
* Optional exclude patterns for common directories or file types.

---

## Prerequisites

* **Linux** (or any POSIX‑compatible shell)
* **rclone** installed and configured with a remote (e.g. `remote:`)
* **systemd** user service support

---

## Installation

### 1. Copy the backup script

```bash
mkdir -p ~/.local/scripts/backup-smart
cp backup-smart.sh ~/.local/scripts/backup-smart/
chmod +x ~/.local/scripts/backup-smart/backup-smart.sh
```

### 2. Place systemd unit files

```bash
mkdir -p ~/.config/systemd/user
cp backup-smart.service backup-smart.timer \
   backup-smart-onboot.service backup-smart-onboot.timer \
   ~/.config/systemd/user/
```

Reload and enable timers:

```bash
systemctl --user daemon-reload
systemctl --user enable --now \
  backup-smart.timer backup-smart-onboot.timer
```

---

## Configuration

Edit `backup-smart.sh` to list your source folders under `SOURCES` and set `REMOTE`.
Adjust `RETENTION_DAYS=90` (or your custom value) as needed.
Uncomment and edit `EXCLUDES` patterns if you need to filter files (e.g., `node_modules`, `*.pyc`).

```bash
declare -A SOURCES=(
  [projects]="/path/to/projects"
  [keepass]="/path/to/keepass"
  [notes]="/path/to/notes"
)
REMOTE="remote:backup"
RETENTION_DAYS=90  # e.g. 90 days
# Optional excludes:
# EXCLUDES=("--exclude=.venv/**" "--exclude=node_modules/**" "--exclude=*.pyc")
```

---

## Usage

* **Regular backup:** runs every 3 hours via `backup-smart.timer`.
* **On-boot backup:** runs \~10 minutes after login/boot via `backup-smart-onboot.timer`.
* **History cleanup:** old versions in `history/modified` and `history/deleted` are purged after the retention period.

---

## How It Works

1. **Sync Phase**

   * `rclone sync` each source to `remote:backup/<source>`.
   * Overwritten/deleted files go into `working/YYYY-MM-DD/<source>/`.

2. **Versioning Phase**

   * Scan `working/YYYY-MM-DD/`.
   * If file exists locally → move to `history/modified/YYYY-MM-DD/<source>/…`.
   * If file missing locally → move to `history/deleted/YYYY-MM-DD/<source>/…`.

3. **Cleanup Phase**

   * Purge `working/YYYY-MM-DD/`.
   * Delete history older than `RETENTION_DAYS`.

4. **Logging**

   * Append events to `backup-smart.log`.
   * Rotate logs older than `LOG_ROTATION_DAYS` and remove `.old` files older than `ROTATED_RETENTION_DAYS`.

---

## Scheduling with systemd

### Service Unit: `backup-smart.service`

```ini
[Unit]
Description=Run backup-smart.sh

[Service]
Type=oneshot
ExecStart=%h/.local/scripts/backup-smart/backup-smart.sh
```

### Timer: `backup-smart.timer` (every 3 hours)

```ini
[Unit]
Description=Run backup-smart every 3 hours

[Timer]
OnBootSec=10min
OnUnitActiveSec=3h
Persistent=true

[Install]
WantedBy=timers.target
```

### Timer: `backup-smart-onboot.timer` (post-boot)

```ini
[Unit]
Description=Run backup-smart shortly after boot/login

[Timer]
OnBootSec=10min
AccuracySec=1min
Persistent=true

[Install]
WantedBy=timers.target
```

---

## Accessing Logs

The `backup-smart` system writes detailed logs to a local log file. You can view and monitor these logs in several ways:

### Log File Location

* **Main log:**

  ```bash
  ~/.local/logs/backup-smart.log
  ```
* **Rotated logs:**

  ```bash
  ~/.local/logs/backup-smart.log.YYYY-MM-DD.old
  ```

### Viewing Logs Manually

* **Open with `less`:**

  ```bash
  less ~/.local/logs/backup-smart.log
  ```
* **Follow in real‑time:**

  ```bash
  tail -f ~/.local/logs/backup-smart.log
  ```

### Checking Systemd Journal (User)

The service and timer units also emit messages to the user journal:

* **Backup service logs:**

  ```bash
  journalctl --user -u backup-smart.service
  journalctl --user -u backup-smart-onboot.service
  ```
* **Timer events:**

  ```bash
  journalctl --user -u backup-smart.timer
  journalctl --user -u backup-smart-onboot.timer
  ```

Use these commands to diagnose failures, confirm run times, or verify cleanup operations.

## Restoration Guide

To restore a file or folder versioned by date:

1. **Find the date** under `history/modified/YYYY-MM-DD` or `history/deleted/YYYY-MM-DD`.
2. **Copy** the desired file back:

```bash
rclone copy remote:backup/history/modified/2025-05-02/projects/path/to/file.txt \
  ~/projects/path/to/file.txt
```

For deleted files, replace `modified` with `deleted`:

```bash
rclone copy remote:backup/history/deleted/2025-05-02/notes/old_note.md \
  ~/notes/old_note.md
```

---

## Customization & Tips

* Tweak `RETENTION_DAYS` for history retention.
* Use `EXCLUDES` to skip large or unwanted files.
* Monitor log growth and adjust rotation days.
* Ensure your rclone remote has sufficient quota.

---

**Author:** Carlo Capobianchi (bynflow)
**Year:** 2025

