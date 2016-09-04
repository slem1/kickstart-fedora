#!/bin/sh
#author slemonk

if [[ -z "$1" ]]; then
  echo "Missing target directory"
  echo "Usage sync_mirror.sh [destination]"
  echo "Example : ./sync_mirror.sh /media/data"
fi

destination=$(echo $1 | sed 's:/$::')

base_mirror=fedora.mirrors.ovh.net/download.fedora.redhat.com

releases=/linux/releases/24/Workstation/x86_64/os/
updates=/linux/updates/24/x86_64/

releases_destination=$destination$releases
updates_destination=$destination$updates

echo $releases_dest

##releases 
echo "Begin mirroring in $destination"
mkdir -p $releases_destination
rsync -av rsync://$base_mirror$releases --exclude=drpms $releases_destination

mkdir -p $updates_destination
rsync -av rsync://$base_mirror$updates --exclude=drpms $updates_destination

echo "Mirroring end"
