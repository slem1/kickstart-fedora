#!/bin/sh

if [[ ! $EUID -eq 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

set -e

trap "_term" TERM INT

function _term {
  echo "Terminate http server..."
  kill -TERM $server_pid 2> /dev/null
  echo "Exiting..."
  exit 0
}

./make-efi.sh -w . -o boot.img

python3 -m http.server @install.repo.port@ --bind=@install.repo.host@ &

server_pid=$!

./create-vm.sh -m efi -b boot.img

while true; do
  sleep 1
done;
