#!/bin/sh
#@author slemoine
#Custom fedora iso maker script
#Packages requirements : xorriso, syslinux

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
  echo "Usage : $0 -d <device> -w <working_dir>"
  echo "Requirements :"
  echo "This command requires the following packages : xorriso, syslinux"
  echo "options :"
  echo "-f or --force : bypass all action confirm i.e. assuming you answer yes to all script confirmation"
  echo "-d : device to write on the iso"
  echo "-w : working directory where all operations like downloading native iso and building new custom one will be done"
  echo "-a or --additionals : directory or file to copy to the new custom iso as additional files"
  echo "--iso-only : use this if you only want to build the custom iso without writing on a device"
  echo "--no-clean : do not clean custom iso making directory (for debugging purpose)"
}

#clean temporary stuff
function clean {

  if [[ -z "$no_clean" ]]; then
    echo "Cleaning $working_dir/bootisoks"
    rm -rf "$working_dir"/bootisoks
  fi
}

#write on device
#e.g. write_on_device if of
function write_on_device {
  echo "write $1 on $2"
  dd if="$1" bs=2048 of="$2"
  echo "Iso writing done on $2"
}

#BODY

if [[ $EUID -ne 0 ]]; then
  echo 'This script must be run as root'
  exit 1
fi

if [[ $# -eq 0 || $@ == '-h' || $@ == '--help' ]]; then
  usage
  exit
fi

if ! xorriso --version > /dev/null 2>&1; then
  echo "xorriso is not installed, abort..."
  exit 1
fi

if ! syslinux --version > /dev/null 2>&1; then
  echo "syslinux is not installed, abort..."
  exit 1
fi

while [[ $# -gt 0 ]];
do
  case "$1" in
    --iso-only) iso_only=true;;
    -d) device="$2"; shift;;
    -f) force=true;;
    --force) force=true;;
    -o) output="$2"; shift;;
    -w) working_dir="$2"; shift;;
    -a) additionals="$2"; shift;;
    --additionals) additionals="$2"; shift;;
    --no-clean) no_clean=true;;
    *) echo "unknow option $1, exit..."; exit 1;;
  esac
  shift
done

if [[ "$iso_only" != true && -z "$device" ]]; then
  echo -e "Please specify a target device or --iso-only option \n"
  usage
  exit 1
fi

if [[ -z "$working_dir" ]]; then
  working_dir=.
fi

#Get ISO & Checksum
if [[ -f $working_dir/$ISO ]]; then
  echo 'The fedora iso has already been downloaded, skip...'
else
  echo 'Downloading iso from $ISO_URL...'

  mkdir -p $working_dir

  if ! (cd $working_dir && curl -O $ISO_URL && curl -O $ISO_CHECKSUM_URL ); then
    echo "Download error, exit..."
    exit 1
  fi

  echo 'Validate checksum'

  #import gpg key
  gpg --keyserver keys.fedoraproject.org --recv $FEDORA_FINGERPRINT

  #download checksum
  gpg_out=$(gpg --status-fd 1 --verify-files $working_dir/$ISO_CHECKSUM 2> /dev/null)

  if ! echo $gpg_out | grep -qs "\[GNUPG:\] VALIDSIG $FEDORA_FINGERPRINT"; then
    echo "Invalid GPG signature for Checksum"
    exit 1
  fi

  if ! (cd $working_dir && sha256sum -c --quiet --status $ISO_CHECKSUM); then
    echo "Wrong checksum, exit..."
    exit 1
  fi

  echo 'Base fedora iso available in $working_dir'
fi

echo "Begin creation of custom kickstart iso"

#mount iso and create working stuff
mkdir -p "$working_dir"/bootiso && mkdir -p "$working_dir"/bootisoks

mount -o loop "$working_dir"/"$ISO" "$working_dir"/bootiso/

cp -r "$working_dir"/bootiso/* "$working_dir"/bootisoks/

umount "$working_dir"/bootiso && rmdir "$working_dir"/bootiso

chmod -R u+w "$working_dir"/bootisoks/

#add custom conf
cp iso/$FEDORA_VERSION/EFI/BOOT/grub.cfg $working_dir/bootisoks/EFI/BOOT/grub.cfg
cp iso/$FEDORA_VERSION/isolinux/isolinux.cfg $working_dir/bootisoks/isolinux/isolinux.cfg

#add additionals files to the iso if necessary
if [[ ! -z "$additionals" ]]; then
  mkdir "$working_dir"/bootisoks/additionals/
  cp -r "$additionals/." "$working_dir"/bootisoks/additionals
fi

#make bootable iso from usb device
cd $working_dir/bootisoks/

xorriso -as mkisofs -U -A "$VOLUME" -V "$VOLUME" -volset "$VOLUME" \
    -J -joliet-long -r -v -x ./lost+found \
    -o $working_dir/fedora_boot.iso \
    -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 \
    -boot-info-table -eltorito-alt-boot -e images/efiboot.img -isohybrid-mbr /usr/share/syslinux/isohdpfx.bin -no-emul-boot \
    .

if [[ $? -ne 0 ]]; then
  echo "Error while making iso, abort..."
  exit 1
fi


if [[ "$iso_only" = true ]]; then
  echo "iso image $working_dir/fedora_boot.iso is available"
  clean
  exit
fi

if [[ "$force" = true ]]; then
 write_on_device $working_dir/fedora_boot.iso "$device"
else
  while true; do
    read -p "All data on $device will be wiped out, are you sure ?" yn
    case $yn in
      [yY]*) write_on_device $working_dir/fedora_boot.iso "$device"
             break;;
      [nN]*)
             echo "Iso image is available $working_dir/fedora_boot.iso"
             exit;;
      *) echo "Please answer yes or no";;
    esac
  done
fi
