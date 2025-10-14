#!/usr/bin/env python3
import sys, json, signal
from collections import defaultdict

# pid -> [syscall numbers]
seq = defaultdict(list)
# pid -> comm (best-known)
comm = {}

def flush_pid(pid, reason="exit"):
    s = seq.get(pid)
    if not s:
        return
    name = comm.get(pid, "?")
    # print one ADFA-style line per process (space-separated numbers)
    print(f"{pid}\t{name}\t" + " ".join(map(str, s)))
    # clean up
    seq.pop(pid, None)
    comm.pop(pid, None)

def flush_all(reason="eof"):
    for pid in list(seq.keys()):
        flush_pid(pid, reason=reason)

def on_sigint(sig, frame):
    flush_all("sigint")
    sys.exit(0)

signal.signal(signal.SIGINT, on_sigint)

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
    except json.JSONDecodeError:
        # ignore bad lines
        continue

    pid = obj.get("pid")
    if pid is None:
        continue

    t = obj.get("type")
    if t == "enter":
        # record syscall number
        sc = obj.get("syscall")
        if sc is None:
            continue
        try:
            sc = int(sc)
        except Exception:
            continue
        seq[pid].append(sc)
        # remember comm (first seen or latest)
        if "comm" in obj:
            comm[pid] = obj["comm"]
    elif t == "exit":
        flush_pid(pid, reason="exit")

# EOF: flush whatever's left
flush_all("eof")
