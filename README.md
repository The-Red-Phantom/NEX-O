NEX_O_ENGINE — Total Control Editor (How-To)

A terminal UI for batch-editing and validating scripts in the current directory. It keeps backups, shows color-coded status/permissions, and lets you mass-validate or chmod files without leaving the screen.

TL;DR
cd into the folder with your scripts → chmod +x nexo_engine.sh → ./nexo_engine.sh → use numbers to edit, validate all to check everything, perm <sel> <mode> to fix perms, q to bail.

1) Requirements

OS: GNU/Linux (tested on Bash).
macOS note: stat -c "%a" is GNU-specific; on macOS you’ll need gstat from coreutils or adapt the command.

Tools: bash, find, stat, awk, grep, timeout, readlink, sort, command -v.

Editor: nano by default; respects $EDITOR (e.g., export EDITOR=vim).

2) What it indexes (and what it ignores)

Included: regular, non-hidden files in $PWD (not recursive).

Ignored: directories and dotfiles (anything starting with .).

Tip: If you want recursion or hidden files, that’s a code change—by design it stays shallow to avoid chaos.

3) Safety nets & where stuff goes

Backups: every edit makes a copy at .edit_backups/<filename>-<epoch>.bak

Logs: directory .edit_logs/ is created (currently unused by the script—future expansion).

Status file: .validation_status is created (currently not written—future expansion).

Validation runs code: see §6 (important).

4) Quickstart
