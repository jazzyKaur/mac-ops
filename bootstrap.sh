#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2059,SC2154,SC2116
#------------------------------------------------------------------------------
# PURPOSE:  A QnD script to configure a base environment so I can get back to
#           work quickly. It will be replaced by Ansible automation as soon as
#           possible between laptop upgrades.
#------------------------------------------------------------------------------
# EXECUTE:  ./bootstrap.sh 2>&1 | tee ~/.config/admin/logs/mac-ops-config.out
#------------------------------------------------------------------------------
# PREREQS: 1) ssh keys must be on the new system for Github clones
#          2)
#------------------------------------------------------------------------------
#  AUTHOR: todd_dsm
#------------------------------------------------------------------------------
#    DATE: 2017/01/11
#------------------------------------------------------------------------------
set -x

###------------------------------------------------------------------------------
### VARIABLES
###------------------------------------------------------------------------------
timePre="$(date +'%T')"
source './my-vars.sh'


###----------------------------------------------------------------------------
### FUNCTIONS
###----------------------------------------------------------------------------
### Print stuff of secondary importance: Requirements
###---
printReq() {
    theReq="$1"
    printf '\e[1;34m%-6s\e[m' """
$theReq
"""
}

###---
### Print stuff of secondary importance: Headlines
###---
printHead() {
    theHead="$1"
    printf '%s' """
  $theHead
"""
}

###---
### Print stuff of tertiary importance: Informational
###---
printInfo() {
    theInfo="$1"
    printf '%s\n' """
    $theInfo
"""
}

###---
### Print Requirement
###---
getNewPaths() {
    declare PATH=''
    ### Construct new paths
    printReq "Constructing the \$PATH environment variable..."
    while IFS= read -r binPath; do
        printHead "Adding: $binPath"
        if [[ -z "$myPath" ]]; then
           declare "myPath=$binPath"
       else
           declare myPath="$myPath:$binPath"
        fi
    done < "$sysPaths"

    export PATH="$myPath"


    ### Construct new manpaths
    printReq "Constructing the \$MANPATH environment variable..."
    while IFS= read -r manPath; do
        printHead "Adding: $manPath"
        if [[ -z "$myMans" ]]; then
           declare "myMans=$manPath"
       else
           declare myMans="$myMans:$manPath"
        fi
    done < "$sysManPaths"

    export MANPATH="$myMans"
}


###----------------------------------------------------------------------------
### The Setup
###----------------------------------------------------------------------------
### Add the Github key to the knownhosts file
###---
printReq  "Checking to see if we have the Github public key..."
if ! grep "^$hostRemote" "$knownHosts" > /dev/null 2>&1; then
    printHead "We don't, pulling it now..."
    ssh-keyscan -t 'rsa' "$hostRemote" >> "$knownHosts"
else
    printHead "We have the Github key, all good."
fi

####---
## Backup some files before we begin
###---
if [[ "$theENV" == 'TEST' ]]; then
    printReq "Backing up the /etc directory before we begin..."
    sudo rsync -aE /private/etc "$backupDir/" 2> /tmp/rsync-err-etc.out
fi

###---
### Pull some stuff for the Terminal
###---
printReq "Pulling Terminal stuff..."
git clone "$solarizedGitRepo" "$termStuff/solarized" > /dev/null 2>&1

# Pull the settings back
if [[ ! -d "$myBackups" ]]; then
    printHead "There are no 'settings' to restore."
else
    printHead "Restoring Terminal (and other) settings..."
    rsync -aEv  "$myBackups/Documents/system" "$myDocs/" 2> /tmp/rsync-err-system.out
fi

###----------------------------------------------------------------------------
### Configure the Shell: base options
###----------------------------------------------------------------------------
printReq "Configuring base shell options..."

printHead "Configuring $myBashProfile ..."
cat << EOF >> "$myBashProfile"
# URL: https://www.gnu.org/software/bash/manual/bashref.html#Bash-Startup-Files
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

EOF


printHead "Configuring $myBashrc ..."
cat << EOF >> "$myBashrc"
# shellcheck disable=SC2148,SC1090,SC1091,SC2012,SC2139
declare sysBashrc='/etc/bashrc'
if [[ -f "\$sysBashrc" ]]; then
    . "\$sysBashrc"
fi

###############################################################################
###                                  System                                 ###
###############################################################################
export TERM='xterm-256color'
export HISTFILESIZE=
export HISTSIZE=
export PROMPT_COMMAND="history -a; \$PROMPT_COMMAND"
# If you want the last command ran immediately available to all currently open
# shells then comment the one above and uncomment the two below.
#shopt -s histappend
#export PROMPT_COMMAND="history -a; history -c; history -r; \$PROMPT_COMMAND"
export HISTCONTROL=ignoredups
export HISTTIMEFORMAT="%a%l:%M %p  "
export HISTIGNORE='ls:bg:fg:history'

EOF

# Source-in and Display changes
printInfo '\n%s\n' "System ~/.bashrc changes:"
source "$myBashProfile" && tail -18 "$myBashrc"

###----------------------------------------------------------------------------
### Install Homebrew
###----------------------------------------------------------------------------
printReq "Installing Homebrew..."
yes | /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

printHead "Updating Homebrew..."
brew update

printHead "Running 'brew doctor'..."
brew doctor

printHead "Tapping Homebrew binaries..."
brew tap homebrew/binary
brew tap caskroom/fonts

printHead "Configuring Homebrew..."
cat << EOF >> "$myBashrc"
###############################################################################
###                                Homebrew                                 ###
###############################################################################
source /usr/local/etc/bash_completion.d/brew

EOF

# Source-in and Display changes
printInfo "homebrew ~/.bashrc changes:"
source "$myBashProfile" && tail -5 "$myBashrc"


###----------------------------------------------------------------------------
### Display some defaults for the log
### For some reason Homebrew triggers a set -x; counter that
###----------------------------------------------------------------------------
printHead "Default macOS paths:"
printInfo "System Paths:"
cat "$sysPaths"
printInfo "\$PATH=$PATH"

printHead "System man paths:"
cat "$sysManPaths"
if [[ -z "$MANPATH" ]]; then
    # at this stage it's always empty
    printInfo "MANPATH is empty!"
else
    printInfo "\$MANPATH=$MANPATH"
fi


###----------------------------------------------------------------------------
### Install the font: Hack
### Hack is a solid font for programmers; version 2.010 is the golden-age.
### If you want the latest version then:
###   *delete the mkdir and tar lines
###   *uncomment the brew lines.
###----------------------------------------------------------------------------
printHead "Installing font: Hack..."
brew tap caskroom/fonts
brew cask install font-hack
#if [[ ! -d "$myDocs/system/Hack-v2_010-ttf.tgz" ]]; then
#    printInfo "Download Hack when you can"
#else
#    mkdir "$HOME/Library/Fonts"
#    tar xzvf "$myDocs/system/Hack-v2_010-ttf.tgz" -C "$HOME/Library/Fonts"
#fi


###----------------------------------------------------------------------------
### Let's Get Open: GNU Coreutils
###----------------------------------------------------------------------------
printReq "Let's get open..."

printHead "Installing sed - the stream editor..."
brew install gnu-sed --with-default-names

printHead "Installing GNU Coreutils..."
brew install coreutils

###----------------------------------------------------------------------------
### Set new Variables
###----------------------------------------------------------------------------
declare pathGNU_CORE="$(brew --prefix coreutils)"

# Set path for the GNU Coreutils
sudo sed -i "\|/usr/local/bin|i $pathGNU_CORE/libexec/gnubin" "$sysPaths"

# Set path for the GNU Coreutils Manuals
sudo sed -i "\|/usr/share/man|i $pathGNU_CORE/libexec/gnuman" "$sysManPaths"

# Move system manpaths down 1 line
sudo sed -i -n '2{h;n;G};p' "$sysManPaths"


###---
#### Verify the new paths have been set
###---
getNewPaths

###----------------------------------------------------------------------------
### PATHs
###   * System:  /usr/bin:/bin:/usr/sbin:/sbin
###   * Homebrew: anything under /usr/local
###----------------------------------------------------------------------------
printHead "The new paths:"
printInfo "\$PATH:"
cat "$sysPaths"
printInfo "$PATH"

###----------------------------------------------------------------------------
### MANPATHs
###   * System:   /usr/share/man
###   * Homebrew: /usr/local/share/man
###----------------------------------------------------------------------------
printHead "\$MANPATH:"
cat "$sysManPaths"
if [[ -z "$MANPATH" ]]; then
    printInfo "MANPATH is empty!"
else
    printInfo "\$MANPATH=$MANPATH"
fi


### Configure coreutils
printHead "Configuring GNU Coreutils..."
cat << EOF >> "$myBashrc"
###############################################################################
###                                coreutils                                ###
###############################################################################
export MANPATH=$MANPATH
# Filesystem Operational Behavior
function ll { ls --color -l   "\$@" | egrep -v '.(DS_Store|CFUserTextEncoding)'; }
function la { ls --color -al  "\$@" | egrep -v '.(DS_Store|CFUserTextEncoding)'; }
function ld { ls --color -ld  "\$@" | egrep -v '.(DS_Store|CFUserTextEncoding)'; }
function lh { ls --color -alh "\$@" | egrep -v '.(DS_Store|CFUserTextEncoding)'; }
alias cp='cp -rfvp'
alias mv='mv -v'
# FIX: alias for GNU zip/unzip do not work
alias zip='/usr/local/bin/gzip'
alias unzip='/usr/local/bin/gunzip'
alias hist='history | cut -c 21-'

EOF

# Source-in and Display changes
printInfo "coreutils ~/.bashrc changes:"
source "$myBashProfile" && tail -16 "$myBashrc"


###----------------------------------------------------------------------------
### Install GNU Tools and Languages
###----------------------------------------------------------------------------
printReq "Installing and configuring additional GNU programs..."
brew install homebrew/dupes/ed --with-default-names
brew install gnu-indent --with-default-names
brew install findutils --with-default-names
brew install gnu-which --with-default-names
brew install wget --with-pcre
brew install gnu-tar --with-default-names
brew install gnu-time --with-default-names
brew install homebrew/dupes/grep --with-default-names
brew install gnupg2 --with-readline --without-dirmngr
brew install homebrew/dupes/gzip gawk homebrew/dupes/diffutils

printHead "Configuring grep and find..."
cat << EOF >> "$myBashrc"
###############################################################################
###                                   grep                                  ###
###############################################################################
alias grep='grep   --color=auto' 2>/dev/null
alias egrep='egrep --color=auto' 2>/dev/null
alias fgrep='fgrep --color=auto' 2>/dev/null

###############################################################################
###                                   find                                  ###
###-------------------------------------------------------------------------###
### Easily find stuff within the root '/' filesystem (fs) without errors.
###----------------------------------------------------------------------------
# Find files somewhere on the system; to use:
#   1) call the alias, 'findsys'
#   2) pass a directory where the search should begin, and
#   3) pass a file name, either exact or fuzzy: e.g.:
# $ findsys /var/ '*.log'
function findSystemStuff()   {
    findDir="\$1"
    findFSO="\$2"
    sudo find "\$findDir" -name 'cores' -prune , -name 'dev' -prune , -name 'net' -prune , -name "\$findFSO"
}

alias findsys=findSystemStuff
###-------------------------------------------------------------------------###
### Easily find stuff within your home directory. To use:
#     1) call the alias, 'findmy'
#     2) pass a 'type' of fs object, either 'f' (file) or 'd' (directory)
#     3) pass the object name, either exact or fuzzy: e.g.:
#     \$ findmy f '.vim*'
function findMyStuff()   {
    findType="\$1"
    findFSO="\$2"
    find "\$HOME" -type "\$findType" -name "\$findFSO"
}

alias findmy=findMyStuff

EOF

# Source-in and Display changes
printInfo "grep/find ~/.bashrc changes:"
source "$myBashProfile" && tail -38 "$myBashrc"


###----------------------------------------------------------------------------
### Install the Casks (GUI Apps)
###----------------------------------------------------------------------------
printReq "Installing GUI (cask) Apps..."
printHead "Installing Utilities..."
brew cask install \
    atom android-file-transfer flux java wireshark osxfuse \
    virtualbox virtualbox-extension-pack

printHead "Installing Google Chrome..."
brew cask install google-chrome
#mkdir -p "$HOME/Library/Application\ Support/Google/Chrome"
#chown -R vagrant:staff "/Users/vagrant/Library/Application Support"/


###---
### Install the latest version of VMware Fusion
### Using older versions of Fusion on current macOS never seems to work.
###---
printHead "Installing VMware Fusion: 7..."
brew cask install vmware-fusion

###---
### VirtualBox configurations
###---
printHead "Configuring VirtualBox..."
printInfo "Setting the machinefolder property..."
vboxmanage setproperty machinefolder "$HOME/vms/vbox"

printHead "Setting VirtualBox environment variables..."
cat << EOF >> "$myBashrc"
###############################################################################
###                                VirtualBox                               ###
###############################################################################
export VBOX_USER_HOME="\$HOME/vms/vbox"

EOF


###---
### VMware configurations
###---
printHead "Configuring VMware..."
cat << EOF >> "$myBashrc"
###############################################################################
###                                  VMware                                 ###
###############################################################################
export VMWARE_STORAGE="\$HOME/vms/vmware"

EOF

tail -10 "$myBashrc"


###----------------------------------------------------------------------------
### Useful System Utilities
###----------------------------------------------------------------------------
printReq "Installing system-admin utilities..."
printHead "Some networking and convenience stuff..."
brew install \
    git nmap homebrew/dupes/rsync ssh-copy-id watch tree pstree psgrep  \
    sipcalc whatmask ipcalc dos2unix testdisk homebrew/fuse/sshfs       \
    homebrew/dupes/openssh

### Seperate installs for programs with options
printHead "Installing tcl-tk with options..."
brew install homebrew/dupes/tcl-tk --with-threads

### Include path for tcl-tk
printHead "Opening up /usr/local/opt/tcl-tk/bin so we can see tcl..."
sudo sed -i "\|/usr/bin|i /usr/local/opt/tcl-tk/bin" "$sysPaths"

printHead "Installing tcpdump with options..."
brew install homebrew/dupes/tcpdump --with-libpcap

printHead "Installing tmux with options..."
brew install tmux --with-utf8proc

### Include path for tcpdump
printHead "Opening up /usr/local/sbin so we can see tcpdump..."
sudo sed -i "\|/usr/bin|i /usr/local/sbin" "$sysPaths"


###----------------------------------------------------------------------------
### PYTHON
###----------------------------------------------------------------------------
printReq "Installing Python..."
printf '%s\n' """
    ####    ####    ####    ####    ####     ####     ####     ####     ####

        You can safely ignore the message 'echo export PATH' message from
                  the installer. THIS IS NOT NECESSARY.

    ####    ####    ####    ####    ####     ####     ####     ####     ####
    """

brew install python python3

printHead "Upgrading Python Pip and setuptools..."
pip  install --upgrade pip setuptools neovim
pip3 install --upgrade pip3 setuptools wheel neovim \
    ipython simplejson requests boto


printHead "Configuring Python..."
cat << EOF >> "$myBashrc"
###############################################################################
###                                  Python                                 ###
###############################################################################
export PIP_CONFIG_FILE="\$HOME/.config/python/pip.conf"
# Setup autoenv to your tastes
#export AUTOENV_AUTH_FILE="\$HOME/.config/python/autoenv_authorized"
#export AUTOENV_ENV_FILENAME='.env'
#export AUTOENV_LOWER_FIRST=''
#source /usr/local/bin/activate.sh

EOF


###---
### Configure pip
###---
printReq "Configuring pip..."
printHead "Creating pip home..."
if [[ ! -d "$myConfigs/python" ]]; then
    mkdir -p "$myConfigs/python"
fi

printHead "Creating the pip config file..."
cat << EOF >> "$myConfigs/python/pip.conf"
# pip configuration
[list]
format=columns

EOF

###---
### Configure autoenv
###---
printHead "Configuring autoenv..."

printHead "Creating the autoenv file..."
touch "$myConfigs/python/autoenv_authorized"


# Source-in and Display changes
printHead "python ~/.bashrc changes:"
source "$myBashProfile" && tail -5 "$myBashrc"

printInfo "Testing pip config..."
pip list


###----------------------------------------------------------------------------
### Ruby
###----------------------------------------------------------------------------
printReq "Installing Ruby..."
brew install ruby chruby

###---
### Update/Install Gems
###---
printHead "Updating all Gems..."
gem update "$(gem list | cut -d' ' -f1)"

printHead "Installing new Gems to test..."
gem install neovim


printHead "Configuring Ruby..."
cat << EOF >> "$myBashrc"
###############################################################################
###                                   Ruby                                  ###
###############################################################################
#source /usr/local/opt/chruby/share/chruby/chruby.sh
#source /usr/local/opt/chruby/share/chruby/auto.sh

EOF

# Source-in and Display changes
printInfo "ruby ~/.bashrc changes:"
source "$myBashProfile" && tail -6 "$myBashrc"


###----------------------------------------------------------------------------
### golang
###----------------------------------------------------------------------------
printReq "Installing the Go Programming Language..."
brew install go

# Create the code path
printHead "Creating the \$GOPATH directory..."
mkdir -p "$HOME/code/gocode"

printHead "Configuring Go..."
cat << EOF >> "$myBashrc"
###############################################################################
###                                    Go                                   ###
###############################################################################
export GOPATH="\$HOME/code/gocode"
alias mygo="cd \$GOPATH"

EOF

# Source-in and Display changes
printInfo "golang ~/.bashrc changes:"
source "$myBashProfile" && tail -6 "$myBashrc"


###----------------------------------------------------------------------------
### Bash
###----------------------------------------------------------------------------
printf '\n%s\n' "Installing Bash..."
brew install bash shellcheck dash bash-completion@2

# Configure GNU Bash for the system and current $USER
printReq "Configuring Bash..."

printHead "Creating a softlink from sh to dash..."
ln -sf '/usr/local/bin/dash' '/usr/local/bin/sh'

printHead "System Shells default:"
grep '^\/' "$sysShells"
sudo sed -i "\|^.*bash$|i /usr/local/bin/bash" "$sysShells"
sudo sed -i "\|local|a /usr/local/bin/sh" "$sysShells"
printHead "System Shells new:"
grep '^\/' "$sysShells"

printHead "$USER's default shell:"
dscl . -read "$HOME" UserShell

printHead "Configuring $USER's shell..."
sudo chpass -s "$(which bash)" "$USER"

printHead "$USER's new shell:"
dscl . -read "$HOME" UserShell

cat << EOF >> "$myBashrc"
###############################################################################
###                                   Bash                                  ###
###############################################################################
export SHELL='/usr/local/bin/bash'
export BASH_VERSION="\$(bash --version | head -1 | awk -F " " '{print \$4}')"
# ShellCheck: Ignore: https://goo.gl/n9W5ly
export SHELLCHECK_OPTS="-e SC2155"

EOF

# Source-in and Display changes
printInfo "bash ~/.bashrc changes:"
source "$myBashProfile" && tail -8 "$myBashrc"


###----------------------------------------------------------------------------
### nodejs and npm
###----------------------------------------------------------------------------
printReq "Installing the Node.js and npm..."
brew reinstall node --with-full-icu

# Create the code path
#printHead "Creating the \$GOPATH directory..."
#mkdir -p "$HOME/code/gocode"

printHead "Configuring npm..."
cat << EOF >> "$myBashrc"
###############################################################################
###                                  npm                                    ###
###############################################################################
source /usr/local/etc/bash_completion.d/npm

EOF

# Source-in and Display changes
printInfo "npm ~/.bashrc changes:"
source "$myBashProfile" && tail -5 "$myBashrc"


###----------------------------------------------------------------------------
### Vim: The Power and the Glory
###----------------------------------------------------------------------------
printReq "Upgrading to full-blown Vim..."

# Verify before install
printHead "Checking Apple's Vim..."
vim --version | grep  -E --color 'VIM|Compiled|python|ruby|perl|tcl'

# Install Vim with support for:
#   Use this version over the system one
#   w/o NLS (National Language Support)
#   +Python   (v2; default)
#   +Ruby     (default)
#   +Lua      (broke)
#   +mzscheme (broke)

printHead "Installing Vim..."
brew install vim --with-override-system-vi --without-nls --with-python3 \
#    --with-lua --with-mzscheme --with-tcl

# We should evaluate Neovim
printHead "Installing Neovim..."
brew install neovim/neovim/neovim

printHead "Configuring Vim..."
cat << EOF >> "$myBashrc"
###############################################################################
###                                   Vim                                   ###
###############################################################################
export EDITOR='/usr/local/bin/vim'
alias vi="\$EDITOR"
alias nim='/usr/local/bin/nvim'

EOF

# Source-in and Display changes
printInfo "vim ~/.bashrc changes:"
source "$myBashProfile" && tail -8 "$myBashrc"


# Verify after install
printHead "The Real version of Vim:"
vim --version | grep  -E --color 'VIM|Compiled|python|ruby|perl|tcl'


###----------------------------------------------------------------------------
### Amazon AWS CLI
###----------------------------------------------------------------------------
printReq "Installing the AWS CLI..."
pip3 install awscli

printHead "Installing some AWS CLI Utilitiese..."
pip install --upgrade jmespath jmespath-terminal

brew tap jmespath/jmespath
brew install jp jq

printHead "Configuring the AWS CLI..."
cat << EOF >> "$myBashrc"
###############################################################################
###                                 Amazon                                  ###
###############################################################################
complete -C "\$(type -P aws_completer)" aws
#export AWS_REGION='yourRegion'
#export AWS_PROFILE='awsUser'
export AWS_CONFIG_FILE="\$HOME/.aws/config"

EOF

printHead "Setting the AWS User to your local account name..."
sed -i "/AWS_PROFILE/ s/awsUser/$USER/g" "$myBashrc"

# Restore the AWS configs if there are any
if [[ ! -d "$myBackups" ]]; then
    printInfo "There are no AWS settings to restore."
else
    printInfo "Restoring AWS directory..."
    rsync -aEv "$myBackups/.aws" "$HOME/"
    sudo chown -R "$USER:staff" "$HOME/.aws"
fi

# Source-in and Display changes
printInfo "aws ~/.bashrc changes:"
source "$myBashProfile" && tail -7 "$myBashrc"


###----------------------------------------------------------------------------
### Add a space for common remote access tokens
###----------------------------------------------------------------------------
printReq "Configuring Access Tokens for Remote services..."
cat << EOF >> "$myBashrc"
###############################################################################
###                             Remote Access                               ###
###############################################################################
# HashiCorp Atlas
export ATLAS_TOKEN=''
# Homebrew / Github
export HOMEBREW_GITHUB_API_TOKEN=''

EOF

# Source-in and Display changes
printInfo "token ~/.bashrc changes:"
source "$myBashProfile" && tail -8 "$myBashrc"


###----------------------------------------------------------------------------
### HashiCorp: Terraform
###----------------------------------------------------------------------------
printHead "Installing Terraform..."
brew install terraform terraform-inventory graphviz

printHead "Configuring Terraform..."
cat << EOF >> "$myBashrc"
###############################################################################
###                                Terraform                                ###
###############################################################################
alias tf='/usr/local/bin/terraform'
export TF_VAR_AWS_PROFILE="\$AWS_PROFILE"
export TF_LOG='DEBUG'
export TF_LOG_PATH='/tmp/terraform.log'

EOF

# Source-in and Display changes
printInfo "terraform ~/.bashrc changes:"
source "$myBashProfile" && tail -8 "$myBashrc"


###----------------------------------------------------------------------------
### HashiCorp: Packer
###----------------------------------------------------------------------------
printReq "Installing Packer..."
brew install packer packer-completion

printHead "Configuring Packer..."
cat << EOF >> "$myBashrc"
###############################################################################
###                                  Packer                                 ###
###############################################################################
source /usr/local/etc/bash_completion.d/packer
export PACKER_HOME="\$HOME/vms/packer"
# leave PACKER_CONFIG commented till you need it
#export PACKER_CONFIG="\$PACKER_HOME"
export PACKER_CACHE_DIR="\$PACKER_HOME/iso-cache"
export PACKER_BUILD_DIR="\$PACKER_HOME/builds"
export PACKER_LOG='yes'
export PACKER_LOG_PATH='/tmp/packer.log'
export PACKER_NO_COLOR='yes'

EOF

# Source-in and Display changes
printInfo "packer ~/.bashrc changes:"
source "$myBashProfile" && tail -10 "$myBashrc"


###----------------------------------------------------------------------------
### HashiCorp: Vagrant
###----------------------------------------------------------------------------
printReq "Installing Vagrant..."
brew cask install vagrant
brew install vagrant-completion

printHead "Configuring Vagrant..."
cat << EOF >> "$myBashrc"
###############################################################################
###                                 Vagrant                                 ###
###############################################################################
source /usr/local/etc/bash_completion.d/vagrant
#export VAGRANT_LOG=debug
export VAGRANT_HOME="\$HOME/vms/vagrant"
export VAGRANT_BOXES="\$VAGRANT_HOME/boxes"
export VAGRANT_DEFAULT_PROVIDER='virtualbox'

EOF

# Source-in and Display changes
printInfo "vagrant ~/.bashrc changes:"
source "$myBashProfile" && tail -8 "$myBashrc"

# Handle Licensing
printHead "Installing vagrant vmware-fusion license..."
printInfo "Reparing plugins first..."
vagrant plugin repair

printInfo "Installing Fusion plugin..."
vagrant plugin install vagrant-vmware-fusion

printInfo "All plugins:"
vagrant plugin list

printInfo "Installing Vagrant license..."
vagrant plugin license vagrant-vmware-fusion \
    "$HOME/Documents/system/hashicorp/license-vagrant-vmware-fusion.lic"


###----------------------------------------------------------------------------
### Ansible
###----------------------------------------------------------------------------
# Boto is for some Ansible/AWS operations
printReq "Installing Ansible..."
pip install --upgrade ansible boto

printHead "Ansible Version Info:"
ansible --version

printHead "Configuring Vagrant..."
cat << EOF >> "$myBashrc"
###############################################################################
###                                 Ansible                                 ###
###############################################################################
export ANSIBLE_CONFIG="\$HOME/.ansible"

EOF

# Source-in and Display changes
printInfo "ansible ~/.bashrc changes:"
source "$myBashProfile" && tail -5 "$myBashrc"

# Create a home for Ansible
printInfo "Creating the Ansible directory..."
mkdir -p "$HOME/.ansible/roles"
touch "$HOME/.ansible/"{ansible.cfg,hosts}
cp -pv 'sources/ansible/ansible.cfg' ~/.ansible/ansible.cfg
cp -pv 'sources/ansible/hosts'       ~/.ansible/hosts


###----------------------------------------------------------------------------
### Docker
###----------------------------------------------------------------------------
printReq "Installing Docker, et al..."
# Includes completion
brew cask install docker
brew install \
    docker-compose docker-compose-completion \


# Create a vbox VM
#printHead "Creating the Docker VM..."
#docker-machine create --driver virtualbox default

printHead "Configuring Docker..."
cat << EOF >> "$myBashrc"
###############################################################################
###                                 DOCKER                                  ###
###############################################################################
# command-completions for docker, et al.
source /usr/local/etc/bash_completion.d/docker
source /usr/local/etc/bash_completion.d/docker-compose
#source /usr/local/etc/bash_completion.d/docker-machine.bash
#source /usr/local/etc/bash_completion.d/docker-machine-wrapper.bash
#eval "\$(docker-machine env default)"

EOF

# Source-in and Display changes
printInfo "Docker ~/.bashrc changes:"
source "$myBashProfile" && tail -5 "$myBashrc"


###----------------------------------------------------------------------------
### Git is already installed; this is only configuration
###----------------------------------------------------------------------------
printReq "Configuring Git..."
cat << EOF >> "$myBashrc"
###############################################################################
###                                  GIT                                    ###
###############################################################################
source /usr/local/etc/bash_completion.d/git-completion.bash

EOF

# Source-in and Display changes
printInfo "git ~/.bashrc changes:"
source "$myBashProfile" && tail -5 "$myBashrc"


###----------------------------------------------------------------------------
### Post-configuration Steps
###----------------------------------------------------------------------------
printReq "Securing ~/.bashrc ..."
chmod 600 "$myBashrc"


###----------------------------------------------------------------------------
### Configure Vim
###----------------------------------------------------------------------------
### Pull the code
###---
printReq "Pulling the vimSimple repo..."
git clone --recursive -j10 "$vimSimpleGitRepo" "$vimSimpleLocal"

###----------------------------------------------------------------------------
### Modify 1-off configurations on current submodules
###---
printHead "Making 1-off configuration changes..."
### python-mode: disable: 'pymode_rope'
printHead "Disabling pymode_rope..."
printInfo "Check Value before change:"
ropeBool="$(grep "('g:pymode_rope', \w)$" "$pymodConfig")"
ropeBool="${ropeBool:(-2):1}"
if [[ "$ropeBool" -ne '0' ]]; then
    printInfo "Value is $ropeBool, Changing the value to Zero..."
    sed -i "/'g:pymode_rope', 1/ s/1/0/g" "$pymodConfig"
    sed -i "/'g:pymode_rope', 0/i $vimSimpleTag" "$pymodConfig"
else
    printInfo "Value is already Zero"
    grep "('g:pymode_rope', \w)$" "$pymodConfig"
fi

### Print the value for logging
printHead "The pymode_rope plugin is disabled:"
grep "('g:pymode_rope', \w)$" "$pymodConfig"


###---
### json-vim: add: 'autocmd' to the top of the file
###---
sed -i "/$jsonIndREGEX/a $jsonAppendStr" "$jsonIndent"

### json-vim: add a space seperator
sed -i "/$jsonIndREGEX/G" "$jsonIndent"

### json-vim: add: tag as vimSimple configuration
sed -i "/${jsonAppendStr%%\ *}/i $vimSimpleTag" "$jsonIndent"

### Make softlinks to the important files
printHead "Creating softlinks for ~/.vim and ~/.vimrc"
ln -s "$vimSimpleLocal/vimrc" ~/.vimrc
ln -s "$vimSimpleLocal/vim" ~/.vim

ls -dl ~/.vimrc ~/.vim


###----------------------------------------------------------------------------
### Nvim Configurations
###----------------------------------------------------------------------------
printReq  "Neovim post-install configurations:"
printHead "Saving default \$TERM details > ~/config/term/..."
mkdir "$termDir"
infocmp "$TERM" > "$termDir/$TERM.ti"
infocmp "$TERM" | sed 's/kbs=^[hH]/kbs=\\177/' > "$termDir/$TERM-nvim.ti"

printHead "Compiling terminfo for Neovim warning..."
tic "$termDir/$TERM-nvim.ti"

printHead "Linking to existing .vim directory..."
ln -s "$vimSimpleLocal/vim" "$nvimDir"

printHead "Linking to existing .vimrc file..."
ln -s "$vimSimpleLocal/vimrc" "$nvimDir/init.vim"


###----------------------------------------------------------------------------
### Configure The macOS
###----------------------------------------------------------------------------
### Configure the System
###---
printReq "Configuring the System:"

###---
###  Set the hostname(s)
###---
printHead "Configuring the hostname(s)..."
### Configure the network hostname
printInfo "Configuring network hostname..."
sudo scutil --set ComputerName "$myHostName"

### Configure the Terminal hostname
printInfo "Configuring Terminal hostname..."
sudo scutil --set HostName "${myHostName%%.*}"

### Configure the AirDrop hostname
printInfo "Configuring AirDrop hostname..."
sudo scutil --set LocalHostName "${myHostName%%.*}"

###---
### Storage
###---
printHead "Configuring Storage:"
printInfo "Save to disk by default (not to iCloud)..."
# defaults read NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

###---
### Disable smart quotes and dashes system-wide
###---
printHead "Disabling smart quotes and dashes system-wide:"
### Disable smart quotes
printInfo "Disabling smart quotes..."
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
### Disable smart dashes
printInfo "Disabling smart dashes..."
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false


###----------------------------------------------------------------------------
### The Finder
###----------------------------------------------------------------------------
### Display all folders in List View
###---
printHead "Setting Finder Preferences:"
printInfo "Display all windows in List View..."
defaults write com.apple.finder FXPreferredViewStyle Nlsv

###---
### Enable sidebar directories
###---
# Add $HOME
printHead "Configuring Finder Sidebar..."
printInfo "Add \$HOME to sidebar..."
sfltool add-item com.apple.LSSharedFileList.FavoriteItems "file:///$HOME"
# Add Pictures
printInfo "Add Pictures to sidebar..."
sfltool add-item com.apple.LSSharedFileList.FavoriteItems "file:///$HOME/Pictures"
# Add Music
printInfo "Add Music to sidebar..."
sfltool add-item com.apple.LSSharedFileList.FavoriteItems "file:///$HOME/Music"
# Add Movies
printInfo "Add Movies to sidebar..."
sfltool add-item com.apple.LSSharedFileList.FavoriteItems "file:///$HOME/Movies"

###---
### New window displays home
###---
printInfo "Display the home directory by default..."
defaults write com.apple.finder NewWindowTarget -string "PfLo"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"

###---
### Show status bar in Finder
###---
printInfo "Display status bar in Finder..."
defaults write com.apple.finder ShowStatusBar -bool true

###---
### Search the current folder by default
###---
printInfo "Search the current folder by default..."
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

###---
### Display all file extensions in Finder
###---
printInfo "Display all extensions by default..."
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

###---
### Screenshot behavior
###---
printInfo "Save screenshots to a specified location..."
if [[ ! -d "$dirScreenshot" ]]; then
    mkdir -p "$dirScreenshot"
    defaults write com.apple.screencapture location "$dirScreenshot"
fi

### Create a softlink on the Desktop
if [[ ! -h "$linkScreens" ]]; then
    ln -s "$dirScreenshot" "$linkScreens"
fi

### Set screenshots without window shadows
printInfo "Save screenshots without window shadows..."
defaults write com.apple.screencapture disable-shadow -bool true

###---
### Show battery percentage
###---
printInfo "Show battery percentage..."
# defaults read com.apple.menuextra.battery ShowPercent
defaults write com.apple.menuextra.battery ShowPercent -string 'YES'

###---
### Display Configuration
###---
printInfo "Don't show mirroring options in the menu bar..."
defaults write com.apple.airplay showInMenuBarIfPresent -bool false

###---
### Display Date/Time formatted: 'EEE MMM d  h:mm a'
###---
printInfo "Display Day HH:MM AM format..."
defaults write com.apple.menuextra.clock 'DateFormat' -string 'EEE MMM d  h:mm a'

###---
### Network Shares
###---
printInfo "Do NOT create .DS_Store files on network volumes..."
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

###---
### Dialog Box behavior
###---

### The Save Dialog Box
printInfo "Expand Save panel by default..."
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

### The Print Dialog Box
printInfo "Expand Print panel by default..."
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true


###----------------------------------------------------------------------------
### The Dock
###----------------------------------------------------------------------------
printHead "Setting Dock Preferences:"
printInfo "Display The Dock at 46px..."
# Set default Tile Size to 42px
defaults write com.apple.dock tilesize 42

### Auto-Hide the Dock
printInfo "Auto-hide The Dock..."
defaults write com.apple.dock autohide -bool true

### Optionally: adjust timing with these settings
#defaults write com.apple.dock autohide-delay -float 0
#defaults write com.apple.dock autohide-time-modifier -float 0

###----------------------------------------------------------------------------
### Configure Basic OS Security
###----------------------------------------------------------------------------
printHead "Configuring Basic OS Security:"

###---
### Disable Guest User at the Login Screen
###---
printInfo "Disable Guest User at the Login Screen..."
sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool NO
# sudo defaults read /Library/Preferences/com.apple.loginwindow GuestEnabled
# OUTPUT: 0

###---
### Apple File Protocol
###---
printInfo "Disable AFP Guest Access..."
defaults write com.apple.AppleFileServer.plist AllowGuestAccess -int 0

###----------------------------------------------------------------------------
### Configure Application Behavior
###----------------------------------------------------------------------------
printHead "Configuring Application Preferences:"

###---
### Stop Photos from opening automatically when plugging in iPhone [TEST]
###---
printInfo "Stop Photos from opening automatically..."
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

###---
### TextEdit
###---
printInfo "TextEdit Preferences: before:"
defaults read com.apple.TextEdit

# Set Author Name
printInfo "Setting autor name..."
defaults write com.apple.TextEdit author "$myFullName"
# Use plain text not RichText
printInfo "Use plain text by default..."
defaults write com.apple.TextEdit RichText -int 0
# Set Font
printInfo "We'll use Courier as the font..."
defaults write com.apple.TextEdit NSFixedPitchFont 'Courier'
# Set Font Size
printInfo "Courier is set to 14pt..."
defaults write com.apple.TextEdit NSFixedPitchFontSize -int 14
# Default Window Size
printInfo "New Windows will open at H:45 x W:100..."
defaults write com.apple.TextEdit WidthInChars -int 100
defaults write com.apple.TextEdit HeightInChars -int 45
# Disable SmartDashes and SmartQuotes
printInfo "Disabling SmartDashes and SmartQuotes..."
defaults write com.apple.TextEdit SmartDashes -int 0
defaults write com.apple.TextEdit SmartQuotes -int 0

printInfo "TextEdit Preferences: after:"
defaults read com.apple.TextEdit


###----------------------------------------------------------------------------
### Remove the Github Remote Host Key
###----------------------------------------------------------------------------
#printInfo "Removing the $hostRemote public key from our known_hosts file..."
#ssh-keygen -f "$knownHosts" -R "$hostRemote"


###----------------------------------------------------------------------------
### Save installed package and library details AFTER the install
###----------------------------------------------------------------------------
printReq "Saving some pre-install app/lib details..."
tools/admin-app-details.sh post

### Create a link to the log file
ln -s ~/.config/admin/logs/mac-ops-config.out config-output.log


###----------------------------------------------------------------------------
### Restore Personal Data
###----------------------------------------------------------------------------
if [[ ! -d "$myBackups" ]]; then
    printInfo "There are no Documents to restore."
else
    printInfo "Restoring files..."
    tools/restore-my-stuff.sh 2> /tmp/rsycn-errors.out
fi


###----------------------------------------------------------------------------
### Some light housework
###----------------------------------------------------------------------------
printReq "Cleaning up a bit..."
sudo find "$HOME" -type f -name 'AT.postflight*' -exec mv {} "$adminLogs" \;

printInfo "Refreshing the Fonts directory..."
fc-cache -frv "$HOME/Library/Fonts"

printInfo "Restoring the /etc/hosts file..."
sudo cp "$sysBackups/etc/hosts" /etc/hosts
sudo chown root:wheel /etc/hosts

printInfo "Ensure correct ownership of ~/.viminfo file..."
if [[ -f ~/.viminfo ]]; then
    sudo chown "$USER:staff" ~/.viminfo
fi

###----------------------------------------------------------------------------
### Announcements
###----------------------------------------------------------------------------
printf '\n\n%s\n' """
###############################################################################
#                         POST-INSTALL INSTRUCTIONS                           #
###############################################################################
"""
printf '\n%s\n' """
    1) The AWS client profile:
            Use this guide to setup your AWS cli profile:
            https://github.com/todd-dsm/mac-ops/wiki/Install-awscli
            * If you already had this setup then these settings have already
            been restored to ~/.aws/

    2) Sidebar elements have been added but I still haven't figured out how to
       remove stuff; customize this to your tastes:
       Finder > Preferences: Sidebar.

    3) You still have to open System Preferences and verify your settings. I
       can't see any other way to set these preference than the manual way.

    4) Data Restoration:
       a) Check for any data restore errors by:
          less /tmp/rsycn-errors.out
       b) Check for any data that is not owned by you:
          less /tmp/find-out.log

    That's basically it. Now get back to work :-)


"""


###----------------------------------------------------------------------------
### Quick and Dirty duration
###----------------------------------------------------------------------------
# we can't read /etc/paths until the next login; set date location
declare gnuDate='/usr/local/opt/coreutils/libexec/gnubin/date'
timePost=$("$gnuDate" +'%T')
### Convert time to a duration
startTime=$("$gnuDate" -u -d "$timePre" +"%s")
endTime=$("$gnuDate" -u -d "$timePost" +"%s")
procDur="$("$gnuDate" -u -d "0 $endTime sec - $startTime sec" +"%H:%M:%S")"
printf '%s\n' """
    Process start at: $timePre
    Process end   at: $timePost
    Process duration: $procDur
"""


###----------------------------------------------------------------------------
### Fin~
###----------------------------------------------------------------------------
printInfo
