#!/usr/bin/env bash
#
# System stats for the tmux status bar, colored with the active theme.
#   stats.sh mem  <ok> <warn> <crit>     memory usage
#   stats.sh cpu  <ok> <warn> <crit>     cpu usage
#   stats.sh up   <icon> <text>          upload rate
#   stats.sh down <icon> <text>          download rate
# Colors are hex values without the leading '#' (it would start a shell comment).

CACHE="${TMPDIR:-/tmp}/tmux-theme-$(id -u)"
OS=$(uname -s)
mkdir -p "$CACHE"

level_color() {
  local pct=$1 warn=$2 crit=$3 ok=$4 mid=$5 high=$6
  if [ "$pct" -ge "$crit" ]; then echo "$high"
  elif [ "$pct" -ge "$warn" ]; then echo "$mid"
  else echo "$ok"; fi
}

mem_pct() {
  if [ "$OS" = Darwin ]; then
    vm_stat | awk -v total="$(sysctl -n hw.memsize)" '
      /page size of/                  { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+$/) size = $i }
      /^Anonymous pages/              { anon = $NF + 0 }
      /^Pages purgeable/              { purge = $NF + 0 }
      /^Pages wired down/             { wired = $NF + 0 }
      /^Pages occupied by compressor/ { comp = $NF + 0 }
      END { printf "%d", (anon - purge + wired + comp) * size * 100 / total }'
  else
    awk '/^MemTotal/ { t = $2 } /^MemAvailable/ { a = $2 } END { printf "%d", (t - a) * 100 / t }' /proc/meminfo
  fi
}

cpu_pct() {
  if [ "$OS" = Darwin ]; then
    ps -A -o %cpu= | awk -v n="$(sysctl -n hw.ncpu)" '{ s += $1 } END { v = s / n; if (v > 100) v = 100; printf "%d", v }'
  else
    local user nice system idle iowait irq softirq steal total busy prev_total prev_busy
    read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
    total=$((user + nice + system + idle + iowait + irq + softirq + steal))
    busy=$((total - idle - iowait))
    read -r prev_total prev_busy 2>/dev/null < "$CACHE/cpu"
    echo "$total $busy" > "$CACHE/cpu"
    if [ -n "$prev_total" ] && [ "$total" -gt "$prev_total" ]; then
      echo $(( (busy - prev_busy) * 100 / (total - prev_total) ))
    else
      echo 0
    fi
  fi
}

net_counters() {
  if [ "$OS" = Darwin ]; then
    netstat -ibn | awk '$1 ~ /^en[0-9]+$/ && $3 ~ /^<Link/ { rx += $(NF-4); tx += $(NF-1) } END { printf "%.0f %.0f\n", rx, tx }'
  else
    local rx=0 tx=0 dev
    for dev in /sys/class/net/*; do
      [ "${dev##*/}" = lo ] && continue
      rx=$((rx + $(cat "$dev/statistics/rx_bytes"))); tx=$((tx + $(cat "$dev/statistics/tx_bytes")))
    done
    echo "$rx $tx"
  fi
}

# Up and down run as separate status jobs, so the sample is shared through a cache
# and only refreshed once per second.
net_rates() {
  local now rx tx ts prev_rx prev_tx rx_rate tx_rate elapsed
  now=$(date +%s)
  read -r ts prev_rx prev_tx rx_rate tx_rate 2>/dev/null < "$CACHE/net"
  if [ -n "$ts" ] && [ $((now - ts)) -lt 1 ]; then
    echo "$rx_rate $tx_rate"
    return
  fi
  read -r rx tx < <(net_counters)
  rx_rate=0 tx_rate=0
  if [ -n "$ts" ]; then
    elapsed=$((now - ts))
    rx_rate=$(( (rx - prev_rx) / elapsed )); tx_rate=$(( (tx - prev_tx) / elapsed ))
    [ "$rx_rate" -lt 0 ] && rx_rate=0
    [ "$tx_rate" -lt 0 ] && tx_rate=0
  fi
  echo "$now $rx $tx $rx_rate $tx_rate" > "$CACHE/net"
  echo "$rx_rate $tx_rate"
}

human_rate() {
  awk -v b="$1" 'BEGIN {
    if (b >= 1048576) printf "%.1f MB/s", b / 1048576
    else printf "%d KB/s", b / 1024 }'
}

case $1 in
  mem)
    pct=$(mem_pct)
    color=$(level_color "$pct" 70 85 "$2" "$3" "$4")
    printf '#[fg=#%s]󰍛 %s%%' "$color" "$pct"
    ;;
  cpu)
    pct=$(cpu_pct)
    color=$(level_color "$pct" 50 80 "$2" "$3" "$4")
    printf '#[fg=#%s] %s%%' "$color" "$pct"
    ;;
  up)
    read -r _ tx < <(net_rates)
    printf '#[fg=#%s]󰕒 #[fg=#%s]%s' "$2" "$3" "$(human_rate "$tx")"
    ;;
  down)
    read -r rx _ < <(net_rates)
    printf '#[fg=#%s]%s #[fg=#%s]󰇚' "$3" "$(human_rate "$rx")" "$2"
    ;;
esac
