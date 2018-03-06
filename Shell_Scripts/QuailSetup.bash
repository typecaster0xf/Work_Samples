#!/bin/bash
###########################################################
# Sets up a BeagleBone Black from its factory image to make
# it the platform for the Valtiroty lights project.
###########################################################

set -o nounset
declare -r SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
declare -r TIMESTAMP="$(date +%Y%m%d:%H%M:%Z)"

declare -r CONFIG_FILE_CACHE="$SCRIPT_DIR/originalConfigFiles"

###########################################################
#  Functions with User Interaction  #
#####################################

function changePasscode
{
	log green 'Changing passcode for debian:'
	
	declare SUCCESS_FLAG=1
	while test $SUCCESS_FLAG -gt 0
	do
		passwd debian
		SUCCESS_FLAG=$?
	done
	
	log green 'Deleting root password.'
	passwd -d root
}

function promptToSetupConnman
{
	while true
	do
		read -p 'Do you wish to set-up WiFi now? (y|n):' USER_IN
		
		case "$USER_IN" in
		y|Y)
			return 0
			;;
		n|N)
			return 1
			;;
		*)
			echo 'Invalid input.'
		esac
	done
}

# TODO: Having this function copy in configuration settings that
# get the board onto my WiFi network is an okay approach for
# now to speed development a little; but I'm going to want to
# change this so that the user is prompted to setup the WiFi
# and enter all the credentials manually.
function setupConnman
{
	declare -r SETUPS_FOLDER="$1"
	
	log green 'Copying connman config files into place.'
	
	cp -r "$SETUPS_FOLDER"/connman/* /var/lib/connman/
	
	function setPermissions
	{
		declare -r DIR="$1"
		
		for ITEM in $(ls "$DIR")
		do
			chown root:root "$DIR"/$ITEM
			if test -d "$DIR"/$ITEM
			then
				chmod 700 "$DIR"/$ITEM
				setPermissions "$DIR"/$ITEM
			else
				chmod 600 "$DIR"/$ITEM
			fi
		done
	}
	setPermissions /var/lib/connman
	
	log green 'Restarting connman service'
	log yellow 'WiFi connection might not succeed until after reboot.'
	service connman restart
}

function setTimezone
{
	dpkg-reconfigure tzdata
}

###########################################################
#  Repository Functions  #
##########################

declare -r SETUP_REPO_INSTALL_LOCATION='/usr/local'

function installSystemPackagesAndUpgrades
{
	declare -r SETUPS_FOLDER="$1"
	
	installSetupRepository "$SETUPS_FOLDER"
	installAptitude
	installPackageUpgrades
	installAdditionalPackages "$SETUPS_FOLDER"
	removeSetupRepository "$SETUPS_FOLDER"
}

function installSetupRepository
{
	declare -r SETUPS_FOLDER="$1"
	
	log green 'Installing setup repository.'
	
	tar xmf $SETUPS_FOLDER/setupRepository/setupRepository.tar \
			-C $SETUP_REPO_INSTALL_LOCATION/
	
	cacheOriginalConfigFile '/etc/apt/sources.list'
	cp $SETUPS_FOLDER/setupRepository/sources.list \
			/etc/apt/sources.list
}

function removeSetupRepository
{
	declare -r SETUPS_FOLDER="$1"
	
	log green 'Removing setup repository.'
	
	rm -r $SETUP_REPO_INSTALL_LOCATION/setupRepository
	
	rm /etc/apt/sources.list
	cp "$CONFIG_FILE_CACHE/sources.list" \
			/etc/apt/sources.list
}

###########################################################
#  Package Update Functions  #
##############################

function installAptitude
{
	log green 'Installing aptitude.'
	apt-get update
	apt-get install -y --allow-unauthenticated aptitude
	aptitude update
}

function installPackageUpgrades
{
	log green 'Installing package upgrades.'
	aptitude upgrade -y --allow-untrusted
}

function installAdditionalPackages
{
	declare -r SETUPS_FOLDER="$1"
	
	function listAdditionalPackagesToInstall
	{
		declare -r ADDITIONAL_PACKAGES_FILE="$SETUPS_FOLDER/requiredPackages.txt"
		cat "$ADDITIONAL_PACKAGES_FILE" \
				| tr '\n' ' '
	}
	
	log green 'Installing additional packages.'
	aptitude install -y --allow-untrusted $(listAdditionalPackagesToInstall)
}

###########################################################
#  System Setting Modifications  #
##################################

function disableWiFiAccessPoint
{
	log green 'Shutting down WiFi access point (SoftAp0).'
	ifconfig SoftAp0 down
	
	log green 'Disabling WiFi access point on boot.'
	
	cacheOriginalConfigFile '/usr/bin/bb-wl18xx-tether'
	sed -i 's/\t\tcreate_softap0_interface/\t\t#create_softap0_interface/g' /usr/bin/bb-wl18xx-tether
	sed -i 's/\t\tbringup_softap0_interface/\t\t#bringup_softap0_interface/g' /usr/bin/bb-wl18xx-tether
	sed -i 's/\t\tstart_hostapd/\t\t#start_hostapd/g' /usr/bin/bb-wl18xx-tether
	
	/lib/systemd/systemd-sysv-install disable hostapd
	
	# Another option is to edit /etc/default/bb-wl18xx
	# and change the line TETHER_ENABLED=yes to
	# TETHER_ENABLED=no.  Howver, this method will disable
	# both the WiFi access point and USB tethering.
}

function setFishAsDefaultShell
{
	log green 'Setting fish as the default shell.'
	cacheOriginalConfigFile '/etc/passwd'
	sed -i s:/bin/bash:/usr/bin/fish:g /etc/passwd
}

function changeHostnameTo
{
	declare -r NEW_HOSTNAME="$1"
	
	log green "Changing hostname to $NEW_HOSTNAME."
	
	cp /etc/hostname{,.bak}
	echo "$NEW_HOSTNAME" >/etc/hostname
	
	cacheOriginalConfigFile '/etc/hosts'
	sed -i s:beaglebone:$NEW_HOSTNAME:g /etc/hosts
}

function changeSSHPort
{
	log green 'Changing SSH port.'
	cacheOriginalConfigFile '/etc/ssh/sshd_config'
	sed -i 's:#Port 22:Port 22225:g' \
			/etc/ssh/sshd_config
}

function changeSudoToNoPasswd
{
	log green 'Setting sudo to not ask for debian passcode.'
	cacheOriginalConfigFile '/etc/sudoers.d/admin'
	sed -i s/ALL\$/NOPASSWD:ALL/g \
			/etc/sudoers.d/admin
}

function colorizeBashPrompts
{
	log green 'Setting Bash prompt colors.'
	
	echo 'PS1="\[\e]0;\u@\h \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\] \[\033[01;34m\]\w \$\[\033[00m\] "' >>/home/debian/.bashrc
	
	echo 'PS1="\[\e]0;\u@\h \w\a\]${debian_chroot:+($debian_chroot)}\[\033[01;31m\]\h\[\033[01;34m\] \W \$\[\033[00m\] "' >>/root/.bashrc
}

function disableNodeRed
{
	log green 'Disabling Node-Red'
	systemctl disable node-red
	systemctl disable node-red.socket
}

function disableCloud9
{
	log green 'Disabling Cloud9 IDE'
	systemctl disable cloud9
	systemctl disable cloud9.socket
}

function disableApache2
{
	log green 'Disabling Apache2'
	#/lib/systemd/systemd-sysv-install disable apache2
	#/lib/systemd/systemd-sysv-install disable apache-htcacheclean
	systemctl disable apache2
	systemctl disable apache-htcacheclean
}

function disableBonescript
{
	log green 'Disabling bonescript'
	systemctl disable bonescript
	systemctl disable bonescript.socket
	systemctl disable bonescript-autorun
}

function disableBluetooth
{
	log green 'Disabling bluetooth'
	systemctl disable bluetooth
}

function disableRoboticscape
{
	log green 'Disabling roboticscape'
	systemctl disable roboticscape
}

function configureFirewall
{
	log green 'Configuring Firewall'
	ufw allow 67/udp
	ufw allow http
	ufw allow 22225/tcp
	log yellow 'Activating firewall may end current SSH sessions.  Should this occur, the next step is to reboot the BeagleBone.'
	expect <<EOS
spawn ufw enable
expect "Proceed with operation (y|n)? "
send "y\r"
expect eof
EOS
	
}

###########################################################
#  Functions Requiring Files #
#  from the Setups Folder    #
##############################

function disableHeartbeat
{
	declare -r SETUPS_FOLDER="$1"
	
	log green 'Disabling heartbeat on boot.'
	
	cp "$SETUPS_FOLDER"/heartbeat/disable-heartbeat \
			/etc/init.d/
	chmod 755 /etc/init.d/disable-heartbeat
	chown root:root /etc/init.d/disable-heartbeat
	update-rc.d disable-heartbeat defaults
	/etc/init.d/disable-heartbeat
}

function setupSSHClient
{
	declare -r SETUPS_FOLDER="$1"
	
	log green 'Copying debian SSH client files into place.'
	
	if ! test -d /home/debian/.ssh
	then
		mkdir /home/debian/.ssh
		chmod 700 /home/debian/.ssh
		chown debian:debian /home/debian/.ssh
	fi
	
	cp "$SETUPS_FOLDER"/ssh/* /home/debian/.ssh/
	
	chmod 644 /home/debian/.ssh/*
	chown debian:debian /home/debian/.ssh/*
	
	chmod 600 /home/debian/.ssh/id_rsa
}

function setupTinc
{
	declare -r SETUPS_FOLDER="$1"
	
	log green 'Copying Tinc files into place.'
	
	cp -r "$SETUPS_FOLDER"/tinc/icenet /etc/tinc/
	chown -R root:root /etc/tinc/icenet
	
	chmod 755 /etc/tinc/icenet
	chmod 600 /etc/tinc/icenet/rsa_key.priv
	chmod 644 /etc/tinc/icenet/tinc.conf
	chmod 755 /etc/tinc/icenet/tinc-up
	chmod 755 /etc/tinc/icenet/hosts
	chmod 600 /etc/tinc/icenet/hosts/*
	
	echo 'icenet' >>/etc/tinc/nets.boot
	
	log green ' > Performing systemctl fix for Tinc.'
	cacheOriginalConfigFile '/lib/systemd/system/tinc.service'
	sed -i s/'^ExecStart=\/bin\/true$'/'ExecStart=\/etc\/init.d\/tinc\ start'/ \
			/lib/systemd/system/tinc.service
	sed -i s/'^ExecReload=\/bin\/true$'/'ExecReload=\/etc\/init.d\/tinc\ reload'/ \
			/lib/systemd/system/tinc.service
}

function setupMercurial
{
	declare -r SETUPS_FOLDER="$1"
	
	log green 'Copying Mercurial config files into place.'
	
	cp "$SETUPS_FOLDER"/mercurial/hgrc \
			/home/debian/.hgrc
	chmod 644 /home/debian/.hgrc
	chown debian:debian /home/debian/.hgrc
}

###########################################################
#  Library Compillation and Install  #
######################################

function installLibraries
{
	declare -r SETUPS_FOLDER="$1"
	
	log green 'Generating temporary swap file.'
	$SETUPS_FOLDER/swap/createSwap.fish
	
	buildAndRunVibeUnitTestBuild "$SETUPS_FOLDER/libraries/vibe"
	makeAndInstallVibe "$SETUPS_FOLDER/libraries/vibe"
	
	log green 'Deleting temporary swap file.'
	$SETUPS_FOLDER/swap/removeSwap.fish
}

function buildAndRunVibeUnitTestBuild
{
	declare -r SOURCE_DIRECTORY="$1"
	
	log green 'Compilling vibe.d unit tests.'
	
	pushd "$SOURCE_DIRECTORY"
	if ! make vibeUnittest.run
	then
		log red 'Compilation failure.'
		exit 1
	elif ! ./vibeUnittest.run
	then
		log red 'Vibe.d unit test failure.'
		exit 1
	fi
	popd
}

function makeAndInstallVibe
{
	declare -r SOURCE_DIRECTORY="$1"
	
	log green 'Compilling and installing Vibe.d'
	
	pushd "$SOURCE_DIRECTORY"
	if ! make install
	then
		log red 'Compile and install of Vibe.d failed.'
		exit 1
	fi
	popd
}

###########################################################
#  Utility  #
#############

function ensureRunningAsRoot
{
	declare -r SCRIPT_INVOCATION="$*"
	
	if test $(whoami) != 'root'
	then
		log red 'Root privileges required.'
		exec sudo $SCRIPT_INVOCATION
	fi
}

function log
{
	declare -r COLOR_SETTING="$1"
	shift
	
	declare -r COLOR_GREEN='\e[1;32m'
	declare -r COLOR_YELLOW='\e[1;33m'
	declare -r COLOR_RED='\e[1;31m'
	declare -r COLOR_NONE='\e[0m'
	
	case "$COLOR_SETTING" in
		green)
			declare OUTPUT_COLOR="$COLOR_GREEN"
			;;
		yellow)
			declare OUTPUT_COLOR="$COLOR_YELLOW"
			;;
		red)
			declare OUTPUT_COLOR="$COLOR_RED"
			;;
		*)
			log red "Unknown color setting: $COLOR_SETTING"
	esac
	
	echo -e "$OUTPUT_COLOR$*$COLOR_NONE" \
			| tee -a "$SCRIPT_DIR/setup-$TIMESTAMP.log"
}

function cacheOriginalConfigFile
{
	declare -r FILE="$1"
	
	if ! test -d "$CONFIG_FILE_CACHE"
	then
		mkdir "$CONFIG_FILE_CACHE"
		chown root:root "$CONFIG_FILE_CACHE"
		chmod 700 "$CONFIG_FILE_CACHE"
	fi
	
	cp "$FILE" "$CONFIG_FILE_CACHE"
}

###########################################################
#  Main  #
##########

declare -r SETUP_FILES_DIR="$SCRIPT_DIR"

# Functions requireing user interaction:
ensureRunningAsRoot "$0" "$@"
changePasscode
if promptToSetupConnman
then
	#Will need user input after later development.
	setupConnman "$SETUP_FILES_DIR"
fi
setTimezone

installSystemPackagesAndUpgrades "$SETUP_FILES_DIR"

# System modifications:
disableWiFiAccessPoint
setFishAsDefaultShell
changeHostnameTo 'Quail'
changeSSHPort
changeSudoToNoPasswd
colorizeBashPrompts
disableNodeRed
disableCloud9
disableApache2
disableBonescript
disableBluetooth
disableRoboticscape

# System modifications that use files from the setup
# tarball:
disableHeartbeat "$SETUP_FILES_DIR"
setupSSHClient "$SETUP_FILES_DIR"
setupTinc "$SETUP_FILES_DIR"
setupMercurial "$SETUP_FILES_DIR"
installLibraries "$SETUP_FILES_DIR"

configureFirewall

log green "\n\nSetup completed."
log yellow "Rebooting."
reboot
