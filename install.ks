#version=DEVEL
# System authorization information
auth --enableshadow --passalgo=sha512

# Use graphical install
graphical

# Use http server Installation media
install
#url --url=http://fedora.mirrors.ovh.net/linux/releases/23/Workstation/x86_64/os/
url --url=http://fedora.mirrors.ovh.net/linux/releases/24/Workstation/x86_64/os/

# Run the Setup Agent on first boot
firstboot --enable

# Keyboard layouts
keyboard --vckeymap=fr-oss --xlayouts='fr (oss)'

# System language
lang fr_FR.UTF-8

# Network information
network  --bootproto=dhcp --onboot=on --device=enp0s3 --ipv6=auto
network  --hostname=localhost.localdomain

# Firewall
firewall --enabled

# Root password
#rootpw 

# System timezone
timezone Europe/Paris

#groups & users
group --name=home
group --name=dev
user 

# X Window System configuration information
xconfig  --startxonboot

# System bootloader configuration
bootloader --location=mbr --boot-drive=vda

# repo
repo --name=everything --baseurl=http://fedora.mirrors.ovh.net/linux/releases/24/Everything/x86_64/os/
repo --name=updates --baseurl=http://fedora.mirrors.ovh.net/linux/updates/24/x86_64/
repo --name=rpmfusion-free --mirrorlist=http://mirrors.rpmfusion.org/mirrorlist?repo=free-fedora-24&arch=x86_64 
repo --name=rpmfusion-free-updates --mirrorlist=http://mirrors.rpmfusion.org/mirrorlist?repo=free-fedora-updates-released-24&arch=x86_64 
repo --name=rpmfusion-nonfree --mirrorlist=http://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-24&arch=x86_64 
repo --name=rpmfusion-nonfree-updates --mirrorlist=http://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-updates-released-24&arch=x86_64 

# Partition clearing information
clearpart --all --initlabel

autopart --type=plain

# Disk partitioning information
#part pv.3517 --fstype="lvmpv" --ondisk=sdb --size=15763
#part pv.3914 --fstype="lvmpv" --ondisk=sda --size=19460
#part /boot --fstype="ext4" --ondisk=sdb --size=238
#volgroup fedoraData --pesize=4096 pv.3914
#volgroup fedoraOs --pesize=4096 pv.3517
#logvol /  --fstype="ext4" --size=13312 --name=root --vgname=fedoraOs
#logvol /home  --fstype="ext4" --size=19456 --name=home --vgname=fedoraData
#logvol swap  --fstype="swap" --size=2448 --name=swap --vgname=fedoraOs

#after installation complete
reboot --kexec

#for vm only
services --enabled=sshd

#Package selection

%packages

#fedora workstation
@base-x
@workstation-product
nautilus
nautilus-open-terminal
gnome-tweak-tool
firefox

#dev
java-1.8.0-openjdk-devel 
postgresql-server
postgresql-contrib
git

#multimedia
azureus
vlc

#editor
vim

#ssh
openssh
openssh-clients
openssh-server

#misc
tomboy
calibre
dropbox
lsb-core-noarch #for atom
htop

%end
