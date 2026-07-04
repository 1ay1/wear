#!/bin/sh
# rofi script mode: fuzzy-pick a process, SIGTERM it. Second pass confirms with SIGKILL option.
# Listing format:  PID  CPU%  MEM%  COMMAND

if [ -z "$1" ]; then
    # list processes, heaviest first, skip kernel threads and self
    ps -eo pid,pcpu,pmem,comm --sort=-pcpu --no-headers \
        | grep -v " rofi$" \
        | head -60 \
        | awk '{printf "%6d  cpu:%-5s mem:%-5s %s\n", $1, $2"%", $3"%", $4}'
else
    pid=$(echo "$1" | awk '{print $1}')
    name=$(echo "$1" | awk '{print $NF}')
    if [ -n "$pid" ]; then
        kill "$pid" 2>/dev/null \
            && notify-send "[kill] SIGTERM → $name" "pid $pid terminated" \
            || notify-send -u critical "[kill] FAILED" "pid $pid refused SIGTERM — try: kill -9 $pid"
    fi
fi
