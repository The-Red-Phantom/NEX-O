#!/bin/bash

# ===== CONFIG =====

EDITOR="${EDITOR:-nano}"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
COREDIR="$PWD"

LOG_DIR="$COREDIR/.edit_logs"
BACKUP_DIR="$COREDIR/.edit_backups"
STATUS_FILE="$COREDIR/.validation_status"
mkdir -p "$LOG_DIR" "$BACKUP_DIR"
touch "$STATUS_FILE"


# ===== COLORS =====
RED="\033[0;31m"
YELLOW="\033[0;33m"
GREEN="\033[0;32m"
NC="\033[0m"

# ===== FILE INDEXING =====
# Only include regular files to avoid issues when attempting to edit
# directories. This prevents commands like "n" or selecting a numbered
# entry from trying to open a directory in the editor which previously
# caused errors.
mapfile -t files < <(find "$COREDIR" -maxdepth 1 -type f ! -name '.*' | sort)
file_count="${#files[@]}"
declare -A status_map
declare -A perm_map

# ===== PERMISSION HELPERS =====
get_perm() { stat -c "%a" "$1"; }

perm_color() {
  local file="$1" perm="$2" code="$YELLOW"
  local exec=0
  [[ -x "$file" ]] && exec=1
  local o=${perm:0:1} g=${perm:1:1} u=${perm:2:1}
  if (( perm < 600 )) || [[ $perm =~ ^77[0-7]$ ]] || [[ $u =~ [2367] ]]; then
    code="$RED"
  elif { [[ $exec -eq 1 && $perm -ge 750 && $perm -le 755 ]] || [[ $exec -eq 0 && $perm -ge 640 && $perm -le 644 ]]; }; then
    code="$GREEN"
  fi
  printf "%b%s%b" "$code" "$perm" "$NC"
}

update_perm() {
  local idx="$1"
  local file="${files[$idx]}"
  local base
  [[ ! -e "$file" ]] && return
  base="$(basename "$file")"
  perm_map[$base]="$(perm_color "$file" "$(get_perm "$file")")"
}

# ===== VALIDATION =====
scan_deadpaths() {
  local file="$1" missing=0
  local keywords="if then else fi for while do done case esac select until time in { } [[ ]] function"
  while read -r cmd; do
    [[ " $keywords " == *" $cmd "* ]] && continue
    command -v "$cmd" >/dev/null 2>&1 || missing=1
  done < <(grep -v '^\s*#' "$file" | awk '{print $1}' | grep -E '^[A-Za-z0-9_./-]+$' | sort -u)
  while read -r path; do
    [[ -e "$path" ]] || missing=1
  done < <(grep -oE '(/[^ "\047]+)' "$file" | sort -u)
  return $missing
}

validate_file() {
  local idx="$1"
  local file="${files[$idx]}"
  local base status
  base="$(basename "$file")"
  if ! bash -n "$file" >/dev/null 2>&1; then
    status="RED"
  elif ! timeout 5 bash "$file" >/dev/null 2>&1; then
    status="RED"
  elif ! scan_deadpaths "$file"; then
    status="YELLOW"
  else
    status="GREEN"
  fi
  status_map[$base]="$status"
  update_perm "$idx"
}

validate_targets() {
  local spec="$1" idxs=( $(parse_indexes "$spec") )
  for i in "${idxs[@]}"; do
    validate_file "$i"
    echo "$(basename "${files[$i]}"): ${status_map[$(basename "${files[$i]}")]}"
  done
}

# ===== INDEX PARSING =====
parse_indexes() {
  local spec="$1" out=()
  if [[ "$spec" == "all" ]]; then
    out=("${!files[@]}")
  else
    IFS=',' read -ra parts <<< "$spec"
    for part in "${parts[@]}"; do
      if [[ $part =~ ^[0-9]+-[0-9]+$ ]]; then
        local start=${part%-*} end=${part#*-}
        for ((i=start; i<=end; i++)); do
          (( i >=0 && i < file_count )) && out+=("$i")
        done
      elif [[ $part =~ ^[0-9]+$ ]]; then
        (( part >=0 && part < file_count )) && out+=("$part")
      fi
    done
  fi
  echo "${out[@]}"
}

# ===== PERMISSION CHANGES =====
perm_targets() {
  local spec="$1" mode="$2" idxs=( $(parse_indexes "$spec") )
  for i in "${idxs[@]}"; do
    local f="${files[$i]}" base
    [[ -e "$f" ]] || continue
    chmod "$mode" "$f"
    update_perm "$i"
    base="$(basename "$f")"
    echo "$base: ${perm_map[$base]}"
  done
}

# ===== EDIT HELPER =====
edit_file() {
  local idx="$1"
  local file="${files[$idx]}"
  [[ -e "$file" ]] || { echo "Invalid selection."; return; }
  cp "$file" "$BACKUP_DIR/$(basename "$file")-$(date +%s).bak"
  validate_file "$idx"
  "$EDITOR" "$file"
  validate_file "$idx"
}

# ===== MENU =====
show_menu() {
  clear
  echo -e "\n┌────────────────────────────────────────────────────────┐"
  echo -e "│  NEX_O_ENGINE – REDPHANTOMOPS's Total Control Editor   │"
  echo -e "└────────────────────────────────────────────────────────┘"
  echo " Directory: $COREDIR"
  echo " Files found: $file_count"
  echo
  printf " %-4s %-40s %-7s\n" "ID" "File" "Perm"
  echo " -------------------------------------------------------------"
  for i in "${!files[@]}"; do
    local path="${files[$i]}" base status code perm
    base="$(basename "$path")"
    status="${status_map[$base]:-NC}"
    case "$status" in
      GREEN) code="$GREEN" ;;
      YELLOW) code="$YELLOW" ;;
      RED) code="$RED" ;;
      *) code="$NC" ;;
    esac
    perm="${perm_map[$base]}"
    printf " [${code}%2d${NC}] %-40s %s\n" "$i" "$base" "$perm"
  done
  echo -e "\nCommands:"
  echo "  [#]                 - Edit file by number"
  echo "  n                   - Next file"
  echo "  b                   - Back to previous file"
  echo "  validate <#|all>    - Validate file or all files"
  echo "  perm <sel> <mode>   - Change permissions (sel: index,list,range,all)"
  echo "  q                   - Quit editor"
  echo
}

# ===== MAIN LOOP =====
for i in "${!files[@]}"; do
  validate_file "$i"
done

index=0
last_index=0

while true; do
  show_menu
  read -rp "Choose: " choice
  case "$choice" in
    [0-9]*)
      if [[ "$choice" -ge 0 && "$choice" -lt "$file_count" ]]; then
        last_index="$index"
        index="$choice"
        edit_file "$index"
      else
        echo "Invalid index: $choice"
      fi
      ;;
    n)
      last_index="$index"
      ((index++))
      ((index >= file_count)) && index=0
      edit_file "$index"
      ;;
    b)
      index="$last_index"
      edit_file "$index"
      ;;
    validate\ *|v\ *)
      validate_targets "${choice#* }"
      ;;
    perm\ *|p\ *)
      args=(${choice#* })
      [[ ${#args[@]} -eq 2 ]] && perm_targets "${args[0]}" "${args[1]}"
      ;;
    q)
      for i in "${!files[@]}"; do
        validate_file "$i"
      done
      echo -e "\nExiting NEX_O_ENGINE. Stay sharp, $USER"
      exit 0
      ;;
    *)
      echo "Invalid input. Try again."
      ;;
  esac
  # Pause to allow the user to view any output before the screen is
  # refreshed on the next loop iteration. Without this pause the menu
  # was immediately redrawn, making it seem like commands such as
  # "validate" or "perm" did nothing.
  read -rp "Press Enter to continue..." _
done
