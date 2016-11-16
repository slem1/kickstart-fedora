#!/bin/sh

if [[ ! $EUID -eq 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

if ! python3 --version > /dev/null 2>&1; then
  echo "python3 must be installed, abort..."
  exit 1
fi

clean=false

trap "_term" EXIT TERM INT

function _term {

if [[ $clean == false ]]; then
  origin=$?
  virsh list --all | grep -qs ksvm
  ksvm=$?

  if [[ ! $origin -eq 0 && $ksvm -eq 0 ]]; then
    #Destroy vm on error
    echo "Destroy and undefine ksvm domain"
    virsh destroy ksvm 2> /dev/null ; virsh undefine ksvm --nvram 2> /dev/null
  elif [[ $ksvm -eq 0 ]]; then
    #Ask for destroy and undefine on success
    read -p "Do you want to destroy and undefine ksvm domain: (n)" -n 1 answer
    case "$answer" in      
      y|Y) echo ; virsh destroy ksvm 2> /dev/null ; virsh undefine ksvm --nvram 2> /dev/null;;
    esac
  fi

  if [[ ! -z $server_pid ]]; then
    echo "Terminate http server..."
    kill -TERM $server_pid 2> /dev/null
  fi
    
  echo "Exiting..."
  clean=true
  exit $origin
fi
}

./make-efi.sh -w . -o boot.img

if [[ ! $? -eq 0 ]]; then
  exit 1
fi

python3 -m http.server @ks.port@ --bind=@ks.host@ &

if [[ ! $? -eq 0 ]]; then
  exit 1
fi

server_pid=$!

./create-vm.sh -m efi -b boot.img

if [[ ! $? -eq 0 ]]; then
  exit 1
fi

echo "Press ctrl-C to stop"

while true; do
  sleep 1
done;
