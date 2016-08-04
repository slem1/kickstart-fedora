#!/bin/sh

#Kickstart post install script
#@author slemonk

#Colors
COLOR_NONE="$(tput sgr0)"
COLOR_RED="$(tput setaf 1)"
COLOR_GREEN="$(tput setaf 2)"
COLOR_ORANGE="$(tput setaf 172)"

#dir
WORKING_DIR=/var/kickstart-tmp
INSTALL_DIR=/opt

#Versions
FEDORA_VERSION=$(rpm -E %fedora)
IDEA_VERSION=162.1628.6
PLEX_VERSION=1.0.2
ATOM_VERSION=1.8.0
ATOM_PLUGINS_VERSION=1.0.0
NVM_VERSION=0.31.3

#Private repo
LOCAL_REPO_HOST=192.168.1.60
LOCAL_REPO_PORT=80
APP_REPO_URL=http://$LOCAL_REPO_HOST:$LOCAL_REPO_PORT/apps

#External ressources
URL_NVM_GIT=https://github.com/creationix/nvm.git

#Local ressources
URL_NVM=$APP_REPO_URL/nvm/$NVM_VERSION/install.sh
URL_RPMFUSION_FREE=$APP_REPO_URL/rpmfusion/$FEDORA_VERSION/rpmfusion-free-release-$FEDORA_VERSION.noarch.rpm
URL_RPMFUSION_NONFREE=$APP_REPO_URL/rpmfusion/$FEDORA_VERSION/rpmfusion-nonfree-release-$FEDORA_VERSION.noarch.rpm
URL_PLEX=$APP_REPO_URL/plex/$PLEX_VERSION/plex.rpm
URL_ATOM=$APP_REPO_URL/atom/$ATOM_VERSION/atom.rpm
URL_ATOM_PLUGINS=$APP_REPO_URL/atom-plugins/$ATOM_PLUGINS_VERSION/atom-plugins.tgz
URL_IDEA=$APP_REPO_URL/idea/$IDEA_VERSION/idea.tar.gz

#Original External resources / url may be outdated
#URL_NVM=https://raw.githubusercontent.com/creationix/nvm/v0.31.3/install.sh
#URL_NVM_GIT=https://github.com/creationix/nvm.git
#URL_RPMFUSION_FREE=http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
#URL_RPMFUSION_NONFREE=http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
#URL_PLEX=https://downloads.plex.tv/plex-media-server/1.0.2.2413-7caf41d/plexmediaserver-1.0.2.2413-7caf41d.x86_64.rpm
#URL_ATOM=https://atom.io/download/rpm
#URL_IDEA=https://download.jetbrains.com/idea/ideaIU-162.1447.21-no-jdk.tar.gz

#Misc
JAVA_HOME=/usr/lib/jvm/java-openjdk/bin
IDEA_INSTALL_DIR=idea-IU-$IDEA_VERSION


#Common functions
function print_error {
  echo "$COLOR_RED$1$COLOR_NONE"
}

function print_warn {
  echo "$COLOR_ORANGE$1$COLOR_NONE"
}

function print_success {
  echo "$COLOR_GREEN$1$COLOR_NONE"
}

function print_error_and_exit {
  print_error "$1"
  exit 1
}

#Yes, I'm lazy...
function print_install_abort {
  print_error "An error occured while installing $1, abort..."
}

#...Oh yes I am
function print_download_abort {
  print_error "An error occured while downloading $1, abort..."
}

function print_install_done {
  print_success "$1 install done!"
}

function must_be_root {
  if [[ $EUID -ne 0 ]]; then
    print_error_and_exit  "This script must be run as root" 1>&2
  fi
}

#Install functions

#Install nvm and nodejs globally
function nodejs_global {

  echo "Install the node version manager for all users"

  nvm_dir="$INSTALL_DIR"/nvm

  git clone "$URL_NVM_GIT" "$nvm_dir" && cd "$nvm_dir" && git checkout `git describe --abbrev=0 --tags`

  chgrp -R dev "$nvm_dir" #anyone can use node but only dev members can install new node version

  chmod 774 "$nvm_dir"

  #unfortunaly add these lines in profile.d does not work...
  echo "export NVM_DIR=\"$nvm_dir\"" >> /etc/bashrc
  echo "[ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh" # This loads nvm" >> /etc/bashrc

  source /etc/bashrc

  nvm install node

  if [[ $? -ne 0 ]]; then
    print_error "NodeJs install KO"
    return 1
  fi

  print_install_done "Node JS"
}

#Install node to one user
function nodejs {

  var user=slemoine

  echo "Install the node version manager"

  su "$user"

  curl -o- $URL_NVM | bash

  source ~/.bashrc

  nvm install node

  logout

  if [[ $? -eq 0 ]]; then
    print_install_done "Node JS"
  else
    print_error "NodeJs install KO"
    return 1
  fi
}

#install the rpm fusion repo
function rpmfusion {

  echo "Install rpm fusion"

  dnf install $URL_RPMFUSION_FREE $URL_RPMFUSION_NONFREE -q -y

  if [[ $? -ne 0 ]]; then
    print_error "Error while installing rpm fusion"
    return 1
  fi

  print_install_done "RPM Fusion"

}

#install plex media server
function plex {

  echo "Install the plex media server"

  cd "$WORKING_DIR" &&  wget -O plex.rpm $URL_PLEX

  if [[ $? -ne 0 ]]; then
    print_download_abort "the plex rpm"
    return 1
  fi

  rpm -i ./plex.rpm

  if [[ $? -ne 0 ]]; then
    print_install_abort "Plex"
    return 2
  fi

  print_install_done "Plex"

}

#Install atom editor
#Note : Atom requires lsb-core-noarch package, please be sure that this
#package has already been installed either manually or by kickstart packages install
function atom {

  echo "Install atom"

  cd "$WORKING_DIR" && wget -O atom.rpm $URL_ATOM

  if [[ $? -ne 0 ]]; then
    print_download_abort "the atom rpm"
    return 1
  fi

  rpm -i ./atom.rpm

  if [[ $? -ne 0 ]]; then
    print_error "Error during atom installation... aborting..."
    return 2
  fi

  print_install_done "Atom"

}

#Install atom additional plugins
function atom_plugins {

  echo "Install atom"

  if [[ $# -lt 1 ]]; then
    print_error "At least one user must be specified"
    return 1
  fi

  cd "$WORKING_DIR" &&  wget -O atom-plugins.tgz "$URL_ATOM_PLUGINS"

  if [[ $? -ne 0 ]]; then
    print_download_abort "the atom plugins archive"
    return 2
  fi

  tar -xzf atom-plugins.tgz

  if [[ $? -ne 0 ]]; then
    print_error "Error while uncompressing archive, aborting..."
    return 3
  fi

  #copy the atom plugins for users
  for user in "$@"; do

    id "$user"

    if [[ $? -ne 0 ]]; then
      print_warn "$user user does not exist, skip it"
      continue
    fi

    #get the user home
    user_home="$(grep "$user" /etc/passwd | cut -d ":" -f6)"

    if [[ ! -s "$user_home" ]]; then
      echo "No home, no atom for $user"
    else
      echo "install atom plugins in $i in $user_home."

      if [[ ! -d "$user_home"/.atom ]]; then
	mkdir "$user_home"/.atom
      fi

      cp -R "$WORKING_DIR"/atom-plugins/* "$user_home"/.atom

      chown -R "$user":"$user" "$user_home"/.atom
    fi
 done

 print_install_done "Atom plugins"

}

#Install intellij idea
function idea {

  echo "Install intellij idea"

  mkdir "$INSTALL_DIR"/idea_install/

  cd "$WORKING_DIR" &&  wget -O idea.tgz "$URL_IDEA"

  if [[ $? -ne 0 ]]; then
    print_download_abort "Idea"
  fi

  echo "Please wait while uncompressing the idea archive..."

  tar -xzf idea.tgz -C "$INSTALL_DIR"/idea_install

  ln -s "$INSTALL_DIR"/idea_install/"$IDEA_INSTALL_DIR" "$INSTALL_DIR"/idea

  print_install_done "Idea"

}

#Java SDK must be installed
function java_conf {

  if [[ -f "/etc/profile.d/java-env.sh" ]]; then
    print_error "java-env.sh already exists"
    return 1
  fi

  echo "export JAVA_HOME=$JAVA_HOME" >> /etc/profile.d/java-env.sh

  source /etc/profile

  print_install_done "Java post-install configuration"
}

#Please don't use this in a none secured private (local) environment
function copy_ssh_keys {

  if [[ $# -ne 2 ]]; then
    echo "Usage : copy_ssh_key <username> <url_for_ssh_keys>"
    exit 1
  fi

  cd "$WORKING_DIR"

  id "$1"

  if [[ $? -ne 0 ]]; then
    print_error "User $1 does not exists !"
    return 1
  fi

  #get the user home
  user_home="$(grep "$1" /etc/passwd | cut -d ":" -f6)"

  if [[ ! -s "$user_home" ]]; then
    print_error "No home, no ssh for $1"
    return 2
  fi

  ssh_home="$user_home"/.ssh

  mkdir "$ssh_home" && chown "$1":"$1" "$ssh_home" && chmod 700 "$ssh_home"

  if [[ $? -ne 0 ]]; then
    print_error "Error while creating ssh directory"
  fi

  #get the keys in .tar archive

  curl -o keys.tar "$2"

  if [[ $? -ne 0 ]]; then
    print_download_abort "ssh keys"
    return 3
  fi

  tar -xf keys.tar -C "$ssh_home"

   if [[ $? -ne 0 ]]; then
    print_install_abort "ssh keys"
    return 4
  fi

  print_install_done "ssh keys"

}

#SCRIPT BODY

must_be_root

if [[ ! -d "$WORKING_DIR" ]]; then
  mkdir $WORKING_DIR
fi

dnf update -y

rpmfusion

plex

nodejs_global

atom

atom_plugins slemoine

java_conf

idea

copy_ssh_keys slemoine "http://$LOCAL_REPO_HOST:$LOCAL_REPO_PORT/special/keys.tar"
