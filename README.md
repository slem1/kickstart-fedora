# Kickstart Fedora #

## Goals ##

This project aims to provide scripting tools to easily manage, test and configure kickstart fedora installation. I made this project for my personal use of kickstart installations but I tried to make it as far as possible customizable to probably suit your own needs.

For a complete documentation on fedora kickstart please see the [official documentation](http://pykickstart.readthedocs.io/en/latest/).

This project provides :
  - Kickstart sample files
  - Scripts to create both iso and efi kickstart bootable media
  - Testing scripts to run kickstart installation on virtual machines

## Disclaimer ##

The scripts provided in this project must be run as root user (as they usually need superuser operations like mounting or writing on devices...). I check and run all the scripts several times on my own system, but if you feel uneasy about this, please feel free to run this project in a trashable environnement like virtual machines or containers.

## Environnement ##

I run the scripts on both Fedora 23 and Fedora 24 but it should be ok with all redhat distributions like centos. VM creation relies on libvirt. I use QEMU as hypervisor on my system. VM use bridge networking which will be discussed later in the VM testing section.

The project targets Fedora 24 installation but through property settings it could be customized for other fedora / centos / redhat versions.

## Dependencies ##

The following dependencies must be installed on your system:
  - ant
  - virt-install
  - virt-viewer
  - python3

(for iso making only) :
  - xorriso
  - syslinux  

## Project organization and setup ##

This project aims to host the kickstart installation file on an http server.

![](docs/images/ks-overview.png)

Each machine installation will be boot up from a bootable usb media for which the GRUB configuration has been modified to point to the kickstart provider http server. This way, the bootable device remains stable across kickstart modifications as the kickstart file is stored separatly.

The first thing to do is to set up the ip:port values of your kickstart server in global-conf.properties file :

```
ks.host=[MY_IP]
ks.port=[MY_PORT]
```

Optionally, you can also set the fedora installation mirror if for instance you have your own private mirror (see utils/sync_mirror.sh if you want to create a private fedora 24 mirror):

```
install.repo.host=[MY_FEDORA_MIRROR_HOST]
install.repo.port=[MY_FEDORA_MIRROR_PORT]
```

The project provides the following files :
 - install-src.ks : The base kickstart file
 - post-install.sh : A bunch of kickstart post install operations (will only be use with ant ks-full target)
 - make-efi.sh : allows to create a efi bootable usb device or virtual disk bootable image. The created media will start a kickstart installation from your http kickstart provider server.
 - make-iso.sh : allows to create a custom iso image. The created media will start a kickstart installation by retrieving the kickstart start from your http server.
 - create-vm.sh : create a virtual machine installation using custom iso or efi bootable image.
 - run-test.sh : create an efi bootable disk image, runs an http server serving the kickstart file, and start a virtual machine installation using the bootable efi disk image.
 - utils/sync_mirror.sh : utility script to create a private fedora 24 mirror.

 All these files must not be use from the root directory of the project. they need to be preprocessed by ant which will filters them through properties substitution file (global-conf.properties) and copy them in the dist directory.

### Process files ###

First build the project with ant :

```
ant
```

or

```
ant ks-min
```

Ant will do property substitutions on the differents scripts by using the global-conf.properties file. Please feel free to cutomize these keys-values pairs to adapt these to your need. By default, the filtered kickstart file will install a fedora 24 system with 2 users user1 and user2 with password 123456.

As I don't want to share my personal data (especially root and users passwords) you can provide an extra property file called user-conf.properties.private at the same level of global-conf.properties file. The keys/values pairs in this private property files overrides the ones provided in the global-conf.properties file. However this file is .gitignore by the project.

If you modify the default keys please re-run ant command and then move to the dist directory.

```
cd dist
```

You normally access to a ready-to-use kickstart file named install.ks and all the scripts described above.

#### Make a bootable efi device (the recommended media creation way) ####

The make-efi.sh script allows you to create a GRUB custom fedora bootable media which points to the kickstart installation http server. Using it enables you to create either a physical usb media or a bootable efi file disk image which can be used for booting installation on virtual machine.

This script will automatically detect if your target output is a block device (such like an usb stick) or a regular file (in this case it will create an efi bootable disk image). So for instance :

1 - to create an efi bootable disk image :
```
sudo ./make-efi.sh -o boot.img
```

2 - to create an efi bootable usb drive :

```
sudo ./make-efi.sh -o /dev/sdX
```

In case n°2, please double check that the target device /dev/sdX is REALLY YOUR USB STICK because it will overwrite all datas on the device.

#### bootable iso (not recommended) ####

The project also provides a make-iso.sh script which allows you to create a custom fedora iso image. Actually, it creates an iso hybrid image wich can be written on an usb device to boot up the system installation. I no longer use this method because for some reasons it does not work with some BIOS.

  - Make iso :

```
sudo ./make-iso.sh -o boot.iso --iso-only
```

  - Make iso and write it on device :

```
sudo ./make-iso.sh -o boot.iso -d /dev/sdX
```

Please double check that the target device /dev/sdX is REALLY YOUR USB STICK because it will overwrite all datas on the device.

#### VM Testing ####

Before deploying Kickstart installation on your physical machine, it should be advised to test the result in a virtual machine. Two scripts can help you to test your kickstart installation :

 - create-vm.sh
 - run-test.sh

 Both rely on virtual bridge networking to allows access of the host ressources from the guest. So in order to use both of these scripts, you need to create a virtual bridge br0 on your system (Actually the name br0 can be customized in the global-conf file).

![](docs/images/ksvm-test.png)

Bridge creation tutorial (Redhat / public bridge): [http://www.linux-kvm.org/page/Networking](http://www.linux-kvm.org/page/Networking)

##### create-vm.sh #####

The create-vm.sh script allows you to create a VM using libvirt and start the installation of the system from an ISO image or EFI bootable disk (made with make-efi.sh or make-iso.sh for instance). The creation of the media and the http server serving the kickstart file remains up to you.

  - Install VM from efi bootable disk :

```
sudo  ./create-vm.sh -b my-efi.img -m efi
```

   - Install from iso image :

```
sudo ./create-vm.sh -b my-iso.iso -m iso
```

By defaut it will create a system disk of size 12 GB for the newly installed system. The size of the disk can be configured in global-conf.properties.

You can also provide your own pre-allocated disk file with the -d options

```
sudo ./create-vm.sh -b my-efi.img -m efi -d my-system-hd.img
```

##### run-test.sh #####

The run-test.sh script is a straightforward combination of all the scripts described above. It will :

- Create an efi bootable virtual disk called boot.img in your current directory (through make-efi.sh).
- Create an http server bind to the ks.host:ks.port address (through python3 http server).
- Create a guest domain and runs the vm installation (through create-vm.sh).

```
sudo ./run-test.sh
```
