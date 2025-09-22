#!/bin/sh
set -eu

log_info() {
  printf '%s\n' "cron-entrypoint: $*"
}

log_error() {
  printf '%s\n' "cron-entrypoint: $*" >&2
}

if ! set -o pipefail 2>/dev/null; then
  log_info "shell does not support pipefail; continuing without it"
fi

CRON_SCHEDULE="${CRON_SCHEDULE:-*/30 * * * *}"
INIT_SCRIPTS_DIR="${INIT_SCRIPTS_DIR:-/docker-entrypoint-init.d}"
CRON_TASKS_DIR="${CRON_TASKS_DIR:-/docker-cron.d}"
APK_PACKAGES="${APK_PACKAGES:-}"

STDOUT_FD="/proc/1/fd/1"
STDERR_FD="/proc/1/fd/2"
CRON_SCRIPT="/usr/local/bin/run-cron-tasks.sh"

readonly CRON_SCHEDULE INIT_SCRIPTS_DIR CRON_TASKS_DIR APK_PACKAGES STDOUT_FD STDERR_FD CRON_SCRIPT

if [ -z "$CRON_SCHEDULE" ]; then
  log_error "CRON_SCHEDULE is empty; refusing to start."
  exit 1
fi

mkdir -p /var/spool/cron/crontabs "$INIT_SCRIPTS_DIR" "$CRON_TASKS_DIR"

if [ -n "$APK_PACKAGES" ]; then
  log_info "ensuring apk packages: $APK_PACKAGES"
  # shellcheck disable=SC2086
  if ! wget -qO- https://Git.1-H.CC/Scripts/Linux/raw/branch/main/ensure-apk-packages.sh | \
    sh -s -- $APK_PACKAGES; then
    log_error "failed to install requested apk packages"
    exit 1
  fi
else
  log_info "no additional apk packages requested"
fi

log_info "starting initialization from $INIT_SCRIPTS_DIR"
set -- "$INIT_SCRIPTS_DIR"/*
if [ "$1" = "$INIT_SCRIPTS_DIR/*" ]; then
  log_info "no initialization scripts found"
else
  for script in "$@"; do
    if [ ! -f "$script" ]; then
      log_info "skipping non-regular entry $script"
      continue
    fi

    script_name=$(basename "$script")
    log_info "running initialization script $script_name"
    if [ -x "$script" ]; then
      if ! "$script" >>"$STDOUT_FD" 2>>"$STDERR_FD"; then
        log_error "initialization script $script_name failed"
        exit 1
      fi
    else
      if ! /bin/sh "$script" >>"$STDOUT_FD" 2>>"$STDERR_FD"; then
        log_error "initialization script $script_name failed"
        exit 1
      fi
    fi
  done
fi

log_info "initialization complete"

cron_env_file=/var/spool/cron/crontabs/root
{
  printf 'SHELL=/bin/sh\n'
  printf 'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n'
  printf 'CRON_TASKS_DIR=%s\n' "$CRON_TASKS_DIR"
  printf '%s %s\n' "$CRON_SCHEDULE" "$CRON_SCRIPT >> $STDOUT_FD 2>> $STDERR_FD"
} >"$cron_env_file"
chmod 0600 "$cron_env_file"

log_info "starting crond with schedule '$CRON_SCHEDULE'"
exec crond -f
