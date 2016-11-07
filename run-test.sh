#!/bin/sh

if [[ ! $EUID -eq 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

set -e

trap "_term" EXIT TERM INT

function _term {

  origin=$?
  virsh list --all | grep -qs ksvm

  if [[ ! $origin -eq 0 && $? -eq 0 ]]; then
    echo "Destroy and undefine ksvm domain"
    virsh destroy ksvm 2> /dev/null && virsh undefine ksvm 2> /dev/null
  else
    read -p "Do you want to destroy and undefine ksvm domain: (n)" -n 1 answer
    case "$answer" in
      y|Y) virsh destroy ksvm 2> /dev/null && virsh undefine ksvm 2> /dev/null;;
    esac
  fi

  echo "Terminate http server..."
  kill -TERM $server_pid 2> /dev/null
  echo "Exiting..."
  exit 0
}

./make-efi.sh -w . -o boot.img

python3 -m http.server @ks.port@ --bind=@ks.host@ &

server_pid=$!

./create-vm.sh -m efi -b boot.img

echo "Press ctrl-C to stop"

while true; do
  sleep 1
done;
