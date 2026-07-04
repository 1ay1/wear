#!/bin/sh
# gpu:35% — nvidia-smi poller for waybar (json output)
out=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw --format=csv,noheader,nounits 2>/dev/null)
[ -z "$out" ] && { printf '{"text":"gpu:err","class":"critical"}\n'; exit 0; }

util=$(echo "$out"  | cut -d, -f1 | tr -d ' ')
temp=$(echo "$out"  | cut -d, -f2 | tr -d ' ')
mused=$(echo "$out" | cut -d, -f3 | tr -d ' ')
mtot=$(echo "$out"  | cut -d, -f4 | tr -d ' ')
pwr=$(echo "$out"   | cut -d, -f5 | tr -d ' ')

class=""
[ "$temp" -ge 80 ] 2>/dev/null && class="critical"

vram=$((mused * 100 / mtot))
printf '{"text":"gpu:%s%% vmem:%s%% gtmp:%s°","tooltip":"GTX 1660 SUPER\\nutil: %s%%  temp: %s°C\\nvram: %sM / %sM\\npower: %sW","class":"%s"}\n' \
    "$util" "$vram" "$temp" "$util" "$temp" "$mused" "$mtot" "$pwr" "$class"
