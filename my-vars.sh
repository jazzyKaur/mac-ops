#!/usr/bin/env bash
# shellcheck disable=SC2034
# -----------------------------------------------------------------------------
# User-specific variables required before running the automation.
# WARNING: YOU MUST SET THESE VARIABLES FIRST. DO NOT RUN bootstrap.sh WITHOUT
#          HAVING CONFIGURED THESE PARAMETERS.
# -----------------------------------------------------------------------------

# Are we testing or are we really doing this?
export theENV='TEST'

# What's your Full Name?
export myFullName='Todd E Thomas'

# What would you like to call your computer?
export myMBPName='tbook'

# Do you have an internal domain?
#   If there isn't one just delete the value between the quotes.
export myDomain='ptest'

# What's the TLD for the internal domain?
#   If there isn't one just delete the value between the quotes.
export myTLD='us'

# Altogether
export myDomaiName="$myDomain.$myTLD"

# Set the Domain Name and TLD to .local if there is nothing else
if [[ -z "$myDomaiName" ]]; then
    export myDomaiName='.local'
fi

# Call it 'macos' if we're testing - whatever you want if we're live.
if [[ "$theENV" == 'TEST' ]]; then
    export myHostName="macos.$myDomaiName"
else
    export myHostName="$myMBPName.$myDomaiName"
fi

# Define a path to your backup device. It's just a path. It can point to an NFS
# share, a USB drive, whatever.
export myBackupDev='/Volumes/storage'

# Define a path to your latest backups
if [[ "$theENV" == 'TEST' ]]; then
    export myBackupDir='test'
else
    export myBackupDir='pre_sierra'
fi

# Define the last "$USER" backed up. 2 options:
# 1) If theENV=TEST: $USER will always be 'vagrant'.
# 2) If NOT TEST then set your user name to whatever you like.
#    This will be used during rsync operations to restore your data.
if [[ "$theENV" == 'TEST' ]]; then
    export lastUser="$USER"
else
    export lastUser="thomas"    # replace with your current user name
fi

# Define Restore SRC (source of the backups)
export  myBackups="$myBackupDev/$myBackupDir/$lastUser/current"
export sysBackups="$myBackupDev/$myBackupDir/system"

# -----------------------------------------------------------------------------
# Define some personal truths *if they are different*. This stuff doesn't
# change much though.
# -----------------------------------------------------------------------------

# Where do you keep your code/projects?
export myCode="$HOME/code"

# Where do you store your virtual machines?
export myVMs="$HOME/vms"

# Define where the ssh keys go
export mySSHDir="$HOME/.ssh"

# Desktop
export myDesktop="$HOME/Desktop"

# Documents
export myDocs="$HOME/Documents"

# Movies
export myMovies="$HOME/Movies"

# Music
export myMusic="$HOME/Music"

# Pictures
export myPics="$HOME/Pictures"

# Downloads
export myDownloads="$HOME/Downloads"

# -----------------------------------------------------------------------------
# This stuff never changes
# -----------------------------------------------------------------------------
# macOS Build
declare myPath=''
declare myMans=''
declare configDir="$HOME/.config"
declare adminDir="$configDir/admin"
declare adminLogs="$adminDir/logs"
declare backupDir="$adminDir/backup"
declare termDir="$configDir/term"
declare nvimDir="$configDir/nvim"
declare sysShells='/etc/shells'
declare hostRemote='github.com'
declare termStuff="$myDownloads"
declare solarizedGitRepo='git@github.com:altercation/solarized.git'
declare myBashProfile="$HOME/.bash_profile"
declare myBashrc="$HOME/.bashrc"
declare myConfigs="$HOME/.config"
declare sysPaths='/etc/paths'
declare sysManPaths='/etc/manpaths'
# Configure Vim
declare knownHosts="$HOME/.ssh/known_hosts"
declare vimSimpleTag='" vimSimple configuration'
declare vimSimpleLocal="$myCode/vimsimple"
declare vimSimpleGitRepo='https://github.com/todd-dsm/vimSimple.git'
declare pymodConfig="$vimSimpleLocal/vim/bundle/python-mode/plugin/pymode.vim"
declare jsonIndent="$vimSimpleLocal/vim/bundle/vim-json/indent/json.vim"
declare jsonIndREGEX='" =================$'
declare jsonAppendStr='autocmd filetype json set et ts=2 sw=2 sts=2'
# Configure macOS
declare dirScreenshot="$myPics/screens"
declare linkScreens="$myDesktop/screens"

# Test the last variable
if [[ -z "$linkScreens" ]]; then
    printf '%s\n' "Crap! something is jacked."
    exit 1
else
    printf '\n%s\n' "Initial configs look good. Let's do this!"
fi
