#!/bin/bash

###################################################
# Make sure user didn't force script to run in sh #
###################################################

ps ax | grep $$ | grep bash > /dev/null ||
{
	clear
	echo "You are forcing the script to run in sh when it was written for bash."
	echo "Please run it in bash instead, and NEVER run any script the way you just did."
	exit 1
}

####################
# Global Variables #
####################

#Path to the file that contains all the functions for this script
RAM_LIB='./ram_lib'

#Path to the rupdate script
RUPDATE_FILE='extras/rupdate'

#Path to the rchroot script
RCHROOT_FILE='extras/rchroot'

#True if home is already on another partition. False otherwise
HOME_ALREADY_MOUNTED=$(df /home | tail -1 | grep -q '/home' && echo true || echo false)

#True if /home should just be copied over to $DEST/home
#False otherwise
#Note: Do NOT remove the default value
COPY_HOME=true

#The new location of /home
#Note: Here, we check the old location of /home, but later we can change it
#to reflect the new location
HOME_DEV=$(readlink -f `df /home | tail -1 | grep '/home' | cut -d ' ' -f 1` 2>/dev/null)

#The device of the root partition
ROOT_DEV=$(readlink -f `df / | grep -o '/dev/[^ ]*'`)

#The device of the boot partition
BOOT_DEV=$(readlink -f `df /boot | grep -o '/dev/[^ ]*'`)

#The UUID of the root partition
ROOT_UUID=$(sudo blkid -o value -s UUID $ROOT_DEV)

#The UUID of the boot partition
BOOT_UUID=$(sudo blkid -o value -s UUID $BOOT_DEV)

#The folder where the RAM Session will be stored
DEST=/var/squashfs/

#Only applies when the Original OS starts out having /home on the same partition as /
#and the user chooses to use a separate partition for /home on the RAM Session
#true if the Original OS's /etc/fstab should be modified to also use
#	the partition that the RAM Session will be using as /home
#false if it should not
SHARE_HOME=true

############################
# Only run if user is root #
############################

uid=$(/usr/bin/id -u) && [ "$uid" = "0" ] || 
{
	clear
	echo "You must be root to run $0."
	echo "Try again with the command 'sudo $0'"
	exit 1
} 

##########################################################
# Source the file with all the functions for this script #
##########################################################

if [[ -e $RAM_LIB ]]
then
	. $RAM_LIB
else
	clear
	echo "The library that comes with RAM Booster ($RAM_LIB) was not found!"
	exit 1
fi

############################
# Check for rupdate script #
############################

if [[ ! -e $RUPDATE_FILE ]]
then
	clear
	echo "\"$RUPDATE_FILE\" was not found!"
	exit 1
fi

############################
# Check for rchroot script #
############################

if [[ ! -e $RCHROOT_FILE ]]
then
	clear
	echo "\"$RCHROOT_FILE\" not found!"
	exit 1
fi

####################################
# Check args passed to this script #
####################################

case "$1" in
	--uninstall)
		#If $1 is --uninstall, force uninstall and exit
		clear
		Uninstall_Prompt
		exit 0
		;;
	"")
		#If no args, no problem
		;;
	*)
		#If $1 is anything else, other than "--uninstall" or blank, it's invalid
		clear
		echo "\"$1\" is not a valid argument"
		exit 1
		;;
esac

############################
# Check if OS is supported #
############################

OS_Check=`cat /etc/issue | grep -o '[0-9][0-9]*\.[0-9][0-9]*'`

if [[ "$OS_Check" != "14.10" ]]
then
	clear
	echo "This script was written to work with Ubuntu 14.10."
	echo "You are running `cat /etc/issue | egrep -o '[a-Z]+[ ][0-9]+\.[0-9]+\.*[0-9]*'`."
	ECHO "This means the script has NOT been tested for your OS. Run this at your own risk."
	echo 
	echo "Press enter to continue or Ctrl+C to exit"
	read key
fi

########################################################
# Check if RAM_booster has already run on this machine #
########################################################

if [ -e /Original_OS ]
then
	clear
	ECHO "$0 has already run on this computer. It will not run again until you uninstall it."
	echo
	read -p "Would you like to uninstall the RAM Session? [y/N]: " answer

	#Convert answer to lowercase
	answer=$(toLower $answer)

	case $answer in
		y|yes)
			clear
			Uninstall_Prompt
			exit 0
			;;  
		*)  
			exit 0
			;;  
	esac
fi

##############################################################################
# Check if the user is trying to run this script from within the RAM Session #
##############################################################################

if [ -e /RAM_Session ]
then
	clear
	echo "This script cannot be run from inside the RAM Session."
	exit 0
fi

#################################################
# Find out what the user wants to do with /home # 
#################################################

clear
ECHO "This script will create a copy of your Ubuntu OS in ${DEST} and then use that copy to create a squashfs image of it located at /live. After this separation, your old OS and your new OS (the RAM Session) will be two completely separate entities. Updates of one OS will not affect the update of the other (unless done so using the update script - in which case two separate updates take place one after the other), and the setup of packages on one will not transfer to the other. Depending on what you choose however, your /home may be shared between the two systems."

echo

ECHO "/home is the place where your desktop, documents, music, pictures, and program settings are stored. Would you like /home to be stored on a separate partition so that it can be writable? If you choose yes, you may need to provide a device name of a partition as this script will not attempt to partition your drives for you. If you choose no, /home will be copied to the RAM session as is, and will become permanent. This means everytime you reboot, it will revert to the way it is right now. Moving it to a separate partition will also make /home shared between the two systems."

#If /home is already on a separate partition, let the user know
if $HOME_ALREADY_MOUNTED
then
	echo
	ECHO "Your /home is currently located on $HOME_DEV. If you choose to have it separate, the RAM Session will mount the $HOME_DEV device as /home as well."
fi

echo
read -p "What would you like to do?: [(S)eparate/(c)opy as is]: " answer

#Convert answer to lowercase
answer=$(toLower $answer)

case $answer in
	s|separate)
		COPY_HOME=false

		if $HOME_ALREADY_MOUNTED
		then
			#/home is already on a separate partition, so we know exactly what to use
			echo
			ECHO "You chose to use $HOME_DEV as your /home for the RAM Session"
			sleep 4
		else
			#Ask user what he wants to use as /home
			#Note: This function sets the global variable $HOME_DEV
			Ask_User_About_Home
		fi
		;;  
	c|copy)  
		COPY_HOME=true

		echo
		ECHO "You chose to copy /home as is. I hope you read carefully and know what that means..."
		sleep 4
		;;  
	*)
		echo
		echo "Invalid answer"
		echo "Exiting..."
		exit 1
		;;
esac

####################################################################################
# If the Original OS's /home was on the same partition as /, and the user chose    #
# to have the RAM Session's /home on a separate partition, ask if we should change #
# the Original OS's /etc/fstab to also mount that partition as /home               #
####################################################################################

if ! $COPY_HOME
then
	if ! $HOME_ALREADY_MOUNTED
	then
		#Ask user if they want to share /home
		clear
		ECHO "Would you like to have your Original OS use $HOME_DEV as its /home as well?"
		echo
		ECHO "If you choose yes, your Original OS's /home and your RAM Session's /home will be shared"
		echo
		ECHO "If you choose no, your Original OS's /home and your RAM Session's /home will be different"
		echo
		read -p "Your choice [Y/n]: " answer

		#Convert answer to lowercase
		answer=$(toLower $answer)

		case $answer in
			n|no)  
				SHARE_HOME=false
				echo
				ECHO "Your Original OS's /home and your RAM Session's /home will remain separate."
				sleep 4
				;;
			*)
				SHARE_HOME=true
				echo
				ECHO "Your /etc/fstab will be modified to mount $HOME_DEV as your /home at boot"
				sleep 4
				;;
		esac
	fi
fi

#################################################################
# If the user hits Ctrl+C at any point, have the script cleanup #
#################################################################

trap CtrlC SIGINT

###################################
# Install some essential packages #
###################################

clear
echo "Installing essential packages:"

echo "Running apt-get update..."
sudo apt-get update 2>/dev/null >/dev/null

echo "Installing squashfs-tools..."
sudo apt-get -y --force-yes install squashfs-tools 2>/dev/null >/dev/null ||
{
	ECHO "squashfs-tools failed to install. You'll have to download and install it manually..."
	exit 1
}

echo "Installing live-boot-initramfs-tools..."
sudo apt-get -y --force-yes install live-boot-initramfs-tools 2>/dev/null >/dev/null ||
{
	ECHO "live-boot-initramfs-tools failed to install. You'll have to download and install it manually..."
	exit 1
}

sudo apt-get -y --force-yes install live-boot 2>/dev/null >/dev/null ||
{
	ECHO "live-boot failed to install. You'll have to download and install it manually..."
	exit 1
}

echo "Packages installed successfully"

#######################################################
# Change a few things to make boot process look nicer #
#######################################################

echo
echo "Making boot process look nicer..."

#Hide expr error on boot
sudo sed -i 's/\(size=$( expr $(ls -la ${MODULETORAMFILE} | awk '\''{print $5}'\'') \/ 1024 + 5000\)/\1 2>\/dev\/null/' /lib/live/boot/9990-toram-todisk.sh 2>/dev/null

#Hide 'sh:bad number' error on boot
sudo sed -i 's#\(if \[ "\${freespace}" -lt "\${size}" ]\)#\1 2>/dev/null#' /lib/live/boot/9990-toram-todisk.sh 2>/dev/null

#Suppress udevadm output
sudo sed -i 's#if ${PATH_ID} "${sysfs_path}"#if ${PATH_ID} "${sysfs_path}" 2>/dev/null#g' /lib/live/boot/9990-misc-helpers.sh 2>/dev/null

#Make rsync at boot use human readable byte counter
sudo sed -i 's/rsync -a --progress/rsync -a -h --progress/g' /lib/live/boot/9990-toram-todisk.sh 2>/dev/null

#Fix boot messages
sudo sed -i 's#\(echo " [*] Copying $MODULETORAMFILE to RAM" 1>/dev/console\)#\1\
				echo -n " * `basename $MODULETORAMFILE` is: " 1>/dev/console\
				rsync -a -h -n --progress ${MODULETORAMFILE} ${copyto} | grep "total size is" | grep -Eo "[0-9]+[.]*[0-9]*[mMgG]" 1>/dev/console\
				echo 1>/dev/console#g' /lib/live/boot/9990-toram-todisk.sh 2>/dev/null

#Hide umount /live/overlay error
sudo sed -i 's#\(umount /live/overlay\)#\1 2>/dev/null#g' /lib/live/boot/9990-overlay.sh 2>/dev/null

#Fix the "hwdb.bin: No such file or directory" bug (on boot)
[ -e /lib/udev/hwdb.bin ] &&
(
	cat << $'\tHWDB'
		#!/bin/sh
		PREREQ=""
		prereqs()
		{
			echo "$PREREQ"
		}

		case $1 in
		prereqs)
			prereqs
			exit 0
			;;
		esac

		. /usr/share/initramfs-tools/hook-functions             #provides copy_exec
		rm -f ${DESTDIR}/lib/udev/hwdb.bin                      #copy_exec will not overwrite an existing file
		copy_exec /lib/udev/hwdb.bin /lib/udev/hwdb.bin         #Takes location in filesystem and location in initramfs as arguments
	HWDB
) | sed 's/^\t\t//' | sudo tee /usr/share/initramfs-tools/hooks/hwdb.bin >/dev/null

#Fix permissions
sudo chmod 755 /usr/share/initramfs-tools/hooks/hwdb.bin
sudo chown root:root /usr/share/initramfs-tools/hooks/hwdb.bin

#########################################
# Update the kernel module dependencies #
#########################################

echo
echo "Updating the kernel module dependencies..."
sudo depmod -a

if [[ "$?" != 0 ]] 
then
        echo "Kernel module dependencies failed to update."
	echo
        echo "Exiting..."
        exit 1
else
        echo "Kernel module dependencies updated successfully."
fi

########################
# Update the initramfs #
########################

echo
echo "Updating the initramfs..."
sudo update-initramfs -u

if [[ "$?" != 0 ]] 
then
        echo "Initramfs failed to update."
	echo
        echo "Exiting..."
        exit 1
else
        echo "Initramfs updated successfully."
fi

##################################################
# Create folder where RAM Session will be stored #
##################################################

sudo mkdir -p ${DEST}

###########################################################################
# Write files to / to identify where you are - Original OS or RAM Session #
###########################################################################

sudo bash -c 'echo "This is the RAM Session. Your OS is running from within RAM." > '${DEST}'/RAM_Session'
sudo bash -c 'echo "This is your Original OS. You are NOT inside the RAM Session." > /Original_OS'

###########################
# Add Grub2 entry to menu #
###########################

GrubEntry

#################################################################
# Modify /etc/grub.d/10_linux so grub doesn't make menu entries #
# for kernels that can't run                                    #
#################################################################
if ! grep -q '\[ x"$i" = x"$SKIP_KERNEL" \] && continue' /etc/grub.d/10_linux
then
	sudo sed -i 's@\(if grub_file_is_not_garbage\)@MOD_PREFIX=$([ -e /RAM_Session ] \&\& echo "/mnt/" || echo "")\n                  [ -d $MOD_PREFIX/lib/modules/${i#/boot/vmlinuz-} ] || continue\n                  \1@g' /etc/grub.d/10_linux
fi

########################
# Copy the OS to $DEST #
########################

CopyFileSystem

###############
# Update Grub #
###############

echo
echo "Updating grub:"
sudo update-grub

#############################################
# Add note to fake /boot that it's not real #
#############################################
echo "This is NOT the real /boot. This is a temporary /boot that software you install in the RAM Session can use to stay happy. The real boot is mounted when you use one of the scripts to update or make changes." | sudo tee $DEST/boot/IMPORTANT_README >/dev/null

##############################################
# Remove /boot from RAM Session's /etc/fstab #
##############################################
#Reasoning:
#Because of the nature of the RAM Session - the fact that it reverts
#back to a previous state after a reboot, if /boot was placed into a
#separate partition, it would be exempt from this action. In cases where
#software is installed that makes changes to /boot, such as changes
#to initrd images, a reboot would result in the software that made the
#changes being removed while the initrd image would still contain the
#changes. This would cause the OS to be in an inconsistent state. I'm no
#expert on the linux kernel by any means, and I have no idea if this is
#dangerous in any way, but updating /boot only when a permanent software
#update is going to be made just seems like the cleanest alternative.
sudo sed -i '/^UUID=[-0-9a-zA-Z]*[ \t]*\/boot[ \t]/d' $DEST/etc/fstab
sudo sed -i '/^\/dev\/...[0-9][ \t]*\/boot[ \t]/d' $DEST/etc/fstab

#################
# Cleanup Tasks #
#################

#Clean some unnecessary files
#Note: The 'root' we skip is the name of root's cron file. Since we
#might be writing to it, we don't want to delete it
echo
echo "Cleaning unnecessary files:"
sudo find ${DEST}/var/run ${DEST}/var/crash ${DEST}/var/mail ${DEST}/var/spool ${DEST}/var/lock ${DEST}/var/backups ${DEST}/var/tmp -type f -not -name "root" -exec rm {} \;

#Delete only OLD log files
echo
echo "Deleting old log files:"
sudo find ${DEST}/var/log -type f -iregex '.*\.[0-9].*' -exec rm -v {} \;
sudo find ${DEST}/var/log -type f -iname '*.gz' -exec rm -v {} \;

#Clean current log files
echo
echo "Cleaning recent log files:"
sudo find ${DEST}/var/log -type f | while read file; do echo "emptied '$file'"; echo -n '' | sudo tee $file; done 

#####################################
# Add rupdate script to RAM Session #
#####################################

sudo cp -v $RUPDATE_FILE ${DEST}/usr/sbin/
sudo chown root:root ${DEST}/usr/sbin/rupdate
sudo chmod 755 ${DEST}/usr/sbin/rupdate
#Add the root device to the rupdate script
sudo sed -i 's#\(REG_DEVICE=\)#\1"'$ROOT_DEV'"#' ${DEST}/usr/sbin/rupdate

#####################################
# Add rchroot script to RAM Session #
#####################################
sudo cp -v $RCHROOT_FILE ${DEST}/usr/sbin/
sudo chown root:root ${DEST}/usr/sbin/rchroot
sudo chmod 755 ${DEST}/usr/sbin/rchroot
#Add root and boot devices to rchroot script
sudo sed -i 's#\(ROOT_DEVICE=\)#\1"'$ROOT_DEV'"#' $DEST/usr/sbin/rchroot
sudo sed -i 's#\(BOOT_DEVICE=\)#\1"'$BOOT_DEV'"#' $DEST/usr/sbin/rchroot
