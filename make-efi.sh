#!/bin/sh
#@author slemoine

#GLOBALS
FEDORA_VERSION=@fedora.version@
ISO=@fedora.iso@
ISO_CHECKSUM=@fedora.iso.checksum@
ISO_URL=@fedora.iso.mirror@/linux/releases/@fedora.version@/Everything/@fedora.arch@/iso/@fedora.iso@
ISO_CHECKSUM_URL=@fedora.iso.mirror@/linux/releases/@fedora.version@/Everything/@fedora.arch@/iso/@fedora.iso.checksum@
VOLUME=FedoraKS
FEDORA_FINGERPRINT=@fedora.fingerprint@

#FUNCTIONS

#show usage
function usage {
  echo "Usage : $0 -w <working_dir> -o <output>"
  echo "options :"
  echo "-o : output file"
  echo "-w : working directory where all temporary operations are done (such like downloading files or mount partitions)"
  echo "-a or --additionals : directory or file to copy the efi system partition"
}

function confirm {
  read -p "$1, are you sure [y/Y/n/N]? " -n 1
  echo
  if [[ ! "$REPLY" =~ ^[yY]$ ]]; then
    echo "abort..."
    exit 1
  fi
}

#download_iso <download_dir>
#<download_dir> : a directory
function download_iso {

  download_dir="$1"

  if [[ ! -d "$download_dir" ]]; then
    echo "Download directory is mandatory"
    exit 1
  fi

  if [[ -f "$download_dir"/$ISO ]]; then
    echo "The fedora iso has already been downloaded, skip..."
  else
    echo "Downloading iso from $ISO_URL..."

    if ! (cd "$download_dir" && curl -O $ISO_URL && curl -O $ISO_CHECKSUM_URL ); then
      echo "Download error, exit..."
      exit 1
    fi

    echo 'Validate checksum'

    #import gpg key
    gpg --keyserver keys.fedoraproject.org --recv $FEDORA_FINGERPRINT

    #download checksum
    gpg_out=$(gpg --status-fd 1 --verify-files "$download_dir"/$ISO_CHECKSUM 2> /dev/null)

    if ! echo $gpg_out | grep -qs "\[GNUPG:\] VALIDSIG $FEDORA_FINGERPRINT"; then
      echo "Invalid GPG signature for Checksum"
      exit 1
    fi

    if ! (cd "$download_dir" && sha256sum -c --quiet --status $ISO_CHECKSUM); then
      echo "Wrong checksum, exit..."
      exit 1
    fi

    echo 'Base fedora iso available in $download_dir'
  fi
}

#download_iso_and_mount <download_dir> <mount_point>
#Download iso and mount where :
#<download_dir> : is the download directory
#<mount_point> : is the directory where the iso will be mounted
function download_iso_and_mount {

  download_dir="$1"
  mount_point="$2" #"$working_dir"/bootiso

  if [[ ! -d "$download_dir" ]]; then
    echo "Download directory is mandatory"
    exit 1
  fi

  if [[ -z "$mount_point" ]]; then
    echo "Mount point is mandatory"
    exit 1
  fi

  download_iso "$download_dir"
  mkdir -p "$mount_point"
  mount -o loop "$download_dir"/"$ISO" "$mount_point"
  echo "ISO has been mount in $mount_point"
}

#esp_create <device>
#Create ESP on device
function esp_create {

  device="$1"

  echo "Make GPT label and create EFI system partition on $device"

  if [[ -z "$device" ]]; then
    echo "esp_create missing target device as parameter"
    exit 1
  fi

  if ! (parted -s "$device" mklabel gpt && parted -s "$device" mkpart ESP fat32 1M 512M &&  parted -s "$device" set 1 boot on); then
    echo "Error while ESP prepare device $device"
    exit 1
  fi
}

#esp_format <partition> <mount_point>
#format and mount ESP partition where
#<partition> is the device partition
#<mount_point> is the directory on which the partition will be mounted
function esp_format {

  partition="$1"
  mount_point="$2"

  echo "Format ESP $partition and mount it on $mount_point"

  if [[ -z "$partition" ]]; then
    echo "efi system partition missing parameter"
    exit 1
  fi

  if [[ -z "$mount_point" ]]; then
    echo "Mount point missing as parameter"
    exit 1
  fi

  if ! (mkfs.vfat "$partition" && mkdir -p "$mount_point" && mount "$partition" "$mount_point"); then
    echo "An error occured while format and mount ESP $partition on $mount_point"
    exit 1
  fi

}

#copy_bootable_data <source> <destination> where
#<source> : is the base ISO mount point
#<destination> : is the ESP mount point
function copy_bootable_data {

  source="$1" #"$working_dir"/bootiso/ source iso dir
  destination="$2" #$working_dir/ESP destination esp dir

  if [[ ! -d "$source" ]]; then
    echo "$source does not exist or is not a directory"
    exit 1
  fi

  if [[ ! -d $destination ]]; then
    echo "$destination does not exist or is not a directory"
    exit 1
  fi

  echo "Copy EFI data on $destination"

  cp -r "$source"/EFI "$destination"

  mkdir -p "$destination"/images/pxeboot

  cp -r "$source"/images/pxeboot/. "$destination"/images/pxeboot/

  #no need source anymore
  umount "$source" && rmdir "$source"

  echo "Replace grub configuration by kickstart one"

  #replace native grub.conf by kickstart grub.conf
  cp iso/$FEDORA_VERSION/EFI/BOOT/grub.cfg "$destination"/EFI/BOOT/grub.cfg

  #add additionals files to the iso if necessary
  if [[ ! -z "$additionals" ]]; then
    echo "Process additionals data"
    mkdir "$destination"/additionals/
    cp -r "$additionals/." "$destination"/additionals
  fi

  echo "Umount and clean"

  umount "$destination" && rmdir "$destination"

  echo "ESP data is ready"
}

#BODY
if [[ $EUID -ne 0 ]]; then
  echo 'This script must be run as root'
  exit 1
fi

if [[ $# -eq 0 || $@ == '-h' || $@ == '--help' ]]; then
  usage
  exit 1
fi

working_dir=.

while [[ $# -gt 0 ]];
do
  case "$1" in
    -o) output="$2"; shift;;
    -w) working_dir="$2"; shift;;
    -a|--additionals) additionals="$2"; shift;;
    *) echo "unknow option $1, exit..."; exit 1;;
  esac
  shift
done

#remove trailing /
working_dir=$(echo "$working_dir" | sed "s/\/*$//g")

if [[ ! -d $working_dir ]]; then
  echo "Working directory is missing or is not a directory"
  exit 1
fi

if [[ -z "$output" ]]; then
  echo "output is mandatory"
  exit 1
fi

set -e

if [[ -b "$output" ]]; then
  echo "Block device mode"

  confirm "All data on device $output will be erased"

  download_iso_and_mount "$working_dir" "$working_dir"/bootiso/

  umount "$output"?*

  esp_create "$output"

  esp="$output"1

  esp_format "$esp" "$working_dir"/ESP

  copy_bootable_data "$working_dir"/bootiso/ "$working_dir"/ESP

  echo "Device $output is ready"

else

  echo "Virtual disk file mode"

  if [[ -f "$output" ]]; then
      confirm "All data on file $output will be erased"
  fi

  download_iso_and_mount "$working_dir" "$working_dir"/bootiso/

  #Allocate file, make GPT label, create Efi System Partition (ESP)
  dd if=/dev/zero of="$output" count=512 bs=1M

  if ! loop_device=$(losetup -f "$output" --show); then
    echo "losetup failed, abort..."
    exit 1
  fi

  esp_create "$output"

  losetup -d $loop_device

  echo "$loop_device($output) has been partitioned"

  unset loop_device

  #start sector 2048s to 999423s, size of 997376s
  esp_start_sector=2048
  esp_size_limit=997376
  sector_size=512

  echo "Loop mount ESP (started from sector 2048)"

  #loop mount ESP, format, copy and release
  if ! loop_device=$(losetup -f "$output" --offset $(($sector_size*$esp_start_sector)) --sizelimit $(($sector_size*$esp_size_limit)) --show); then
    echo "Error while loop mounting ESP, abort..."
    exit 1
  fi

  esp_format "$loop_device" "$working_dir"/ESP

  copy_bootable_data "$working_dir"/bootiso/ "$working_dir"/ESP

  losetup -d "$loop_device"

  echo "virtual efi bootable device is available at $output"
fi
