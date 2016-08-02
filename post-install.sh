#!/bin/sh

#Kickstart post install script
#@author slemonk

#Colors
COLOR_NONE="$(tput sgr0)"
COLOR_RED="$(tput setaf 1)"
COLOR_GREEN="$(tput setaf 2)"
COLOR_ORANGE="$(tput setaf 172)"

#Resources
URL_NVM=https://raw.githubusercontent.com/creationix/nvm/v0.31.3/install.sh
URL_NVM_GIT=https://github.com/creationix/nvm.git
URL_RPMFUSION_FREE=http://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
URL_RPMFUSION_NONFREE=http://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm 
URL_PLEX=https://downloads.plex.tv/plex-media-server/1.0.2.2413-7caf41d/plexmediaserver-1.0.2.2413-7caf41d.x86_64.rpm
URL_ATOM=https://atom.io/download/rpm
URL_ATOM_PLUGINS=http://192.168.1.60/atom-plugins.tgz
#URL_IDEA=https://download.jetbrains.com/idea/ideaIU-162.1447.21-no-jdk.tar.gz
URL_IDEA=http://192.168.1.60/repo/idea.tgz

IDEA_VERSION=idea-IU-162.1447.21


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

function must_be_root {
  if [[ $EUID -ne 0 ]]; then
    print_error_and_exit  "This script must be run as root" 1>&2   
  fi
}

#Install functions

#Install nvm and nodejs globally
function nodejs_global {

  nvm_dir=/opt/nvm

  echo "Install the node version manager for all users "
  
  git clone "$URL_NVM_GIT" "$nvm_dir" && cd "$nvm_dir" && git checkout `git describe --abbrev=0 --tags` 

  chgrp -R dev "$nvm_dir" #anyone can use node but only dev members can install new node version

  chmod 774 "$nvm_dir"  

  #unfortunaly add these lines in profile.d does not work...
  echo "export NVM_DIR=\"$nvm_dir\"" >> /etc/bashrc
  echo "[ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh" # This loads nvm" >> /etc/bashrc

  source /etc/bashrc

  nvm install node

  if [[ $? = 0 ]]; then
    print_success "NodeJs install OK !"
  else
    print_error "NodeJs install KO"
    return 1
  fi
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

  if [[ $? = 0 ]]; then
    print_success "NodeJs install OK !"
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
  else
    print_success "rpm fusion install OK !"
  fi
}

#install plex media server
function plex {

  echo "Install the plex media server"

  cd /tmp/ &&  wget -O plex.rpm $URL_PLEX

  if [[ $? -ne 0 ]]; then
    print_download_abort "the plex rpm"
    return 1
  fi

  rpm -i ./plex.rpm

  if [[ $? -ne 0 ]]; then
    print_install_abort "Plex"  
    return 2
  else 
    print_success "Plex install OK!"
  fi 

}

#install atom
function atom {
  echo "Install atom"

  #todo add it to the kickstart package
  dnf install lsb-core-noarch -y

  cd /tmp/ && wget -O atom.rpm $URL_ATOM
  	
  if [[ $? -ne 0 ]]; then
    print_download_abort "the atom rpm"
    return 1
  fi

  rpm -i ./atom.rpm

  if [[ $? -ne 0 ]]; then
    print_error "Error during atom installation... aborting..."  
    return 2
  else 
    print_success "Atom install OK!"
  fi 

}

#Install the atom plugins
function atom_plugins {

  echo "Install atom"

  cd /tmp/ &&  wget -O atom-plugins.tgz "$URL_ATOM_PLUGINS"

  if [[ $? -ne 0 ]]; then
    print_download_abort "the atom plugins archive"
    return 1
  fi

  tar -xzf atom-plugins.tgz

  if [[ $? -ne 0 ]]; then
    print_error "Error while uncompressing archive, aborting..."
    return 2
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
    
      cp -R /tmp/atom-plugins/* "$user_home"/.atom 

      chown -R "$user":"$user" "$user_home"/.atom
    fi
 done

 print_success "Atom plugins install OK!"

}

function idea {

  echo "Install intellij idea"

  mkdir /opt/idea_install/

  cd /tmp/ &&  wget -O idea.tgz "$URL_IDEA"  

  if [[ $? -ne 0 ]]; then
    print_download_abort "Idea" 
  fi

  echo "Please wait while uncompressing the idea archive..."

  tar -xzf idea.tgz -C /opt/idea_install

  ln -s /opt/idea_install/"$IDEA_VERSION" /opt/idea

  #clean up
  rm /tmp/idea.tgz

}

#Only played if java sdk has been already installed
function java_conf {

  if [[ -f "/etc/profile.d/java-jdk.sh" ]]; then
    print_error "java-jdk.sh already exists"
    return 1
  fi
  
  echo "export JAVA_HOME=/usr/lib/jvm/java-openjdk/bin" >> /etc/profile.d/java-jdk.sh	

  print_success "JAVA post-install configuration OK !"

  source /etc/profile

}

#SCRIPT BODY

must_be_root

#dnf update -y

#rpmfusion

#plex

#nodejs_global

#atom

#atom_plugins slemoine

#java_conf

#idea



