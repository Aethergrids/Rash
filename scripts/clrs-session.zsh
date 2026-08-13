#!/bin/zsh

set -u

if (( $# != 3 )); then
  print -u2 -r -- "usage: clrs-session.zsh CLASH_BIN RUNTIME_DIR CONFIG_FILE"
  exit 64
fi

typeset -r clash_bin="$1"
typeset -r runtime_dir="$2"
typeset -r config_file="$3"

trap 'exit 0' INT TERM HUP

print -r -- "clrs tmux session"
print -r -- "Config: $config_file"
print -r -- "Detach: Ctrl-b, then d"
print -r -- "Stop:   clrs stop"
print -r -- ""

"$clash_bin" --directory "$runtime_dir" --config "$config_file"
typeset -r exit_status=$?

if (( exit_status == 0 || exit_status == 130 )); then
  exit "$exit_status"
fi

print -u2 -r -- ""
print -u2 -r -- "Clash RS exited with status $exit_status."
print -u2 -r -- "This tmux session is being kept open for inspection."
print -u2 -r -- "Run 'clrs stop' to close it."

while true; do
  sleep 3600
done
