#!/bin/bash

# ┌────────────────────────────────────────────────────────┐
# │  NEX_O_ENGINE – REDPHANTOMOPS's Total Control Editor   │
# └────────────────────────────────────────────────────────┘

EDITOR="nano"
LOG_DIR="$HOME/Nexus/.edit_logs"
BACKUP_DIR="$HOME/Nexus/.edit_backups"
STATUS_FILE="$HOME/Nexus/.validation_status"
mkdir -p "$LOG_DIR" "$BACKUP_DIR"
touch "$STATUS_FILE"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

declare -a files
declare -A status_map
declare -A perm_map

# ---------------------------- helpers ----------------------------
load_status() {
  [[ -f "$STATUS_FILE" ]] || return
  while IFS="," read -r path color; do
    status_map["$path"]="$color"
  done < "$STATUS_FILE"
}

save_status() {
  >"$STATUS_FILE"
  for path in "${!status_map[@]}"; do
    echo "$path,${status_map[$path]}" >>"$STATUS_FILE"
  done
}

get_perm_color() {
  local file="$1"
  local mode exec color
  mode=$(stat -c '%a' "$file" 2>/dev/null)
  exec=0
  [[ -x "$file" ]] && exec=1
  if [[ $mode =~ 77[0-7] ]] || (( mode < 600 )) || (( mode % 10 >= 6 )); then
    color="$RED"
  elif (( exec && mode >= 750 && mode <= 755 )) || ((! exec) && mode >= 640 && mode <= 644); then
    color="$GREEN"
  else
    color="$YELLOW"
  fi
  printf '%s%s%s' "$color" "$mode" "$NC"
}

update_perm() {
  local path="$1"
  local rel="${path#./}"
  perm_map["$rel"]="$(get_perm_color "$path")"
}

find_deadpaths() {
  local file="$1"
  local -a missing=()
  local tok

  while IFS= read -r tok; do
    [[ -e "$tok" ]] || missing+=("$tok")
  done < <(grep -oE '((\./|../|/)[A-Za-z0-9_./-]+)' "$file" 2>/dev/null | sort -u)

  while IFS= read -r tok; do
    [[ "$tok" =~ ^[A-Za-z0-9_-]+$ ]] || continue
    [[ "$tok" =~ ^(if|then|else|elif|fi|for|while|do|done|function|case|esac|select|time|in|echo|exit|return|local)$ ]] && continue
    command -v "$tok" >/dev/null 2>&1 || missing+=("$tok")
  done < <(grep -vE '^[ \t]*#' "$file" | awk '{print $1}' | sort -u)

  printf '%s\n' "${missing[@]}" | sort -u
}

validate_script() {
  local path="$1" rel syntax_ok run_ok missing
  rel="${path#./}"
  syntax_ok=0
  run_ok=0
  missing=""

  if [[ $path == *.sh ]]; then
    bash -n "$path" >/dev/null 2>&1; syntax_ok=$?
    timeout 1 bash "$path" >/dev/null 2>&1; run_ok=$?
    missing=$(find_deadpaths "$path")
  elif [[ $path == *.py ]]; then
    python3 -m py_compile "$path" >/dev/null 2>&1; syntax_ok=$?
    timeout 1 python3 "$path" >/dev/null 2>&1; run_ok=$?
    missing=$(find_deadpaths "$path")
  fi

  if (( syntax_ok != 0 || run_ok != 0 )); then
    status_map["$rel"]="red"
  elif [[ -n "$missing" ]]; then
    status_map["$rel"]="yellow"
  else
    status_map["$rel"]="green"
  fi
}

parse_targets() {
  local spec="$1"; shift
  local -a out=()
  if [[ $spec == all ]]; then
    for i in "${!files[@]}"; do out+=("$i"); done
  elif [[ $spec =~ ^[0-9]+$ ]]; then
    out=("$spec")
  elif [[ $spec =~ ^[0-9]+-[0-9]+$ ]]; then
    IFS='-' read -r a b <<<"$spec"
    for ((i=a; i<=b; i++)); do out+=("$i"); done
  elif [[ $spec =~ ^[0-9]+(,[0-9]+)+$ ]]; then
    IFS=',' read -ra out <<<"$spec"
  fi
  echo "${out[@]}"
}

validate_targets() {
  local ids=($1)
  local i
  for i in "${ids[@]}"; do
    [[ -n ${files[$i]} ]] && validate_script "${files[$i]}"
  done
  save_status
}

change_permissions() {
  local ids mode
  ids=($(parse_targets "$1"))
  mode="$2"
  local i
  for i in "${ids[@]}"; do
    [[ -n ${files[$i]} ]] || continue
    chmod "$mode" "${files[$i]}"
    update_perm "${files[$i]}"
    echo " ${files[$i]} $(stat -c '%a' "${files[$i]}")"
  done
}

show_menu() {
  clear
  echo -e "\n┌────────────────────────────────────────────────────────┐"
  echo -e "│  NEX_O_ENGINE – REDPHANTOMOPS's Total Control Editor   │"
  echo -e "└────────────────────────────────────────────────────────┘"
  echo " Directory: $(pwd)"
  echo " Files found: ${#files[@]}"
  echo
  local i path rel color perm color_code
  for i in "${!files[@]}"; do
    path="${files[$i]}"
    rel="${path#./}"
    color="${status_map[$rel]}"
    case "$color" in
      red) color_code="$RED" ;;
      yellow) color_code="$YELLOW" ;;
      green) color_code="$GREEN" ;;
      *) color_code="$NC" ;;
    esac
    perm="${perm_map[$rel]}"
    echo -e " [${color_code}$i${NC}] $rel $perm"
  done
  echo -e "\nCommands:"
  echo " [#]      - Edit file by number"
  echo " n        - Next unedited file"
  echo " b        - Back to previous file"
  echo " validate <#|all> - Validate script(s)"
  echo " perm <targets> <mode> - Change permissions"
  echo " q        - Quit editor"
  echo
}

build_files() {
  mapfile -t files < <(find . -maxdepth 1 -type f \
    \( -iname "*.sh" -o -iname "*.py" -o -iname "*.json" -o -iname "*.conf" -o -iname "*.cfg" -o -iname "*.txt" \) | sort)
}

init_permissions() {
  local f
  for f in "${files[@]}"; do
    update_perm "$f"
  done
}

main_loop() {
  local index=0 last_index=-1 choice path target mode ids
  while true; do
    show_menu
    read -rp "Choose: " choice
    case "$choice" in
      [0-9]*)
        last_index="$index"
        index="$choice"
        path="${files[$index]}"
        validate_script "$path"
        "$EDITOR" "$path"
        update_perm "$path"
        validate_script "$path"
        save_status
        ;;
      n)
        last_index="$index"
        ((index++))
        ((index >= ${#files[@]})) && index=0
        path="${files[$index]}"
        validate_script "$path"
        "$EDITOR" "$path"
        update_perm "$path"
        validate_script "$path"
        save_status
        ;;
      b)
        index="$last_index"
        path="${files[$index]}"
        validate_script "$path"
        "$EDITOR" "$path"
        update_perm "$path"
        validate_script "$path"
        save_status
        ;;
      validate\ *)
        target="${choice#validate }"
        ids=($(parse_targets "$target"))
        validate_targets "${ids[*]}"
        ;;
      perm\ *)
        target="${choice#perm }"
        mode="${target##* }"
        target="${target% $mode}"
        change_permissions "$target" "$mode"
        ;;
      q)
        save_status
        echo "Exiting NEX_O_ENGINE. Stay sharp, GhostSmith."
        exit 0
        ;;
    esac
  done
}

build_files
load_status
init_permissions
main_loop

