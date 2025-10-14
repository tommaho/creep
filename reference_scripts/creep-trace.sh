# LLM generated code (GPT-5)

#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 [-a] [-u UID] [-s SERVICE] [-p PID] [--out FILE]"
  echo "Examples:"
  echo "  $0 -a"
  echo "  $0 -u 1000"
  echo "  $0 -p 4242"
  echo "  $0 -s ssh.service      # Debian/Ubuntu"
  echo "  $0 -s sshd.service     # RHEL/Fedora"
  exit 1
}

mode="all"; uid=""; service=""; pid=""; outfile=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -a) mode="all"; shift ;;
    -u) mode="uid"; uid="${2?UID required}"; shift 2 ;;
    -s) mode="service"; service="${2?SERVICE required}"; shift 2 ;;
    -p) mode="pid"; pid="${2?PID required}"; shift 2 ;;
    --out) outfile="${2?FILE required}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

# Build FILTER_ENTER / FILTER_EXIT (bpftrace exprs)
build_filters() {
  case "$mode" in
    all)
      F_ENTER="1"; F_EXIT="1"
      ;;
    uid)
      F_ENTER="uid == $uid"; F_EXIT="$F_ENTER"
      ;;
    pid)
      F_ENTER="pid == $pid"; F_EXIT="$F_ENTER"
      ;;
    service)
      # Try ControlGroup first (cgroup v2 path). Example: /system.slice/ssh.service
      cgpath=$(systemctl show -p ControlGroup --value "$service" 2>/dev/null || true)
      if [[ -n "$cgpath" && -d "/sys/fs/cgroup$cgpath" ]]; then
        cgid=$(stat -Lc '%i' "/sys/fs/cgroup$cgpath")
        F_ENTER="cgroup == $cgid"; F_EXIT="$F_ENTER"
      else
        # Fallback: PID list (works on any cgroup mode)
        # systemd >= 249 provides PIDs= (space-separated). Else use MainPID.
        pids=$(systemctl show -p PIDs --value "$service" 2>/dev/null || true)
        if [[ -z "$pids" ]]; then
          mpid=$(systemctl show -p MainPID --value "$service" 2>/dev/null || true)
          pids="$mpid"
        fi
        # Build OR chain
        or_chain=""
        for p in $pids; do
          [[ "$p" =~ ^[0-9]+$ ]] || continue
          if [[ -z "$or_chain" ]]; then or_chain="pid == $p"
          else or_chain="$or_chain || pid == $p"
          fi
        done
        if [[ -z "$or_chain" ]]; then
          echo "Could not resolve cgroup or PIDs for service '$service'." >&2
          exit 1
        fi
        F_ENTER="($or_chain)"; F_EXIT="$F_ENTER"
      fi
      ;;
  esac
}

build_filters

# Two tracepoints total; fields via args->id / args->ret
bt_prog=$(cat <<'EOF'
tracepoint:raw_syscalls:sys_enter /FILTER_ENTER/ {
  printf("{\"t\":%lld", nsecs);
  printf(",\"ph\":\"e\"");
  printf(",\"pid\":%d", pid);
  printf(",\"uid\":%d", uid);
  printf(",\"sid\":%d", args->id);
  printf(",\"comm\":\"%s\"}\n", comm);
}
tracepoint:raw_syscalls:sys_exit /FILTER_EXIT/ {
  printf("{\"t\":%lld", nsecs);
  printf(",\"ph\":\"x\"");
  printf(",\"pid\":%d", pid);
  printf(",\"uid\":%d", uid);
  printf(",\"sid\":%d", args->id);
  printf(",\"ret\":%lld", args->ret);
  printf(",\"comm\":\"%s\"}\n", comm);
}
EOF
)

# splice filters in
bt_prog="${bt_prog//FILTER_ENTER/$F_ENTER}"
bt_prog="${bt_prog//FILTER_EXIT/$F_EXIT}"

if [[ -n "$outfile" ]]; then
  sudo bpftrace -e "$bt_prog" | tee "$outfile"
else
  sudo bpftrace -e "$bt_prog"
fi
