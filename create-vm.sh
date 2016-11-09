#!/bin/sh

while getopts :b:m:d: opt; do
 case "$opt" in
   b) boot_img="$OPTARG";;
   d) disk="$OPTARG";;
   m) mode="$OPTARG";;
   \?)
    echo "invalid option $OPTARG" >&2
    exit 1;;
   :)
    echo "Option -$OPTARG requires an argument" >&2
    exit 1;;
  esac
done;

disk_size=@vm.disk.size@ #Gb
disk_default="system_hd.img"
nic="bridge:@vm.bridge@"
name="ksvm"

if [[ ! -f "$boot_img" ]]; then
  "Missing boot image" >&2
  exit 1
fi

if [[ -z "$mode" ]]; then
  "Missing mode (efi or iso)" >&2
  exit 1
fi

if [[ ! -f "$disk" ]]; then
  disk="$disk_default"
  echo "default disk $disk will be used for system installation"
fi

if virsh list --all | grep -qs ksvm; then
  virsh destroy ksvm 2> /dev/null && virsh undefine ksvm 2> /dev/null
fi

if [[ "$mode"=="efi" ]]; then
  virt-install -n "$name" --description "kickstart vm" \
--os-type=linux  --ram=2048  --vcpus=1 --graphics spice \
--disk path="$boot_img",bus=usb \
--disk path="$disk",bus=virtio,size=$disk_size \
--network "$nic" --boot uefi

else

  virt-install -n "$name" --description "kickstart vm"\
--os-type=linux  --ram=2048  --vcpus=1 --graphics spice \
--disk path="$disk",bus=virtio,size=$disk_size \
--cdrom "$boot_img" \
--network "$nic" --boot cdrom
fi
