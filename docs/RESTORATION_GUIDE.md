# Restoration Guide

If you accidentally delete or modify files locally, you can recover them from your remote backup. Follow these steps:

1. **Locate the Backup Root**
   Your backup is stored under a generic remote called `backup`, with this structure:

   ```
   backup/
   ├── projects/                # your main synced directories
   ├── history/
   │   ├── modified/
   │   │   ├── YYYY-MM-DD/      # previous versions of modified files
   │   │   │   └── ...
   │   └── deleted/
   │       ├── YYYY-MM-DD/      # files removed on that date
   │       │   └── ...
   └── ...
   ```

2. **Restoring a Single File**

   * Find the date folder under `backup/history/modified` or `backup/history/deleted` matching when the change occurred.
   * Copy the file back to your local workspace. For example:

     ```bash
     cp ~/remote/backup/history/modified/2025-05-02/projects/report.docx ~/projects/report.docx
     ```

3. **Restoring an Entire Directory**
   Use `rsync` to pull back a full folder. For example:

   ```bash
   rsync -av ~/remote/backup/history/deleted/2025-05-01/projects/old-project/ ~/projects/old-project/
   ```

4. **Verify**
   After copying, check that files open correctly and data is intact.

5. **Customize Paths**

   * Replace `~/projects` with your actual local base directory.
   * Replace `~/remote/backup` with your actual remote mount or alias.

By following this guide, you’ll safely restore any file or folder version managed by your smart backup system.

