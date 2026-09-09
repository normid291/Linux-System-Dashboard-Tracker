#!/usr/bin/env bash
#
# sysdash.sh — A live-refreshing Linux system info dashboard
#
# WHY THIS SCRIPT IS BUILT THIS WAY (read this if you're learning):
#   - It leans on standard Linux tools (df, free, uptime, ps, ip) rather than
#     parsing /proc directly everywhere, because that's what you'll actually
#     use day-to-day as a DevOps engineer. A couple of /proc reads are
#     included (CPU %, temps) because those tools don't expose that data
#     cleanly — and reading /proc is a core Linux skill worth practicing.
#   - Every section is its own function. That's not just style — it means
#     you can comment out one function call in the main loop to debug just
#     that section, and you can copy-paste any function into another script.
#   - We avoid `watch` and instead build our own refresh loop, so you can
#     see exactly how a "live" terminal UI works (clear screen, redraw, sleep).
#
# USAGE:
#   ./sysdash.sh            # refresh every 2 seconds (default)
#   ./sysdash.sh 5          # refresh every 5 seconds
#   Press Ctrl+C to quit.

set -uo pipefail
# -u: error on unset variables (catches typos in variable names)
# -o pipefail: a pipeline (cmd1 | cmd2) fails if ANY part fails, not just the last
# (We skip -e here on purpose — in a dashboard that polls many subsystems,
#  one failed command, like temps not being available on a VM, shouldn't kill the whole script.)

REFRESH_INTERVAL="${1:-2}"   # seconds between redraws; default 2, override with first arg

# ── Colors ──────────────────────────────────────────────────────────────
# ANSI escape codes for colored terminal output. \033 is the ESC character.
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_CYAN="\033[36m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_RED="\033[31m"
C_DIM="\033[2m"

section() {
    # Prints a section header. $1 = title text.
    echo -e "${C_BOLD}${C_CYAN}── $1 ${C_RESET}"
}

# ── Helper: color a percentage based on how high it is ────────────────────
color_for_pct() {
    # $1 = integer percentage. Echoes the right color code.
    local pct="$1"
    if   (( pct >= 85 )); then echo -ne "$C_RED"
    elif (( pct >= 60 )); then echo -ne "$C_YELLOW"
    else                        echo -ne "$C_GREEN"
    fi
}

# ── Section: Host + Uptime ────────────────────────────────────────────────
show_host_info() {
    section "HOST"
    local hostname_str kernel os uptime_str
    hostname_str=$(hostname)
    kernel=$(uname -r)
    # /etc/os-release is the standard cross-distro way to get the OS name
    os=$(grep -oP '(?<=^PRETTY_NAME=").*(?=")' /etc/os-release 2>/dev/null || echo "Unknown")
    uptime_str=$(uptime -p 2>/dev/null || echo "n/a")   # -p = "pretty" e.g. "up 3 hours, 2 minutes"

    printf "  %-12s %s\n" "Hostname:" "$hostname_str"
    printf "  %-12s %s\n" "OS:" "$os"
    printf "  %-12s %s\n" "Kernel:" "$kernel"
    printf "  %-12s %s\n" "Uptime:" "$uptime_str"
}

# ── Section: Load average ─────────────────────────────────────────────────
show_load_avg() {
    section "LOAD AVERAGE"
    # /proc/loadavg format: "0.15 0.22 0.18 2/389 12345"
    # fields 1-3 are the 1/5/15 minute load averages
    local la1 la5 la15
    read -r la1 la5 la15 _ < /proc/loadavg

    local cores
    cores=$(nproc)   # number of CPU cores, used to judge if load is "high"

    printf "  %-8s %-8s %-8s %s\n" "1 min" "5 min" "15 min" "(cores: $cores)"
    printf "  %-8s %-8s %-8s\n" "$la1" "$la5" "$la15"
}

# ── Section: CPU usage ─────────────────────────────────────────────────────
# We compute CPU % by sampling /proc/stat twice, ~200ms apart, and diffing
# the "busy" vs "total" jiffies. This is how tools like top do it under the hood.
show_cpu_usage() {
    section "CPU"
    local cpu_line1 cpu_line2
    cpu_line1=$(grep '^cpu ' /proc/stat)
    sleep 0.2
    cpu_line2=$(grep '^cpu ' /proc/stat)

    # Fields after "cpu" are: user nice system idle iowait irq softirq steal ...
    read -r _ u1 n1 s1 i1 io1 irq1 sirq1 st1 _ <<< "$cpu_line1"
    read -r _ u2 n2 s2 i2 io2 irq2 sirq2 st2 _ <<< "$cpu_line2"

    local total1=$((u1+n1+s1+i1+io1+irq1+sirq1+st1))
    local total2=$((u2+n2+s2+i2+io2+irq2+sirq2+st2))
    local idle1=$i1
    local idle2=$i2

    local total_diff=$((total2-total1))
    local idle_diff=$((idle2-idle1))

    local cpu_pct=0
    if (( total_diff > 0 )); then
        cpu_pct=$(( (100 * (total_diff - idle_diff)) / total_diff ))
    fi

    local color; color=$(color_for_pct "$cpu_pct")
    printf "  Usage: ${color}%s%%${C_RESET}\n" "$cpu_pct"

    # Per-core count + model name, for context
    local model
    model=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')
    printf "  Model: %s (%s cores)\n" "${model:-unknown}" "$(nproc)"
}

# ── Section: Memory ────────────────────────────────────────────────────────
show_memory() {
    section "MEMORY"
    # `free -h` gives human-readable sizes (G/M). -h = human-readable.
    local mem_line
    mem_line=$(free -h | awk '/^Mem:/ {print $2, $3, $4, $7}')
    read -r total used free_mem available <<< "$mem_line"

    # Also compute a % for coloring, using raw (non -h) numbers
    local pct
    pct=$(free | awk '/^Mem:/ {printf "%d", ($3/$2)*100}')
    local color; color=$(color_for_pct "$pct")

    printf "  Total: %-8s Used: %-8s Free: %-8s Available: %-8s [${color}%s%%${C_RESET}]\n" \
        "$total" "$used" "$free_mem" "$available" "$pct"

    # Swap
    local swap_line
    swap_line=$(free -h | awk '/^Swap:/ {print $2, $3}')
    read -r swap_total swap_used <<< "$swap_line"
    printf "  Swap:  Total: %-8s Used: %-8s\n" "$swap_total" "$swap_used"
}

# ── Section: Disk usage ────────────────────────────────────────────────────
show_disk() {
    section "DISK"
    # df -h: human-readable disk free space. We filter to real filesystems only
    # (skip tmpfs, devtmpfs, overlay, etc. which are virtual/noise for a dashboard).
    printf "  %-20s %-6s %-6s %-6s %-5s %s\n" "Filesystem" "Size" "Used" "Avail" "Use%" "Mounted"
    df -h -x tmpfs -x devtmpfs -x overlay -x squashfs 2>/dev/null | tail -n +2 | while read -r fs size used avail pct mount; do
        local pct_num="${pct%\%}"
        local color; color=$(color_for_pct "$pct_num")
        printf "  %-20s %-6s %-6s %-6s ${color}%-5s${C_RESET} %s\n" "$fs" "$size" "$used" "$avail" "$pct" "$mount"
    done
}

# ── Section: Network ────────────────────────────────────────────────────────
show_network() {
    section "NETWORK"
    # List interfaces that are UP, with their IP addresses.
    # `ip -brief addr` gives a compact table: NAME STATE IP/CIDR
    ip -brief addr show 2>/dev/null | while read -r iface state addr _; do
        [[ "$iface" == "lo" ]] && continue   # skip loopback, not interesting here
        printf "  %-10s %-8s %s\n" "$iface" "$state" "${addr:-no address}"
    done

    # RX/TX byte counters from /proc/net/dev, for a quick sense of traffic volume
    echo -e "  ${C_DIM}--- traffic since boot ---${C_RESET}"
    awk 'NR>2 {
        gsub(":", "", $1)
        if ($1 != "lo") printf "  %-10s RX: %10.2f MB   TX: %10.2f MB\n", $1, $2/1024/1024, $10/1024/1024
    }' /proc/net/dev
}

# ── Section: Temperatures ──────────────────────────────────────────────────
show_temps() {
    section "TEMPERATURE"
    # Not all machines expose thermal zones (common on cloud VMs — that's fine,
    # we just print "not available" instead of erroring out).
    local found=0
    if compgen -G "/sys/class/thermal/thermal_zone*/temp" > /dev/null; then
        for zone in /sys/class/thermal/thermal_zone*/temp; do
            local raw type
            raw=$(cat "$zone" 2>/dev/null) || continue
            type=$(cat "${zone%temp}type" 2>/dev/null || echo "zone")
            local celsius=$((raw / 1000))
            local color; color=$(color_for_pct "$celsius")  # rough reuse: treat °C like a %, good enough for coloring
            printf "  %-20s ${color}%s°C${C_RESET}\n" "$type" "$celsius"
            found=1
        done
    fi
    (( found == 0 )) && echo -e "  ${C_DIM}No thermal sensors found (common on VMs/cloud instances)${C_RESET}"
}

# ── Section: Top processes ─────────────────────────────────────────────────
show_top_processes() {
    section "TOP 5 PROCESSES (by CPU)"
    printf "  %-8s %-20s %-6s %-6s\n" "PID" "NAME" "CPU%" "MEM%"
    # ps: -e all processes, -o custom columns, --sort=-%cpu descending by CPU
    ps -eo pid,comm,%cpu,%mem --sort=-%cpu --no-headers | head -n 5 | \
        while read -r pid comm cpu mem; do
            printf "  %-8s %-20s %-6s %-6s\n" "$pid" "$comm" "$cpu" "$mem"
        done
}

# ── Main draw loop ─────────────────────────────────────────────────────────
draw() {
    clear   # wipes the terminal so each refresh redraws cleanly instead of scrolling
    echo -e "${C_BOLD}${C_CYAN}╔══════════════════════════════════════════════╗"
    echo -e "║           LINUX SYSTEM DASHBOARD              ║"
    echo -e "╚══════════════════════════════════════════════╝${C_RESET}"
    echo -e "${C_DIM}$(date '+%Y-%m-%d %H:%M:%S')  |  refresh: ${REFRESH_INTERVAL}s  |  Ctrl+C to quit${C_RESET}"
    echo

    show_host_info;      echo
    show_load_avg;       echo
    show_cpu_usage;      echo
    show_memory;         echo
    show_disk;           echo
    show_network;        echo
    show_temps;          echo
    show_top_processes
}

# Trap Ctrl+C so we exit cleanly with a friendly message instead of a raw kill
trap 'echo -e "\n${C_YELLOW}Dashboard stopped.${C_RESET}"; exit 0' INT

# Main loop: draw, wait, repeat forever
while true; do
    draw
    sleep "$REFRESH_INTERVAL"
done
