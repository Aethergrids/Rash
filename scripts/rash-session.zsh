#!/bin/zsh

set -u

if (( $# != 4 )); then
  print -u2 -r -- "usage: rash-session.zsh CLIENT CLIENT_BIN RUNTIME_DIR CONFIG_FILE"
  exit 64
fi

typeset -r client="$1"
typeset -r client_bin="$2"
typeset -r runtime_dir="$3"
typeset -r config_file="$4"
typeset -a client_args
case "$client" in
  clash-rs) client_args=(--directory "$runtime_dir" --config "$config_file") ;;
  sing-box) client_args=(run --directory "$runtime_dir" --config "$config_file") ;;
  *) print -u2 -r -- "unsupported client: $client"; exit 64 ;;
esac

trap 'exit 0' INT TERM HUP

print -r -- "rash tmux session"
print -r -- "Config: $config_file"
print -r -- "Detach: Ctrl-b, then d"
print -r -- "Stop:   rash stop"
print -r -- ""

"$client_bin" "${client_args[@]}"
typeset -r exit_status=$?

if (( exit_status == 0 || exit_status == 130 )); then
  exit "$exit_status"
fi

print -u2 -r -- ""
print -u2 -r -- "$client exited with status $exit_status."
print -u2 -r -- "This tmux session is being kept open for inspection."
print -u2 -r -- "Run 'rash stop' to close it."

while true; do
  sleep 3600
done
