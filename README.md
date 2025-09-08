# NEX_O_ENGINE  
**RedPhantomOps Total Control Editor**

> *“Trust in Code. Hope for Humanity. Legendary in ALL things.”*  
> ᛏᛁᛚᛚ ᚢᛚᚢᛋᚷᚨᚱᛞᚱ ᚨᚾᛞ ᛒᛖᛁᛟᚾᛞ  

---

## ⚡ What is NEX_O_ENGINE?

A terminal-based editor and validator built for the **NEX_O repo**.  
It indexes scripts in your current working directory, color-codes their health, validates syntax and runtime, manages backups, and lets you chmod or edit without leaving the tool.

Think of it as a **control room**: fast edits, quick diagnostics, and safety rails.

---

## 🛠 Requirements

- **Linux** (tested on Kali/Debian; macOS needs `gstat` from `coreutils`)  
- **Bash** 5+  
- Utilities: `find`, `stat`, `awk`, `grep`, `timeout`, `readlink`, `sort`, `command -v`  
- Text editor: defaults to `nano`, but respects `$EDITOR` (set it to `vim`, `micro`, `code -w`, etc.)

---

## 🚀 Getting Started

```bash
# 1. Make it executable
chmod +x nexo_engine.sh

# 2. Set your editor (optional)
export EDITOR=vim

# 3. Run it in your repo root
./nexo_engine.sh

📂 What it Scans

    Includes: regular, non-hidden files in the current directory ($PWD)

    Ignores: directories and dotfiles

Backups and logs are auto-created:

    .edit_backups/ → per-file timestamped .bak copies

    .edit_logs/ → placeholder for log history (future use)

    .validation_status → placeholder status tracker

🧭 Menu Overview

When you launch, you’ll see:

    ID → number to select/edit a file

    File → basename of the script

    Perm → permission bits, color-coded

    Status (ID color):

        🟢 GREEN → syntax good, runs in <5s, no missing deps/paths

        🟡 YELLOW → runs, but references missing commands/paths

        🔴 RED → syntax error, failed, or timed out

        ⚪ NC → not validated (rare, since startup scans all)

🎮 Commands
Command	Action
[ID]	Edit file by index (backup made first)
n	Edit next file
b	Edit previous file
validate <sel> / v <sel>	Validate file(s)
perm <sel> <mode> / p <sel> <mode>	Change permissions (chmod)
q	Validate all, exit gracefully
🎯 Selectors Cheat-Sheet

Selectors let you target one, many, or all files:

validate all
validate 0
validate 0,2,5
validate 3-7
validate 0,3-5,8

perm all 644
perm 0,2,5 755
perm 3-7 750

🔍 Validation Details

Every validation step does:

    Syntax check → bash -n file
    Fail = RED

    Runtime probe (5s) → timeout 5 bash file
    Fail/timeout = RED
    ⚠️ Note: this executes your script. Sandbox destructive ones or comment this out.

    Dead-path/dependency check → flags missing commands or non-existent /paths.
    If found = YELLOW

🧾 Permission Colors

    🟢 GREEN → exec files 750–755 OR non-execs 640–644

    🟡 YELLOW → anything else, not risky but not ideal

    🔴 RED → perms <600, 077x, or suspicious owner bits

🕹 Example Workflows

Fix a broken script

./nexo_engine.sh
# look for [RED]
2        # edit file #2
# save + quit

Harden permissions across repo

p all 644
p 0,2,5 755

Check everything for missing deps

v all

⚠ Known Quirks

    Not recursive. Only the current folder is scanned.

    Hidden files ignored on purpose.

    Validation executes scripts — handle with care.

    .edit_logs and .validation_status are placeholders for expansion.

🗺 Roadmap (future upgrades)

    --dry-validate flag (no execution).

    Recursive scan mode with depth control.

    Proper status/logging to .edit_logs/.

    Per-file tagging & search.

    Execution sandbox / preview mode.
