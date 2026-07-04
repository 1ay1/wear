#!/usr/bin/env bash
# Toggle screen recording with wf-recorder (NVIDIA-friendly).
# First invocation starts recording; second invocation stops it.
#   record.sh region   -> drag-select an area to record (default)
#   record.sh full     -> record the whole focused output
#   record.sh gif      -> region, saved as an optimized .gif
#   record.sh audio    -> region + system audio
# Stopping copies the file path to clipboard and pops a notification.
#
# Uses NVENC (GPU) h264 encoding with a libx264 (CPU) fallback, because
# wl-screenrec can't negotiate NVIDIA's block-linear dmabuf formats.
set -euo pipefail

viddir="${HOME}/Videos/Recordings"
mkdir -p "$viddir"
pidfile="/tmp/wf-recorder.pid"
lastfile="/tmp/wf-recorder.last"
modefile="/tmp/wf-recorder.mode"

notify() { command -v dunstify >/dev/null && dunstify -a Recorder "$@" || notify-send "$@"; }

stop_recording() {
  local pid; pid="$(cat "$pidfile")"
  # SIGINT lets wf-recorder/ffmpeg finalize the mp4 container cleanly
  kill -INT "$pid" 2>/dev/null || true
  for _ in $(seq 1 60); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  rm -f "$pidfile"

  local f rmode; f="$(cat "$lastfile" 2>/dev/null || true)"; rmode="$(cat "$modefile" 2>/dev/null || true)"
  if [[ -n "$f" && -f "$f" ]]; then
    if [[ "$rmode" == "gif" ]]; then
      local gif="${f%.mp4}.gif"
      notify -h string:x-canonical-private-synchronous:rec -i media-record "Recorder" "Encoding GIF…"
      ffmpeg -y -i "$f" -vf "fps=15,scale=iw:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" "$gif" >/dev/null 2>&1
      rm -f "$f"; f="$gif"
    fi
    printf '%s' "$f" | wl-copy
    notify -i video-x-generic "Recording saved" "$f  (path copied)"
  else
    notify -i video-x-generic "Recording stopped" "no file — check: wf-recorder in terminal"
  fi
}

if [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
  stop_recording
  exit 0
fi

mode="${1:-region}"
ts="$(date +%Y%m%d-%H%M%S)"
outfile="$viddir/rec-$ts.mp4"
declare -a args=()

case "$mode" in
  region)
    geom="$(slurp -d)" || exit 0
    args=(-g "$geom") ;;
  full)
    ;;
  gif)
    geom="$(slurp -d)" || exit 0
    args=(-g "$geom") ;;
  audio)
    geom="$(slurp -d)" || exit 0
    args=(-g "$geom" --audio) ;;
  *)
    echo "usage: record.sh [region|full|gif|audio]" >&2; exit 1 ;;
esac

# Prefer NVENC (GPU); fall back to libx264 (CPU) if NVENC init fails.
codec_args=(-c h264_nvenc -p preset=p5 -p rc=vbr -p cq=23 -x yuv420p)
if ! ffmpeg -hide_banner -encoders 2>/dev/null | grep -q h264_nvenc; then
  codec_args=(-c libx264 -p crf=20 -p preset=veryfast -x yuv420p)
fi

printf '%s' "$outfile" > "$lastfile"
printf '%s' "$mode"    > "$modefile"

start() {
  wf-recorder "${args[@]}" "${codec_args[@]}" -f "$outfile" &
  echo $! > "$pidfile"
}

# Launch; if NVENC-launched process dies within ~1s, retry with libx264.
start
sleep 1
if ! kill -0 "$(cat "$pidfile")" 2>/dev/null && [[ ! -s "$outfile" ]]; then
  codec_args=(-c libx264 -p crf=20 -p preset=veryfast -x yuv420p)
  start
fi

notify -i media-record "Recording…" "$mode → press the same key again to stop"
