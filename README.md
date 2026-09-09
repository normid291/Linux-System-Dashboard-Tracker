# sysdash.sh — Linux System Dashboard

A live, auto-refreshing dashboard that runs right in your terminal and shows you what's going on with your Linux machine — CPU, memory, disk space, network, temperature, and top processes — all in one screen, updating automatically.

Think of it like a simplified, terminal-based Task Manager (Windows) or Activity Monitor (Mac), but built entirely with plain Bash and standard Linux tools.

## What It Shows You

| Section | What it means in plain terms |
|---|---|
| **HOST** | Basic info about your machine — hostname, OS version, kernel version, and how long it's been running (uptime) |
| **LOAD AVERAGE** | How "busy" your system is on average over the last 1, 5, and 15 minutes. Lower is calmer. |
| **CPU** | What percentage of your processor is currently being used, plus what CPU model you have |
| **MEMORY** | How much RAM is total / used / free / available, plus swap (backup memory on disk) |
| **DISK** | How full your storage drives are, and how much space is left |
| **NETWORK** | Your active network connections (like Wi-Fi or Ethernet), their IP addresses, and how much data has been sent/received since boot |
| **TEMPERATURE** | Your hardware's temperature sensors, if your machine exposes them (cloud servers often don't have this) |
| **TOP 5 PROCESSES** | The 5 programs currently using the most CPU |

Everything is color-coded — **green** means healthy, **yellow** means getting busy, **red** means it's running hot/full/high.

## How to Use It

**1. Make it executable (only needs to be done once):**
```bash
chmod +x sysdash.sh
```

**2. Run it:**
```bash
./sysdash.sh
```

By default, it refreshes every **2 seconds**. To change that, pass a number (in seconds) as an argument:

```bash
./sysdash.sh 5     # refresh every 5 seconds
./sysdash.sh 10    # refresh every 10 seconds
```

**3. Stop it:**
Press `Ctrl + C` at any time — it'll exit cleanly with a goodbye message instead of just cutting off.

## Requirements

No installation needed beyond what most Linux systems already have built in:
- Bash (the shell itself)
- Standard tools: `df`, `free`, `uptime`, `ps`, `ip`, `awk`

Works on virtually any Linux distro — Ubuntu, Debian, Amazon Linux, etc. Some sections (like Temperature) may show "not available" on cloud VMs, since virtual servers often don't expose hardware sensors — that's expected, not a bug.

## Why It's Built This Way (for anyone learning Bash/Linux)

This script was intentionally written to double as a learning example, not just a tool:

- **Uses standard commands** (`df`, `free`, `ps`, etc.) instead of manually parsing system files everywhere, because that's what you'd actually reach for as a sysadmin or DevOps engineer day-to-day.
- **Each section is its own function**, so you can study, copy, or disable one piece at a time without breaking the rest.
- **The live refresh is hand-built** (clear the screen -> redraw -> wait -> repeat) instead of using the `watch` command, so you can actually see how a "live" terminal dashboard works under the hood.
- **CPU usage is calculated manually** by reading `/proc/stat` twice, a fraction of a second apart, and comparing the numbers — which is the same basic technique tools like `top` use internally.

## Example Output

```
+================================================+
|           LINUX SYSTEM DASHBOARD              |
+================================================+
2026-09-09 10:15:32  |  refresh: 2s  |  Ctrl+C to quit

-- HOST
  Hostname:    my-server
  OS:          Ubuntu 24.04 LTS
  Kernel:      6.8.0-1015-aws
  Uptime:      up 3 hours, 12 minutes

-- CPU
  Usage: 14%
  Model: Intel Xeon Platinum (2 cores)

-- MEMORY
  Total: 3.8G   Used: 1.1G   Free: 1.9G   Available: 2.6G [29%]
  ...
```

## License

Free to use, modify, and learn from.
