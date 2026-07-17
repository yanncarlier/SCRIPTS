# Built-In Linux Tools (Summary)

Source: [The Built-In Linux Tools I Wish Someone Had Shown Me Earlier](https://medium.com/@fatihaali093/the-built-in-linux-tools-i-wish-someone-had-shown-me-earlier-4621005dffa9) — Fateyaly, Medium

Premise: you don't need dozens of third-party utilities to be productive on Linux — many essential troubleshooting/debugging/investigation tools already ship with the OS. They all **observe** the system without modifying it.

## `ss` — inspect the network stack
Faster, richer replacement for `netstat`; talks to the kernel via Netlink instead of parsing `/proc`.

```bash
ss -tulpn      # listening services overview
ss -ant        # established TCP sessions
```
Useful for: unexpected outbound connections, service verification, connection leaks, incident response.

## `lsof` — everything is a file
Exposes file descriptors held by processes (sockets, pipes, devices, directories, libraries).

```bash
lsof -p <PID>       # files opened by a process
lsof -i :443        # process owning a port
lsof | grep deleted # deleted files still held open (disk space leaks)
```

## `journalctl` — structured system logging
Centralized systemd journal instead of hunting through `/var/log`.

```bash
journalctl -u nginx             # logs for a specific service
journalctl --since "30 minutes ago"
journalctl -b                   # current boot
```

## `vmstat` — memory problems rarely look like memory problems
```bash
vmstat 1
```
Key columns:
- `r` — runnable processes
- `b` — blocked processes
- `si` / `so` — swap in / out
- `wa` — I/O wait

High swap activity can mimic CPU saturation but is actually memory pressure.

## `dmesg` — listen to the kernel
```bash
dmesg -T | tail
```
Look for: hardware failures, disk I/O errors, OOM kills, driver issues, filesystem problems, network device resets.

## `find` — more than file search
```bash
find /var/log -mtime -1        # modified in last day
find / -type f -size +500M     # large files
find /home -user alice         # files owned by a user
```

## `xargs` — turn output into workflows
```bash
find . -name "*.log" | xargs grep "ERROR"
find . -type d -empty | xargs rmdir
```

## `tee` — observe without interrupting
```bash
journalctl -u nginx | tee errors.log
```
Writes to terminal and file simultaneously.

## `watch` — continuous observation
```bash
watch -n 2 "ss -ant"
watch -n 1 "free -h"
```
Runs a command repeatedly at fixed intervals.

## `diff` — compare before assuming
```bash
diff nginx.conf nginx.conf.backup
```
Quickly spots configuration drift.

## `env` — your runtime configuration
```bash
env
```
Check environment variables early when debugging containers, CI/CD, or systemd services — missing secrets/paths are a common root cause.

## Takeaway
These tools share a common trait: none of them modify the system, they only observe it (network state, processes, memory, file descriptors, kernel activity, config, runtime env). Learn what's already built in before reaching for new packages.
