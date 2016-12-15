#!/bin/sh

#Kickstart post install script
#@author slemoine

#Colors
COLOR_NONE="$(tput sgr0)"
COLOR_RED="$(tput setaf 1)"
COLOR_GREEN="$(tput setaf 2)"
COLOR_ORANGE="$(tput setaf 172)"

#dir
WORKING_DIR=/var/kickstart-tmp
INSTALL_DIR=/opt

#Versions
FEDORA_VERSION=@fedora.version@
IDEA_VERSION=@idea.version@
PLEX_VERSION=@plex.version@
ATOM_VERSION=@atom.version@
ATOM_PLUGINS_VERSION=@atom.plugins.version@
NVM_VERSION=@nvm.version@
GITKRAKEN_VERSION=@gitkraken.version@

#Private repo
INSTALL_REPO_HOST=@ks.host@
INSTALL_REPO_PORT=@ks.port@
APPS_REPO_URL=http://$INSTALL_REPO_HOST:$INSTALL_REPO_PORT/apps

#External ressources
URL_NVM_GIT=https://github.com/creationix/nvm.git

#Apps private repo ressources
URL_NVM=$APPS_REPO_URL/nvm/$NVM_VERSION/install.sh
URL_RPMFUSION_FREE=$APPS_REPO_URL/rpmfusion/$FEDORA_VERSION/rpmfusion-free-release-$FEDORA_VERSION.noarch.rpm
URL_RPMFUSION_NONFREE=$APPS_REPO_URL/rpmfusion/$FEDORA_VERSION/rpmfusion-nonfree-release-$FEDORA_VERSION.noarch.rpm
URL_PLEX=$APPS_REPO_URL/plex/$PLEX_VERSION/plex.rpm
URL_ATOM=$APPS_REPO_URL/atom/$ATOM_VERSION/atom.rpm
URL_ATOM_PLUGINS=$APPS_REPO_URL/atom-plugins/$ATOM_PLUGINS_VERSION/atom-plugins.tgz
URL_IDEA=$APPS_REPO_URL/idea/$IDEA_VERSION/idea.tar.gz
URL_GITKRAKEN=$APPS_REPO_URL/gitkraken/$GITKRAKEN_VERSION/gitkraken.tar.gz
URL_POWERLINE_CONF=$APPS_REPO_URL/powerline/conf/powerline-conf.tar.gz

#Misc
JAVA_HOME=/usr/lib/jvm/java-openjdk/bin
IDEA_INSTALL_DIR=idea-IU-$IDEA_VERSION


#Common functions
function print_error {
  echo "$COLOR_RED$1$COLOR_NONE" 1>&2
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

#Exit the script if user is not Root
function must_be_root {
  if [[ $EUID -ne 0 ]]; then
    print_error_and_exit  "This script must be run as root"
  fi
}

#Prints the home path of user $1 on stdout
function home {

  if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <user>"
    echo "[user] = user name"
    return 1
  fi

  if id "$1" >> /dev/null; then
    echo $(grep "$1" /etc/passwd | cut -d: -f6)
  else
    print_error "user $1 does not exist !"
    return 1
  fi

}

#Create a gnome icon
#gnome_icon name exec icon type categories terminal destination
function gnome_icon {

  if [[ $# -eq 0 || $@ == "-h" || $@ == "--help" ]]; then
    echo "Usage: $0 <name> <exec> <icon> <type> <categories> <terminal> <destination>"
    echo "[name] = see gnome desktop entry doc"
    echo "[exec] = see gnome desktop entry doc"
    echo "[icon] = see gnome desktop entry doc"
    echo "[type] = see gnome desktop entry doc"
    echo "[categories] = see gnome desktop entry doc"
    echo "[terminal] = see gnome desktop entry doc"
    echo "[destination] = destination path like /user/share/applications/myicon.desktop"
    return 1
  fi

  echo "Create gnome icon for $1 into $7"

  cat <<-END > "$7"
	[Desktop Entry]
	Name=$1
	Exec=$2
	Icon=$3
	Type=$4
	Categories=$5
	Terminal=$6
END

  echo  "Icon creation done !"
}

#******************************************
#***********Apps Install functions*********
#******************************************

#Install nvm and nodejs globally
function nodejs_global {

  echo "Install the node version manager for all users"

  nvm_dir="$INSTALL_DIR"/nvm

  git clone "$URL_NVM_GIT" "$nvm_dir" && cd "$nvm_dir" && git checkout `git describe --abbrev=0 --tags`

  #anyone can use node but only dev members can install new node version

  chgrp -R dev "$nvm_dir" && chmod 774 "$nvm_dir"

  #unfortunaly add these lines in profile.d does not work...
  echo "export NVM_DIR=\"$nvm_dir\"" >> /etc/bashrc
  echo "[ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh" # This loads nvm" >> /etc/bashrc

  . /etc/bashrc && nvm install node

  if [[ $? -ne 0 ]]; then
    print_error "NodeJs install KO"
    return 1
  fi

  print_install_done "Node JS"
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

  cd "$WORKING_DIR" && curl -o plex.rpm $URL_PLEX

  if [[ $? -ne 0 ]]; then
    print_download_abort "the plex rpm"
    return 1
  fi

  rpm -i ./plex.rpm

  if [[ $? -ne 0 ]]; then
    print_install_abort "Plex"
    return 2
  fi

  gnome_icon "Plex web console" "/usr/bin/firefox localhost:32400/web" "/usr/lib/plexmediaserver/Resources/Graphics/dlna-icon-260.jpg" "Application" "Multimedia" "false" "/usr/share/applications/plex.desktop"

  print_install_done "Plex"

}

#Install atom editor
#Note : Atom requires lsb-core-noarch package, please be sure that this
#package has already been installed either manually or by kickstart packages install
function atom {

  echo "Install atom"

  cd "$WORKING_DIR" && curl -o atom.rpm $URL_ATOM

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

  cd "$WORKING_DIR" &&  curl -o atom-plugins.tgz "$URL_ATOM_PLUGINS"

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

  cd "$WORKING_DIR" &&  curl -o idea.tgz "$URL_IDEA"

  if [[ $? -ne 0 ]]; then
    print_download_abort "Idea"
  fi

  echo "Please wait while uncompressing the idea archive..."

  tar -xzf idea.tgz -C "$INSTALL_DIR"/idea_install

  ln -s "$INSTALL_DIR"/idea_install/"$IDEA_INSTALL_DIR" "$INSTALL_DIR"/idea

  gnome_icon "Intellij IDEA" "$INSTALL_DIR/idea/bin/idea.sh" "$INSTALL_DIR/idea/bin/idea.png" "Application" "Development;IDE" "false" "/usr/share/applications/intellij.desktop"

  print_install_done "Idea"

}

function gitkraken {

  echo "Git Kraken install"

  #libXss.so.1 dependency
  dnf install libXScrnSaver -y -q

  rm -rf "$INSTALL_DIR"/GitKraken

  curl -o "$WORKING_DIR"/gitkraken.tar.gz "$URL_GITKRAKEN"

  if [[ $? -ne 0 ]]; then
    print_download_abort "Git Kraken"
    return 1
  fi

  #uncompress
  tar -xzf "$WORKING_DIR"/gitkraken.tar.gz -C "$INSTALL_DIR"

  if [[ $? -ne 0 ]]; then
    print_install_abort "Git Kraken"
    return 2
  fi

  gnome_icon "Git Kraken" "$INSTALL_DIR/gitkraken/gitkraken" "$INSTALL_DIR/gitkraken/icon.png" "Application" "Development;Utility" "false" "/usr/share/applications/gitkraken.desktop"

  print_install_done "Git Kraken"

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

#install powerline conf for user
function powerline_conf {

  title="Powerline configuration"

  echo "$title install"

  if [[ $# -ne 1 ]]; then
    echo "Usage: powerline_conf <user>"
    echo "[user]= User for which we want install the powerline configuration"
  fi

  home_path=$(home "$1")

  if [[ ! -z $home_path ]]; then

    powerline_home="$home_path"/.config/powerline

    cd "$WORKING_DIR" && curl -o powerline-conf.tar.gz "$URL_POWERLINE_CONF"

    if [[ $? -ne 0 ]]; then
      print_download_abort "$title"
      return 2
    fi

    if [[ -d "$powerline_home" ]]; then
      rm -rf "$powerline_home"
    fi

    if [[ ! -d "$home_path"/.config ]]; then
     mkdir "$home_path"/.config && chown "$1":"$1" "$home_path"/.config && chmod -R 700 "$home_path"/.config
    fi

    tar -xf powerline-conf.tar.gz -C "$home_path"/.config && chown -R "$1":"$1" "$powerline_home" && chmod -R 700 "$powerline_home"

    if [[ $? -ne 0 ]]; then
      print_install_abort "$title"
      return 3
    fi

    #Enable powerline
    cat <<-END >> $home_path/.bashrc
	if [ -f `which powerline-daemon` ]; then
	   powerline-daemon -q
	   POWERLINE_BASH_CONTINUATION=1
	   POWERLINE_BASH_SELECT=1
	   . /usr/share/powerline/bash/powerline.sh
	fi
END

    print_install_done "$title"

  else
    print_error "An error occured while retrieving home for $1"
    return 1
  fi

}

function cleanup {

  rm -rf "$WORKING_DIR"

  exec 1<&-

  exec 2<&-

}

#SCRIPT BODY

must_be_root

if [[ ! -d "$WORKING_DIR" ]]; then
  mkdir -p $WORKING_DIR
fi


if [[ ! -d "$INSTALL_DIR" ]]; then
  mkdir -p $INSTALL_DIR
fi

dnf update -y

rpmfusion

plex

nodejs_global

atom

atom_plugins @user1.name@

gitkraken

java_conf

idea

powerline_conf @user1.name@

cleanup
