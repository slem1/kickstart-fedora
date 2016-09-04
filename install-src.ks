#version=DEVEL
# System authorization information
auth --enableshadow --passalgo=sha512

# Use graphical install
graphical

# Use http server Installation media
install
#url fallback --url=http://fedora.mirrors.ovh.net/linux/releases/@fedora.version@/Everything/@fedora.arch@/os/
url --url=http://@install.repo.host@:@install.repo.port@/repo/linux/releases/@fedora.version@/Everything/@fedora.arch@/os/

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
rootpw --iscrypted @root.password@

# System timezone
timezone Europe/Paris

#groups & users
group --name=home
group --name=dev
user --name=@user1.name@ --password=@user1.password@ --iscrypted --gecos="@user1.name@" --groups=@user1.groups@
user --name=@user2.name@ --password=@user2.password@ --iscrypted --gecos="@user2.name@" --groups=@user2.groups@


# X Window System configuration information
xconfig  --startxonboot

# System bootloader configuration
bootloader --location=mbr 

# repo
## core 
repo --name=everything --baseurl=http://@install.repo.host@:@install.repo.port@/repo/linux/releases/@fedora.version@/Everything/@fedora.arch@/os/
repo --name=updates --baseurl=http://@install.repo.host@:@install.repo.port@/repo/linux/updates/@fedora.version@/@fedora.arch@/
## rpmfusion
repo --name=rpmfusion-free --mirrorlist=http://mirrors.rpmfusion.org/mirrorlist?repo=free-fedora-@fedora.version@&arch=@fedora.arch@ 
repo --name=rpmfusion-free-updates --mirrorlist=http://mirrors.rpmfusion.org/mirrorlist?repo=free-fedora-updates-released-@fedora.version@&arch=@fedora.arch@ 
repo --name=rpmfusion-nonfree --mirrorlist=http://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-@fedora.version@&arch=@fedora.arch@ 
repo --name=rpmfusion-nonfree-updates --mirrorlist=http://mirrors.rpmfusion.org/mirrorlist?repo=nonfree-fedora-updates-released-@fedora.version@&arch=@fedora.arch@ 

# Partition clearing information
clearpart --all --initlabel

autopart --type=plain

#after installation complete
reboot --kexec

#for vm only
services --enabled=sshd

#Package selection

%packages

#fedora workstation
@^workstation-product-environment
nautilus-open-terminal
gnome-tweak-tool
powerline

#dev
java-1.8.0-openjdk-devel 
postgresql-server
postgresql-contrib
pgadmin3
git
gitg
ant

#multimedia
azureus
vlc

##codecs
gstreamer1-libav 
gstreamer1-plugins-ugly 
gstreamer1-plugins-good 
gstreamer1-plugins-bad-free 
gstreamer1-plugins-bad-freeworld 
gstreamer1-vaapi

#editor
vim

#ssh
openssh
openssh-clients
openssh-server

#system
gparted
htop
virt-manager
virt-install
virt-viewer

#misc
tomboy
calibre
dropbox
lsb-core-noarch #for atom

%end
