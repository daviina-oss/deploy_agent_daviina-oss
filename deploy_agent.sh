#!/usr/bin/env bash
# Deploying, running, and archiving the Student Attendance Tracker.
set -Eeuo pipefail

BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$BASE_DIR/templates"
PROJECT_DIR=""
PROJECT_NAME=""
DEPLOYING=false

message_error() { printf 'ERROR: %s\n' "$*" >&2; }

require_tools() {
    local tool
    for tool in python3 zip; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            message_error "Missing required command: $tool"
            return 1
        fi
    done
    python3 --version
}

require_templates() {
    local name
    for name in attendance_checker.py config.json assets.csv; do
        if [[ ! -f "$TEMPLATE_DIR/$name" ]]; then
            message_error "Missing template: $TEMPLATE_DIR/$name"
            return 1
        fi
    done
}

# Archiving and cleaning up only a project created by this deployment.
interrupt_deploy() {
    local signal="$1" archive
    trap - INT TSTP
    printf '\nDeployment interrupted by %s.\n' "$signal" >&2
    if [[ "$DEPLOYING" == true && -d "$PROJECT_DIR" ]]; then
        archive="$BASE_DIR/${PROJECT_NAME}_archive.zip"
        if [[ -e "$archive" ]]; then
            archive="$BASE_DIR/${PROJECT_NAME}_archive_$(date +%Y%m%d_%H%M%S).zip"
        fi
        if (cd "$BASE_DIR" && zip -qr "$archive" "$PROJECT_NAME"); then
            printf 'Backup created: %s\n' "$archive" >&2
            if rm -rf -- "$PROJECT_DIR"; then
                printf 'Incomplete project directory removed.\n' >&2
            else
                message_error "Backup saved, but cleanup failed: $PROJECT_DIR"
                exit 1
            fi
        else
            message_error "ZIP failed; incomplete directory retained: $PROJECT_DIR"
            exit 1
        fi
    fi
    exit 130
}

# Reading a whole number within an inclusive range.
read_number() {
    local label="$1" minimum="$2" maximum="$3" answer
    while true; do
        read -r -p "$label" answer || return 1
        if [[ "$answer" =~ ^[0-9]+$ ]] &&
           (( ${#answer} <= 9 )) &&
           (( 10#$answer >= minimum && 10#$answer <= maximum )); then
            REPLY="$((10#$answer))"
            return 0
        fi
        printf 'Enter a whole number from %s to %s.\n' "$minimum" "$maximum"
    done
}

# Replacing one numeric JSON value without reformatting the file.
set_json_number() {
    local file="$1" key="$2" value="$3"
    sed -i -E "s/(\"${key}\"[[:space:]]*:[[:space:]]*)[0-9]+/\1${value}/" "$file"
}

choose_project() {
    local suffix
    read -r -p 'Project suffix (letters, numbers, _ or -): ' suffix
    if [[ ! "$suffix" =~ ^[A-Za-z0-9_-]+$ ]]; then
        message_error 'Invalid suffix. Use letters, numbers, underscore or hyphen.'
        return 1
    fi
    PROJECT_NAME="attendance_tracker_${suffix}"
    PROJECT_DIR="$BASE_DIR/$PROJECT_NAME"
}

deploy() {
    local choice count total template_count name email i
    local -a names=("Alex Kim" "Bela Smith" "Chris Lee" "Dana Cole" "Eli Noor"
                    "Fran Mensah" "Gina Patel" "Hugo Wang" "Iris Osei" "Jules Park")
    local -a emails=("alex@example.com" "bela@example.com" "chris@example.com"
                     "dana@example.com" "eli@example.com" "fran@example.com"
                     "gina@example.com" "hugo@example.com" "iris@example.com"
                     "jules@example.com")

    require_tools || return 1
    require_templates || return 1
    choose_project || return 1
    if [[ -e "$PROJECT_DIR" ]]; then
        message_error "Already exists: $PROJECT_DIR (deployment aborted; no files overwritten)."
        return 1
    fi
    # Trapping both signals during directory creation and configuration.
    trap 'interrupt_deploy SIGINT' INT
    trap 'interrupt_deploy SIGTSTP' TSTP
    DEPLOYING=true
    mkdir -p -- "$PROJECT_DIR/Helpers" "$PROJECT_DIR/reports"
    cp -- "$TEMPLATE_DIR/attendance_checker.py" "$PROJECT_DIR/attendance_checker.py"
    cp -- "$TEMPLATE_DIR/config.json" "$PROJECT_DIR/Helpers/config.json"

    printf 'Roster options: A) copy from template, B) generate new\n'
    while true; do
        read -r -p 'Select A or B: ' choice
        choice="${choice^^}"
        [[ "$choice" == A || "$choice" == B ]] && break
        printf 'Please choose A or B.\n'
    done

    if [[ "$choice" == A ]]; then
        template_count="$(awk 'END {print NR-1}' "$TEMPLATE_DIR/assets.csv")"
        if (( template_count < 1 )); then
            message_error 'Template roster has no students.'
            return 1
        fi
        read_number "Students to copy (1-$template_count): " 1 "$template_count"
        count="$REPLY"
        head -n "$((count + 1))" "$TEMPLATE_DIR/assets.csv" > \
            "$PROJECT_DIR/Helpers/assets.csv"
        total=5
    else
        read_number 'Students to generate (1-10): ' 1 10
        count="$REPLY"
        printf 'Email,Names,Attendance Count,Absence Count\n' > \
            "$PROJECT_DIR/Helpers/assets.csv"
        for ((i = 0; i < count; i++)); do
            name="${names[i]}"
            email="${emails[i]}"
            printf '%s,%s,0,0\n' "$email" "$name" >> \
                "$PROJECT_DIR/Helpers/assets.csv"
        done
        total=1
    fi
    set_json_number "$PROJECT_DIR/Helpers/config.json" total_sessions "$total"
    chmod +x -- "$PROJECT_DIR/attendance_checker.py"
    chmod 600 -- "$PROJECT_DIR/Helpers/config.json"
    printf 'Permissions: attendance_checker.py executable; config.json owner read/write (600).\n'

    while true; do
        read -r -p 'Update warning/failure thresholds? (y/n): ' choice
        case "${choice,,}" in
            y|yes)
                read_number 'Warning threshold (0-100, default 75): ' 0 100
                local warning="$REPLY"
                read_number 'Failure threshold (0-100, default 50): ' 0 100
                local failure="$REPLY"
                if (( failure > warning )); then
                    printf 'Failure threshold cannot exceed warning threshold.\n'
                    continue
                fi
                set_json_number "$PROJECT_DIR/Helpers/config.json" warning "$warning"
                set_json_number "$PROJECT_DIR/Helpers/config.json" failure "$failure"
                break ;;
            n|no) break ;;
            *) printf 'Enter y or n.\n' ;;
        esac
    done
    printf 'Deployment complete: %s (%s students, session %s).\n' \
        "$PROJECT_DIR" "$count" "$total"

    # Disabling deployment traps before handing control to Python.
    DEPLOYING=false
    trap - INT TSTP
    printf 'Starting the application to verify deployment...\n'
    run_project "$PROJECT_DIR"
}

# Resolving an existing deployed directory, without accepting paths outside the repo.
select_existing_project() {
    local suffix
    read -r -p 'Existing project suffix: ' suffix
    if [[ ! "$suffix" =~ ^[A-Za-z0-9_-]+$ ]]; then
        message_error 'Invalid suffix.'
        return 1
    fi
    PROJECT_DIR="$BASE_DIR/attendance_tracker_${suffix}"
    if [[ ! -f "$PROJECT_DIR/attendance_checker.py" ||
          ! -f "$PROJECT_DIR/Helpers/config.json" ||
          ! -f "$PROJECT_DIR/Helpers/assets.csv" ]]; then
        message_error "Incomplete or missing project: $PROJECT_DIR"
        return 1
    fi
}

run_project() {
    local dir="$1" exit_code=0
    # Keeping the instructor's terminal attached to interactive Python.
    (cd -- "$dir" && python3 attendance_checker.py) || exit_code=$?
    if (( exit_code != 0 )); then
        message_error "Application exited with status $exit_code"
        return "$exit_code"
    fi
}

archive_logs() {
    local timestamp log source destination type
    local found=0
    select_existing_project || return 1
    mkdir -p -- "$PROJECT_DIR/archives/attendance" \
                "$PROJECT_DIR/archives/absent"
    timestamp="$(date +%Y%m%d_%H%M%S)"
    # Avoiding accidental overwrites if archiving twice in one second.
    while [[ -e "$PROJECT_DIR/archives/attendance/attendance_${timestamp}.log" ||
             -e "$PROJECT_DIR/archives/absent/absent_${timestamp}.log" ]]; do
        sleep 1
        timestamp="$(date +%Y%m%d_%H%M%S)"
    done
    for type in attendance absent; do
        source="$PROJECT_DIR/reports/${type}.log"
        destination="$PROJECT_DIR/archives/$type/${type}_${timestamp}.log"
        if [[ -f "$source" ]]; then
            cp -- "$source" "$destination"
            printf 'Archived: %s\n' "$destination"
            found=1
        else
            printf 'Not found (skipped): %s\n' "$source"
        fi
    done
    if (( found == 0 )); then
        printf 'No logs were available to archive.\n'
    fi
}

main() {
    local choice
    printf '\nStudent Attendance Tracker Deployment Agent\n'
    printf '1) Deploy  2) Run  3) Archive logs  4) Exit\n'
    read -r -p 'Choose an option: ' choice || return 1
    case "$choice" in
        1) deploy ;;
        2) require_tools && select_existing_project && run_project "$PROJECT_DIR" ;;
        3) command -v zip >/dev/null 2>&1 || {
               message_error 'Missing zip command'; return 1;
           }
           archive_logs ;;
        4) printf 'Goodbye.\n' ;;
        *) message_error 'Choose 1, 2, 3, or 4.'; return 1 ;;
    esac
}

main "$@"
