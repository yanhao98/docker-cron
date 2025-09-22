#!/bin/sh
set -u

CRON_TASKS_DIR="${CRON_TASKS_DIR:-/docker-cron.d}"
STDOUT_FD="/proc/1/fd/1"
STDERR_FD="/proc/1/fd/2"

readonly CRON_TASKS_DIR STDOUT_FD STDERR_FD

log_info() {
  printf '%s\n' "run-cron-tasks: $*"
}

log_error() {
  printf '%s\n' "run-cron-tasks: $*" >&2
}

if [ ! -d "$CRON_TASKS_DIR" ]; then
  log_info "tasks directory $CRON_TASKS_DIR not found; skipping"
  exit 0
fi

run_started_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
log_info "===== cron run started $run_started_at ====="

set -- "$CRON_TASKS_DIR"/*
if [ "$1" = "$CRON_TASKS_DIR/*" ]; then
  log_info "no task scripts found in $CRON_TASKS_DIR"
  run_finished_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  log_info "===== cron run finished $run_finished_at (exit 0) ====="
  exit 0
fi

max_rc=0
for task in "$@"; do
  if [ ! -f "$task" ]; then
    log_info "skipping non-regular entry $task"
    continue
  fi

  task_name=$(basename "$task")
  log_info "starting task $task_name"

  if [ ! -x "$task" ]; then
    if ! chmod +x "$task" 2>>"$STDERR_FD"; then
      log_error "failed to chmod +x $task_name"
      if [ "$max_rc" -lt 1 ]; then
        max_rc=1
      fi
      continue
    fi
  fi

  if "$task" >>"$STDOUT_FD" 2>>"$STDERR_FD"; then
    rc=0
    log_info "task $task_name completed successfully"
  else
    rc=$?
    log_error "task $task_name exited with status $rc"
  fi

  if [ "$rc" -gt "$max_rc" ]; then
    max_rc=$rc
  fi
done

run_finished_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
log_info "===== cron run finished $run_finished_at (exit $max_rc) ====="
exit "$max_rc"
