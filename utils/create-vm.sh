#!/bin/sh

disk=/media/EXT4-Storage/vm/kickstart-fedora/kickstart_install.qcow2
iso=/media/EXT4-Storage/vm/isos/Fedora-Workstation-netinst-x86_64-24-1.2.iso

virt-install  -n kickstart-vm --description "Testing VM for kickstart installation" --os-type=linux  --ram=1024  --vcpus=1  --disk path=$disk,bus=virtio,size=10 --cdrom $iso  --network bridge:br0 --graphics spice
