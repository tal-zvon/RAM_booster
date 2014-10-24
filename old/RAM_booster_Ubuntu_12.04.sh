#!/bin/bash

#Written On: Oct 2010
#Written By: Tal
#Written For: Ubuntu Forums Community
#Description: Creates a squashfs image of an Ubuntu OS, and adds a grub entry to copy the image to RAM before booting from it. This allows to run an entire OS out of RAM, provided the user has enough RAM.

#Make sure user didn't force script to run in sh
ps ax | grep $$ | grep bash > /dev/null || { echo "You are forcing the script to run in sh when it was written for bash. Please run it in bash instead."; exit 1; }

####################################################################
#############################Functions##############################
####################################################################

#Change user input to lower case
toLower() 
{
  echo $1 | tr "[:upper:]" "[:lower:]" 
}

#Asks for device of the partition to copy /home to and
#makes sure the device is empty and properly formatted
GetDevice()
{

		clear
		echo -e "You have chosen to enter the device name to use for /home\n" | fmt -w `tput cols`
		echo -e "Please enter the device name of the partition you wish to use for /home. This should be something like /dev/hda2 or similar. Please be certain about your choice as any data on the partition you choose will be deleted permanently!\n" | fmt -w `tput cols`
		echo -n "Your choice: "
		read -e DEVICE
		clear
		
		#Check if device exists
		if [[ ! -b "$DEVICE" ]]
		then
			echo "$DEVICE is not a valid device."
			exit 1
		fi

		#Make sure the device is a partition and not an entire physical drive
		Partition_Check=`echo $DEVICE | grep -o '[0-9]$'`
		if [[ -z "$Partition_Check" ]]
		then
			echo "$DEVICE is not a partition but an entire drive. Please rerun the script and specify the device name of a partition instead. Partition devices end in a number such as /dev/hda2" | fmt -w `tput cols`
			echo -e "\nExiting..."
			exit 1
		fi

		#Make sure the device is really empty
		echo -e "Running file check on your device...\n"

		#Make sure an /mnt/tmp doesn't exist from an earlier exit of
		#our script
		if [[ -d /mnt/tmp ]]
		then
			sudo umount /mnt/tmp 2>/dev/null >/dev/null
		else
			sudo mkdir -p /mnt/tmp
		fi

		sudo mount $DEVICE /mnt/tmp 2>/dev/null
		
		#Check if there were problems mounting the device
		if [[ "$?" != 0 ]]
		then
			echo "There was a problem with the device you gave. It would not mount. If this is a brand new drive and the partition has never been formatted, please format it as ext4 before running this script. Otherwise, please fix the problem before rerunning the script." | fmt -w `tput cols`
			echo -e "\nExiting..."
			sudo rmdir /mnt/tmp
			exit 1
		fi

		#Count how many files are on the newly mounted device
		FILE_COUNT=`sudo ls -lR /mnt/tmp | grep ^- | wc -l`
		if [[ "$FILE_COUNT" -gt 0 ]]
		then
			clear
			echo "The device you chose is NOT empty! Are you sure you want to delete all data on it? Type \"I am sure\" to proceed, or \"ls\" to see what's on the device you chose." | fmt -w `tput cols`
			echo -ne "\nYour choice: "
			read answer
			echo

			if [[ "$answer" == "ls" ]]
			then
				#Without running in the background, nautilus doesn't release the terminal
				nautilus /mnt/tmp 2>/dev/null >/dev/null &
				clear
				echo "Do you still wish to format the device and erase all this data? Type \"I do\" to proceed or anything else to exit." | fmt -w `tput cols`
				echo -ne "\nYour choice: "
				read answer

				if [[ "$answer" == "I do" ]]
				then
					echo -e "Formatting $DEVICE\n"
				else
					echo "Exiting..."
					sudo umount /mnt/tmp && sudo rmdir /mnt/tmp
					exit 1
				fi
			elif [[ "$answer" == "I am sure" ]]
			then
				echo -e "Formatting $DEVICE\n"
			else
				echo "$answer is an invalid choice"
				echo "Exiting..."
				sudo umount /mnt/tmp && sudo rmdir /mnt/tmp
				exit 1
			fi
		else
			echo "Everything checks out."
			echo -e "Formatting $DEVICE\n"
		fi

		#Unmount the device
		sudo umount /mnt/tmp
		sudo rmdir /mnt/tmp

		#Format the device
		sudo mkfs.ext4 -L home $DEVICE
}

#Make sure the OS this is being run on is supported (Ubuntu 12.04)
Check_OS()
{
OS_Check=`cat /etc/issue | grep -o '[0-9][0-9]*\.[0-9][0-9]*'`

if [[ "$OS_Check" != "12.04" ]]
then
	echo "This script was written to work with Ubuntu 12.04. You are running `cat /etc/issue | egrep -o '[a-Z]+[ ][0-9]+\.[0-9]+\.*[0-9]*'`. This means the script has NOT been tested for your OS. Run this at your own risk."  | fmt -w `tput cols`
	echo
	echo "Press enter to continue or Ctrl+C to exit"
	read key
fi
}

#Asks user what to do with /home
FindPlaceForHome()
{
echo -e "This script will create a copy of your Ubuntu OS in /var/squashfs/ and then use that copy to create a squashfs image of it located at /live. After this seporation, your old OS and your new OS (the RAM Session) will be two completely separate entities. Updates of one OS will not affect the update of the other (unless done so using the update script - in which case two separate updates take place one after the other), and the setup of packages on one will not transfer to the other. Depending on what you chose however, your /home may be shared between the two systems.\n" | fmt -w `tput cols`

#Check /etc/fstab for existing /home partition being mounted
#Ignore commented out lines
FSTAB_LINE=$(cat /etc/fstab | grep '/home' | grep -v '^#')

#If /home was already getting mounted, there's nothing else to do
if [[ -n "$FSTAB_LINE" ]]
then
	#Since there's a chance /home in /etc/fstab is identified as a UUID,
	#get /home's device name from df istead of converting the UUID to a device name
	HOMEDEV=$(df /home | grep -o '/dev/...[0-9]')

	#Make sure the rest of the script
	#knows the user's choice
	PreExistingHome='true'

	echo "You are currently using $HOMEDEV as your /home. This will be used in the RAM Session as well." | fmt -w `tput cols`
	echo -en "\nPress enter to continue"
	read -t 90 key
	return
fi

echo -en "/home is the place where your desktop, documents, music, pictures, and program settings are stored. Would you like /home to be stored on a separate partition so that it can be writable? If you choose yes, you will need to provide a device name of a partition as this script will not attempt to partition your drives for you. If you choose no, /home will be copied to the RAM session as is, and will become permanent. This means everytime you reboot, it will revert to the way it is right now. Moving it to a separate partition will also make /home shared between the two systems. If you are unsure, pick to store /home on a separate partition.: [(S)eporate/(c)opy as is]:" | fmt -w `tput cols` | perl -p0777 -i -e 's/\n$//'

echo -n ' '
read answer
clear

#Convert answer to lowercase
answer=$(toLower $answer)

#Default to separate if variable is empty
if [ ! -n "$answer" ]
then
	answer=s
fi

case "$answer" in
s|separate)
	#User chose to give /home a separate partition

	#Make sure the rest of the script
	#knows the user's choice
	NewHome='true'

	echo -e "You chose to create a separate partition for /home\n"
	echo -e "As this script is far too stupid to be able to find a partition to store your /home for you, you will need to do this yourself and tell the script the device name. The partition should be big enough to store your Desktop, Music, Pictures, and whatever else your /home will contain. I recommend a partition no smaller than 3GB. What would you like to do?:\n" | fmt -w `tput cols`
	echo "1) Launch gparted (it will be installed if necessary)
2) Enter device name to use for /home
3) Exit script"
	echo -ne "\nYour choice: "
	read answer
	echo

	#Check what user chose
	case "$answer" in
	1)
		#Option 1 - Run gparted (making sure it's installed first)
		clear
		echo "You have chosen to run gparted."
		
		#Check if gparted is already installed
		Install_Check=`which gparted`

		if [[ -n "$Install_Check" ]]
		then
			#Gparted is installed
			echo "gparted already installed. Running gparted..."
			gksudo gparted 2>/dev/null
		else
			#Gparted not installed
			echo "gparted not installed. Installing gparted..."
			sudo apt-get update >/dev/null 2>/dev/null
			sudo apt-get -y install gparted >/dev/null 2>/dev/null 

			if [[ "$?" != 0 ]]
			then
				echo -e "\nThere was an error installing gparted. You'll have to create your /home partition manually."
				exit 1
			fi

			echo "gparted installed successfully. Running gparted..." && gksudo gparted >/dev/null 2>/dev/null

		fi

		#Gparted exits
		echo -n "Are you ready to enter the device name? [y/N]: "
		read answer

		#Convert answer to lowercase
		answer=$(toLower $answer)

		#Default to no
		if [ ! -n "$answer" ]
		then
			answer=n
		fi

		#Check user's answer
		case "$answer" in
		y|yes)
			#Ask user for device of partition to store /home
			#Also verifies that the device is empty before formatting it
			GetDevice
			;;
		n|no)
			#User chose to exit
			echo "In that case, please prepare the device and rerun the script."
			exit 1
			;;
		*)
			#User chose invalid option
			echo -e "$answer is an invalid option.\n"
			echo "Exiting..."
			exit 1
			;;
		esac
		
		;;
	2)
		#Ask user for device of partition to store /home
		GetDevice
		;;
	3)
		#User chose to exit
		clear
		echo -e "Once you create a partition of sufficient size, rerun this script and point it to the right device name of that partition.\n" | fmt -w `tput cols`
		exit 1
		;;
	*)
		#User chose invalid option
		clear
		echo -e "$answer is an invalid choise.\n"
		echo "Exiting..."
		exit 1
		;;
	esac
	;;
c|copy*)
	#User chose NOT to give /home a separate partition

	#Make sure the rest of the script
	#knows the user's choice
	NewHome='false'

	echo -e "You chose to copy /home as is. I hope you know what you are doing...\n"
	;;
*)
	#User chose an invalid answer
	echo -e "Invalid answer\n"
	echo "Exiting..."
	exit 1
	;;
esac
}

#Install necessary packages, update kernel module dependencies,
#and update initramfs
Prepare()
{

#Install some essential packages
echo
echo "Installing essential packages:"
echo "Running apt-get update..."
sudo apt-get update 2>/dev/null >/dev/null
echo "Installing squashfs-tools..."
sudo apt-get -y --force-yes install squashfs-tools 2>/dev/null >/dev/null || { echo "squashfs-tools failed to install. You'll have to download and install it manually..." | fmt -w `tput cols`; exit 1; }
echo "Installing live-boot-initramfs-tools..."
sudo apt-get -y --force-yes install live-boot-initramfs-tools 2>/dev/null >/dev/null || { echo "live-boot-initramfs-tools failed to install. You'll have to download and install it manually... Try: http://packages.ubuntu.com/precise/all/live-boot-initramfs-tools/download" | fmt -w `tput cols`; exit 1; }
echo "Installing live-boot..."
sudo apt-get -y --force-yes install live-boot 2>/dev/null >/dev/null || { echo "live-boot failed to install. You'll have to download and install it manually... Try: http://packages.ubuntu.com/precise/all/live-boot/download" | fmt -w `tput cols`; exit 1; }

echo -e "Packages installed successfully\n"

#Update the kernel module dependencies
echo "Updating the kernel module dependencies..."
sudo depmod -a

if [[ "$?" != 0 ]]
then
	echo "Kernel module dependencies failed to update."
	echo -e "\nExiting..."
	exit 1
else
	echo -e "Kernel module dependencies updated successfully.\n"
fi

#Update the initramfs
echo "Updating the initramfs..."
sudo update-initramfs -u

if [[ "$?" != 0 ]]
then
	echo "Initramfs failed to update."
	echo -e "\nExiting..."
	exit 1
else
	echo -e "Initramfs updated successfully.\n"
fi

}

#Copy the filesystem to /var/squashfs
CopyFileSystem()
{

echo "Ready to copy your filesystem to /var/squashfs..."
echo "Press enter to begin"
#Set timeout incase the user left so the script continues to run
read -t 60 key

#Check if /home needs to be included in the file system transfer
if [[ "$NewHome" == "true" ]] || [[ "$PreExistingHome" == "true" ]]
then
	#Exclude /home. It will be copied later.
	sudo rsync -av --delete / ${DEST} --exclude=/mnt/* --exclude=/media/* --exclude=/proc/* --exclude=/tmp/* --exclude=/dev/* --exclude=/sys/* --exclude=/home/* --exclude=/etc/mtab --exclude=/live --exclude=/RAM_Session --exclude=/Original_OS --exclude=${DEST} 2>&1 | tee /tmp/fs_sync
else
	#Don't exclude /home. Delete anything in Trash for every user being copied.
	sudo rsync -av --delete / ${DEST} --exclude=/mnt/* --exclude=/media/* --exclude=/proc/* --exclude=/tmp/* --exclude=/dev/* --exclude=/sys/* --exclude=/etc/mtab --exclude=/live --exclude=.gvfs --exclude=.local/share/Trash/files/* --exclude=/RAM_Session --exclude=/Original_OS --exclude=${DEST} 2>&1 | tee /tmp/fs_sync
fi

#Since we are piping the previous command to tee,
#we can't just check $?
EX_Code="${PIPESTATUS[0]}"

#Check how the operation went
case "$EX_Code" in
	0)
		echo -e "Filesystem copied successfully.\n"
		;;
	24)
		#Some files vanished while rsync was copying the FS

		echo -e "\nThe following files vanished since filesystem duplication began:\n"
		grep 'vanished' /tmp/fs_sync | grep -vi 'code 24'
		echo "Press enter to continue"
		read key
		echo
		;;
	*)
		echo -e "\nCopying filesystem failed."
		echo -e "\nExiting..."
		sudo rm /tmp/fs_sync
		exit 1
		;;
esac

sudo rm /tmp/fs_sync

}

# Fix potential missing eth0 when MAC addresses change. 
# Forces OS to detect "new" ethernet adapter and auto write new rule.
UpdateNetRules()
{
	rules_file="${DEST}/etc/udev/rules.d/70-persistent-net.rules"

	if [ ! -f ${rules_file} ]
	then
		return 1
	fi

	echo "Updating network rules in ${rules_file}"

	sed -i 's/^SUBSYSTEM/#SUBSYSTEM/g' ${rules_file}

	return 0
}

#Copy /home to new partition
CopyHome()
{

	echo "Copying /home to new partition..."
	sudo mkdir -p /mnt/home && sudo mount $DEVICE /mnt/home && sudo rsync --progress -rav --exclude=.gvfs --exclude=.local/share/Trash/files/* /home/* /mnt/home/

	if [[ "$?" != 0 ]]
	then
		echo "Copying /home to $DEVICE failed."
		echo -e "\nExiting..."
		sudo umount /mnt/home && sudo rmdir /mnt/home
		exit 1
	else
		echo "/home copied successfully."
		echo
	fi

	#Modify RAM session's fstab to mount /home partition
	sudo bash -c 'echo "'$DEVICE'	/home	ext4	auto	0 0" >> '$DEST'/etc/fstab'

	#Modify regular system to mount /home partition as well
	sudo bash -c 'echo "'$DEVICE'	/home	ext4	auto	0 0" >> /etc/fstab'

}

#Delete things that take space and we can do without
Cleanup()
{

#Clean some unnecessary files
#The "root" we skip is the name of root's cron file. Since we'll be writing to it,
#we don't want it to be deleted
echo "Cleaning unnecessary files..."
[ -n "$DEST" ] && sudo find ${DEST}/var/run ${DEST}/var/crash ${DEST}/var/mail ${DEST}/var/spool ${DEST}/var/lock ${DEST}/var/backups ${DEST}/var/tmp -type f -not -name "root" -exec rm {} \; 2>/dev/null

#Delete only OLD log files
echo "Deleting old log files:"
[ -n "$DEST" ] && sudo find ${DEST}/var/log -type f -iregex '.*\.[0-9].*' -exec rm -v {} \;
[ -n "$DEST" ] && sudo find ${DEST}/var/log -type f -iname '*.gz' -exec rm -v {} \;

#Clean current log files
echo -e "\nCleaning old log files..."
[ -n "$DEST" ] && sudo find ${DEST}/var/log -type f | while read file; do echo -n '' | sudo tee $file; done

#Clean Package cache
echo "Cleaning package cache:"
[ -n "$DEST" ] && sudo rm -v ${DEST}/var/cache/apt/archives/*.deb

#Fix gvfs crashing
echo -e "\nRemoving gvfs-metadata folder:"
if [[ "$NewHome" == "true" ]]
then
	#Delete metadata	
	sudo rm -rfv /mnt/home/*/.local/share/gvfs-metadata
else
	#Delete metadata
	sudo rm -rfv ${DEST}/home/*/.local/share/gvfs-metadata
fi

}

#Create the squashfs image
MakeSquashFS()
{

echo -e "\nCreating squashfs image..."
sudo mkdir -p /live
sudo mksquashfs ${DEST} /live/filesystem.squashfs -noappend -always-use-fragments

#See how it went
if [[ "$?" != 0 ]]
then
	echo "Squashfs image creation failed."
	echo -e "\nExiting..."

	if [[ "$NewHome" == "true" ]]
	then
		sudo umount /mnt/home && sudo rmdir /mnt/home
	fi
	exit 1
else
	echo -e "\nSquashfs image created successfully.\n"
fi

#Find out how big the squashfs image ended up being
Image_Size=`sudo du -h /live/filesystem.squashfs | awk '{ print $1 }'`

}

#Add grub2 entry
GrubEntry()
{

#Adding entry to Grub2 menu
echo "Adding entry to Grub2 menu"

(
cat << '06_RAMSESS'
#!/bin/sh -e

KER_NAME=$(ls /boot/ | grep vmlinuz | sort -n | tail -1 | sed 's/vmlinuz-//')

if [ -z "$KER_NAME" ]
then
        KER_NAME=$(uname -r)
fi

cat << EOF

menuentry "Ubuntu, Linux $KER_NAME to RAM" {
  set uuid_grub_boot=BOOT_UUID
  set uuid_os_root=ROOT_UUID

  search --no-floppy --fs-uuid \$uuid_os_root --set=root
  search --no-floppy --fs-uuid \$uuid_grub_boot --set=grub_boot

  set grub_boot=(\$grub_boot)

  if [ \$uuid_grub_boot == \$uuid_os_root ] ; then                 
     set grub_boot=\$grub_boot/boot
  fi

  linux \$grub_boot/vmlinuz-$KER_NAME boot=live toram=filesystem.squashfs apparmor=0 security="" root=/dev/disk/by-uuid/\$uuid_os_root ro
  initrd \$grub_boot/initrd.img-$KER_NAME
}
EOF
06_RAMSESS
) | sudo tee /etc/grub.d/06_RAMSESS >/dev/null

#See how it went
if [[ "$?" != 0 ]]
then
	echo "Failed to add entry to Grub menu."
	echo "You'll have to do this manually."
else
	echo "Grub entry added successfully."
fi

#Replace BOOT_UUID and ROOT_UUID above with actual values
sudo sed -i 's/ROOT_UUID/'$ROOT_UUID'/' /etc/grub.d/06_RAMSESS
sudo sed -i 's/BOOT_UUID/'$BOOT_UUID'/' /etc/grub.d/06_RAMSESS

#Make script executable
sudo chmod a+x /etc/grub.d/06_RAMSESS

#Unhide grub menu by uncommenting line in /etc/default/grub
sudo sed -i 's/\(GRUB_HIDDEN_TIMEOUT=0\)/#\1/g' /etc/default/grub

#Commit the changes by updating the grub menu
sudo update-grub2

}

#Undo everything the script does (Uninstall)
RevertChanges()
{
	echo -e "Uninstalling...\n"

	#Delete /mnt/tmp
	if [[ -d /mnt/tmp ]]; then
		echo "Removing /mnt/tmp..."
		(sudo umount /mnt/tmp 2>/dev/null >/dev/null && sudo rmdir /mnt/tmp) || { echo "/mnt/tmp failed to delete. Is it empty? - it should be. You'll have to do this manually..."; }
	fi

	#Delete /var/squashfs
	if [[ -d /var/squashfs ]]; then
		echo "Removing /var/squashfs..."
		sudo rm -rf /var/squashfs
	fi

	#Unmount /mnt/home and delete it
	if [[ -d /mnt/home ]]; then
		echo "Removing /mnt/home..."
		(sudo umount /mnt/home 2>/dev/null >/dev/null && sudo rmdir /mnt/home) || { echo "/mnt/home failed to delete. Is it empty? - it should be. You'll have to do this manually..."; }
	fi

	#Delete /live
	if [[ -d /live ]]; then
		echo "Removing /live..."
		sudo rm -rf /live
	fi

	#Delete /etc/grub.d/06_RAMSESS
	if [[ -e /etc/grub.d/06_RAMSESS ]]; then
		echo "Removing 06_RAMSESS..."
		sudo rm -f /etc/grub.d/06_RAMSESS
	fi

	#Remove temp files
	echo -e "Removing temporary files..."
	
	if [[ -e /Original_OS ]]; then
		sudo rm -f /Original_OS
	fi

	if [[ -e /tmp/fs_sync ]]; then
		sudo rm -f /tmp/fs_sync
	fi

	#Hide grub menu
	echo "Hiding grub menu..."
	sudo sed -i 's/#\(GRUB_HIDDEN_TIMEOUT=0\)/\1/g' /etc/default/grub

	#Update grub
	echo -e "\nUpdating grub:"
	sudo update-grub2

	#Tell user /home may not have been removed
	echo -e "\nIf you gave a partition during install to setup /home to, this will NOT be undone. fstab will still mount that partition to /home. If you want this reversed, you must do this manually." | fmt -w `tput cols`
	echo

	#Done
	echo "Uninstall Complete!"
	exit 0
}

#See if RAM_booster has already run on this machine
PrevRunCheck()
{
if [ -e /Original_OS ]
then
	echo -e "$0 has already run on this computer. It will not run again until you uninstall it.\n"
	echo -n "Would you like to uninstall? [y/N]: "
	read answer

	#Convert answer to lowercase
	answer=$(toLower $answer)

	#Default to no if variable is empty
	if [ ! -n "$answer" ]
	then
		answer=n
	fi

	case "$answer" in
		y|yes)
			clear
			RevertChanges
			;;
		*)
			echo "Unless you want to reinstall, there's not much else this script is good for."
			exit 0
			;;
	esac

	exit 0
fi
}

#Check if user is trying to run this script inside the RAM session
RAM_Sess_Check()
{

if [ -e /RAM_Session ]
then
	echo "This script cannot be run from inside the RAM Session."
	exit 0
fi

}

FindUUIDs()
{

ROOT_DEV=$(df / | grep -o '/dev/...[0-9]')
BOOT_DEV=$(df /boot | grep -o '/dev/...[0-9]')

ROOT_UUID=$(sudo blkid -o value $ROOT_DEV | head -1)

#If $BOOT_DEV is empty, it means /boot is not mounted and
#must be on the same drive as /
if [ -z "$BOOT_DEV" ]
then
	BOOT_UUID=$ROOT_UUID
else
	BOOT_UUID=$(sudo blkid -o value $BOOT_DEV | head -1)
fi

}

#Ask user if they wish a cronjob to be added to run the update script at night
CronAsk()
{
	echo -e "Would you like a cron job to be added to run the update script at midnight every day in the RAM Session? In order to take advantage of these updates, you would need to reboot after an update has been performed. [Y/n]\n" | fmt -w `tput cols`
		echo -n "Your choice: "
		read -t 60 answer

		#Convert answer to lowercase
		answer=$(toLower $answer)

		#Default to separate if variable is empty
		if [ ! -n "$answer" ]
		then
			answer=y
		fi

		case "$answer" in
		n|no)
			ADDCRON="false"
			echo -e "\nYou chose no."
			;;
		y|yes)
			ADDCRON="true"
			echo -e "\nYou chose yes."
			;;
		*)
			echo -e "\n$answer is invalid. Going with default (yes). To change this later, run sudo crontab -e." | fmt -w `tput cols`
			ADDCRON="true"
			;;
		esac
}

#If user hits Ctrl+C, revert changes
CtrlC()
{
	echo
	echo "You interupted the script while it was running. Would you like to revert all the changes it made so you can start fresh next time you run the script? WARNING: This will delete any existing RAM Session! [Y/n]" | fmt -w `tput cols`
	echo -en "\nYour choice: "
	read answer

	#Convert answer to lowercase
	answer=$(toLower $answer)

	#Default to separate if variable is empty
	if [ ! -n "$answer" ]
	then
		answer=y
	fi

	case "$answer" in
	n|no)
		echo -e "\nIf you say so. You may want to run \"$0 --uninstall\" however before running the script again, just to make sure nothing is left to get in its way." | fmt -w `tput cols`
		exit 0
		;;
	y|yes)
		echo
		RevertChanges
		exit 0
		;;
	*)
		echo -e "\n$answer is invalid. Going with default (yes)." | fmt -w `tput cols`
		echo
		RevertChanges
		exit 0
		;;
	esac
}

#Adds update script to RAM Session
AddUpdate()
{

(
cat << 'rupdate'
#!/bin/bash

#Written On: Oct 2010
#Written By: Tal
#Written For: Ubuntu Forums Community
#Description: Chroots into /var/squashfs and checks for updates. If updates are found, it downloads and performs them. 
#Once this is done, the .deb packages downloaded from the updates are copied to the Original OS so that if the same updates
#are to be performed on the Original OS, it would not be forced to download the packages again. Then, depending on the arguments
#the script recives, the Original OS may be updated as well. After all the updates are complete, the squashfs image is recreated
#(assuming at least one update was performed).

#Device of regular OS
REG_DEVICE=

#Only run if user is root
#Technically all the sudo's in the script would allow the script to run without the following line,
#but I find that since some of the commands take a long time to finish, sudo often times
#out, requiring you to enter your password multiple times while the script is running. 
#This interrupts the flow, preventing the user from being able to just leave the script running,
#come back, and seeing everything done.
uid=$(/usr/bin/id -u) && [ "$uid" = "0" ] ||
{ echo "You must be root to run $0. Try again with the command 'sudo $0'"; exit 1; }

#Check if it should run here
if [ ! -e /RAM_Session ]
then
	echo "This script can only be run in the RAM Session."
	exit 1
fi

#####################################################################################################
##############################Deal with arguments passed to script###################################
#####################################################################################################
# set all script variables
NICE="false"
REBOOT="false"
FORCE="false"
POPUP="false"
BOTH="false"

usage() {
         echo "Usage: $0 [-n|--nice] [-f|--force] [-p|--popup] [-r|--reboot] [-b|--both] [-h|--help]"
	 echo
	 echo "-n, --nice	mksquashfs is set to run with a nice value of 19"
	 echo "-f, --force	forces squashfs image creation even if no updates took place"
	 echo "-p, --popup	displays message on screen when update occurs"
	 echo "-r, --reboot	reboot if at least one package was updated"
	 echo "-b, --both	update the Original OS as well"
	 echo "-h, --help	display this usage guide"
}

#Check number of arguments
if [[ "$#" -gt 5 ]]
then
	echo "Too many arguments!"
	usage
	exit 1
fi

while test -n "$1"; do
   case "$1" in
      --nice|-n)
         NICE="true"
         shift
         ;;
      --force|-f)
         FORCE="true"
         shift
         ;;
      --popup|-p)
         POPUP="true"
         shift
         ;;
      --reboot|-r)
         REBOOT="true"
         shift
         ;;
      --both|-b)
         BOTH="true"
         shift
         ;;
      --help|-h)
         usage
         exit 0
         ;;
      *)
        echo "Unknown argument: $1"
        usage
        exit 1
        ;;
   esac
done

#####################################################################################################
#####################################################################################################
#####################################################################################################

#Mount Original filesystem
Orig_OS='/mnt/Original_OS'
SquashFS='var/squashfs'
sudo mkdir -p $Orig_OS
sudo mount $REG_DEVICE $Orig_OS || { echo "$REG_DEVICE failed to mount."; exit 1; }
sudo mount -o bind /proc $Orig_OS/$SquashFS/proc || { echo "/proc failed to mount."; sudo umount $REG_DEVICE; exit 1; }
sudo mount -o bind /dev $Orig_OS/$SquashFS/dev || { echo "/dev failed to mount."; sudo umount $Orig_OS/$SquashFS/proc $REG_DEVICE; exit 1; }
sudo mount -o bind /dev/pts $Orig_OS/$SquashFS/dev/pts || { echo "/dev/pts failed to mount."; sudo umount $Orig_OS/$SquashFS/proc $REG_DEVICE $Orig_OS/$SquashFS/dev; exit 1; }
sudo mount -o bind /sys $Orig_OS/$SquashFS/sys || { echo "/sys failed to mount."; sudo umount $Orig_OS/$SquashFS/proc $REG_DEVICE $Orig_OS/$SquashFS/dev $Orig_OS/$SquashFS/dev/pts; exit 1; }

#Check where the original /boot comes from
BOOT_CHECK=`cat $Orig_OS/etc/fstab | grep '/boot' | awk '{ print $1 }'`

if [[ -z "$BOOT_CHECK" ]]
then
	#/boot is NOT on a separate partition from /
	sudo mount -o bind $Orig_OS/boot $Orig_OS/$SquashFS/boot || { echo "/boot failed to mount."; sudo umount $Orig_OS/$SquashFS/proc $REG_DEVICE $Orig_OS/$SquashFS/dev $Orig_OS/$SquashFS/dev/pts $Orig_OS/$SquashFS/sys; exit 1; }
else
	#/boot IS on a separate partition from / and gets mounted by /etc/fstab 
	#Make sure $BOOT_CHECK is not a UUID
	UUID_CHECK=$(echo $BOOT_CHECK | grep -o 'UUID=[-a-z0-9]*' | sed 's/UUID=//')

	if [[ -z "$UUID_CHECK" ]]
	then
		#$BOOT_CHECK is a device
		BOOT_CHECK=$(echo $BOOT_CHECK | grep -o '/dev/...[0-9]')

		sudo mount $BOOT_CHECK $Orig_OS/$SquashFS/boot || { echo "$BOOT_CHECK failed to mount to /boot."; sudo umount $Orig_OS/$SquashFS/proc $REG_DEVICE $Orig_OS/$SquashFS/dev $Orig_OS/$SquashFS/dev/pts $Orig_OS/$SquashFS/sys; exit 1; }
	else
		#$BOOT_CHECK is a UUID
		sudo mount -U $UUID_CHECK $Orig_OS/$SquashFS/boot || { echo "$BOOT_CHECK failed to mount to /boot."; sudo umount $Orig_OS/$SquashFS/proc $REG_DEVICE $Orig_OS/$SquashFS/dev $Orig_OS/$SquashFS/dev/pts $Orig_OS/$SquashFS/sys; exit 1; }
	fi
fi

sudo cp /etc/resolv.conf $Orig_OS/$SquashFS/etc/resolv.conf

#Run the actual update
sudo chroot $Orig_OS/$SquashFS/ /bin/bash -c "apt-get update; apt-get -y dist-upgrade; apt-get -y autoremove" 2>&1 | tee /tmp/chroot_out

#Copy /boot over to fake boot so temporary programs installed in RAM session don't wonder why the OS isn't consistent with /boot.
sudo mkdir /tmp/bootdir/
sudo rsync --delete -a $Orig_OS/$SquashFS/boot/* /tmp/bootdir/

#Unmount stuff that has to be unmounted either way
sudo umount $Orig_OS/$SquashFS/proc || { echo "/proc failed to unmount because it's busy. This will fix itself after you reboot."; }
sudo umount $Orig_OS/$SquashFS/dev/pts || { echo "/dev/pts failed to unmount because it's busy. This will fix itself after you reboot."; }
sudo umount $Orig_OS/$SquashFS/dev || { echo "/dev failed to unmount because it's busy. This will fix itself after you reboot."; }
sudo umount $Orig_OS/$SquashFS/sys || { echo "/sys failed to unmount because it's busy. This will fix itself after you reboot."; }
sudo umount $Orig_OS/$SquashFS/boot

#Make sure $Orig_OS/$SquashFS/boot unmounted before copying /boot from temp to it
if [[ "$?" == 0 ]]
then
	#Copy /boot over to fake boot so temporary programs installed in RAM session don't wonder why the OS isn't consistent with /boot.
	if [[ -d /tmp/bootdir/ ]]
	then
		sudo rsync --delete -a /tmp/bootdir/* $Orig_OS/$SquashFS/boot
	fi	
else
	echo "/boot failed to unmount because it's busy. This will fix itself after you reboot."
fi

#Remove temp directory
sudo rm -rf /tmp/bootdir/

#Check if force argument was given
if [[ "$FORCE" == "true" ]]
then
	#Force rebuild squashfs image
	OUTPUT_CHECK='a'
	echo "Rebuilding of squashfs image forced."
else
	#Check /tmp/chroot_out if updates were made
	OUTPUT_CHECK=`cat /tmp/chroot_out | grep '[1-9][0-9]* upgraded, [0-9]* newly installed, [0-9]* to remove and [0-9]* not upgraded.'`
fi

if [ -z "$OUTPUT_CHECK" ]
then
	echo "Nothing was upgraded."

	#Unmount everything left
	sudo umount $Orig_OS || { echo "$Orig_OS failed to unmount because it's busy. This will fix itself after you reboot."; }

	#Delete /tmp/chroot_out
	sudo rm /tmp/chroot_out

	#Exit
	exit 0
fi

#Something was upgraded

#Mount Original OS this time
#This is because we are going to need to recreate the squashfs image
sudo mount -o bind /proc $Orig_OS/proc || { echo "/proc failed to mount the second time. Reboot and run $0 again with the -f option."; sudo rm /tmp/chroot_out; exit 1; }
sudo mount -o bind /dev $Orig_OS/dev || { echo "/dev failed to mount the second time. Reboot and run $0 again with the -f option."; sudo rm /tmp/chroot_out; sudo umount $Orig_OS/proc; exit 1; }
sudo mount -o bind /dev/pts $Orig_OS/dev/pts || { echo "/dev/pts failed to mount the second time. Reboot and run $0 again with the -f option."; sudo rm /tmp/chroot_out; sudo umount $Orig_OS/proc $Orig_OS/dev; exit 1; }
sudo mount -o bind /sys $Orig_OS/sys || { echo "/sys failed to mount the second time. Reboot and run $0 again with the -f option."; sudo rm /tmp/chroot_out; sudo umount $Orig_OS/proc $Orig_OS/dev $Orig_OS/dev/pts; exit 1; }
sudo cp /etc/resolv.conf $Orig_OS/etc/resolv.conf

#Copy apt cache from /var/squashfs to Original OS
#This is so the same packages that were just updated will not have to be redownloaded if the user
#wishes to update the Original OS
echo "Copying $Orig_OS/$SquashFS/var/cache/apt/archives to $Orig_OS/var/cache/apt/archives..."
sudo rsync -a $Orig_OS/$SquashFS/var/cache/apt/archives/*.deb $Orig_OS/var/cache/apt/archives/

#Check if we should update the Original OS
if [[ "$BOTH" == "true" ]]
then
	echo -e "\nUpdating Original OS:"

	#Update Original OS
	sudo chroot $Orig_OS/ /bin/bash -c "apt-get update; apt-get -y dist-upgrade; apt-get -y autoremove" 2>&1
fi

#Clear apt cache of RAM Session
sudo rm -f $Orig_OS/$SquashFS/var/cache/apt/archives/*.deb 2>/dev/null

#Delete files in /var/crash or you may get a crash report every time you boot
sudo rm -f $Orig_OS/$SquashFS/var/crash/* 2>/dev/null

#Make the squashfs image, but first check if we have to be nice about it
if [[ "$NICE" == "true" ]]
then
	sudo chroot $Orig_OS/ /bin/bash -c "nice -n 19 mksquashfs /$SquashFS /live/filesystem.squashfs.new -noappend -always-use-fragments"
else
	sudo chroot $Orig_OS/ /bin/bash -c "mksquashfs /$SquashFS /live/filesystem.squashfs.new -noappend -always-use-fragments"
fi

#Enable the new squashfs image
sudo chroot $Orig_OS/ /bin/bash -c "rm /live/filesystem.squashfs 2>/dev/null"
sudo chroot $Orig_OS/ /bin/bash -c "mv /live/filesystem.squashfs.new /live/filesystem.squashfs"

#Display new size of image
Image_Size=`sudo du -h $Orig_OS/live/filesystem.squashfs | awk '{ print $1 }'`
echo -e "\nThe new size of the image is $Image_Size. This MUST fit in your total RAM, with room to spare. If it does not, you either need to buy more RAM, or manually remove unimportant packages from your OS until the image fits.\n" | fmt -w `tput cols`

#Unmount unnecessary stuff
sudo umount $Orig_OS/proc || { echo "/proc failed to unmount because it's busy. This will be fixed after a reboot."; }
sudo umount $Orig_OS/dev/pts || { echo "/dev/pts failed to unmount because it's busy. This will be fixed after a reboot."; }
sudo umount $Orig_OS/dev || { echo "/dev failed to unmount because it's busy. This will be fixed after a reboot."; }
sudo umount $Orig_OS/sys || { echo "/sys failed to unmount because it's busy. This will be fixed after a reboot."; }

#If you have an SSD, you can use its read speed to boot into your RAM Session faster.
#To do this, create a small partition on your SSD, just big enough to fit the squashfs image.
#Be sure to account for the image growing a bit with future updates. Create a folder called 'live'
#on that partition. Uncomment the following lines, changing /dev/sda2 to your partition. This
#will cause the squashfs image to be copied to your SSD's partition every time it is generated.
#To make use of it however, you will need to modify grub a bit as well. See my original article
#here: http://ubuntuforums.org/showthread.php?t=1499338 to get an idea of how to do that, or post
#a comment asking about it.

#sudo mkdir -p /mnt/SSD
#sudo mount /dev/sda2 /mnt/SSD
#sudo mkdir -p /mnt/SSD/live/
#sudo rm /mnt/SSD/live/filesystem.squashfs 2>/dev/null
#sudo rsync -vh --progress $Orig_OS/live/filesystem.squashfs /mnt/SSD/live/

#Delete temp file
sudo rm /tmp/chroot_out

#Unmount the rest
#sudo umount /mnt/SSD || { echo "/mnt/SSD failed to unmount because it's busy. This will be fixed after a reboot."; }
sudo umount $Orig_OS || { echo "$Orig_OS failed to unmount because it's busy. This will be fixed after a reboot."; }

#Inform user of update completion if needed, as long as --reboot is not set
if [[ "$REBOOT" == "false" ]]
then
	if [[ "$POPUP" == "true" ]]
	then
		#Make sure zenity is allowed to be displayed on main display. Necessary when running updates from cron.
		echo 'xhost local:mpromber > /dev/null' | sudo tee -a /home/*/.bashrc >/dev/null

		#Make zenity inform user of update
		zenity --info --text="Update complete. Reboot to take advantage of it." --display=:0.0
	fi
fi

#Reboot if needed
if [[ "$REBOOT" == "true" ]]
then
	sudo reboot
fi
rupdate
) | sudo tee $DEST/usr/sbin/rupdate >/dev/null

sudo chmod a+x $DEST/usr/sbin/rupdate
sudo sed -i 's#\(REG_DEVICE=\)#\1"'$ROOT_DEV'"#' $DEST/usr/sbin/rupdate

}

#Add rchroot script to RAM Session
AddChroot()
{

(
cat << 'rchroot'
#!/bin/bash

#Written On: Oct 2010
#Written By: Tal
#Written For: Ubuntu Forums Community
#Description: Automates the process of chrooting into either the Original OS or the RAM Session's /var/squashfs to allow for editing of either.

#Only run if user is root
uid=$(/usr/bin/id -u) && [ "$uid" = "0" ] ||
{ echo "You must be root to run $0. Try again with the command 'sudo $0'"; exit 1; }

#Device of Original OS
DEVICE=

Orig_OS='/mnt/Original_OS'
SquashFS='var/squashfs'

function usage {

	echo "Usage: "
	echo "$0 -O ---- Mount Original OS"
	echo "$0 -R ---- Mount RAM Session"
	echo "$0 -U ---- Unmount all"
}

function unmount {

		if [[ `cat /tmp/mounted` == "Original" ]]
		then
			echo "Unmounting Original OS..."
			sudo umount $Orig_OS/proc
			sudo umount $Orig_OS/dev/pts
			sudo umount $Orig_OS/dev
			sudo umount $Orig_OS/sys
			sudo umount $Orig_OS/home
			sudo umount $Orig_OS
		elif [[ `cat /tmp/mounted` == "RAM" ]]
		then
			echo "Unmounting RAM Session..."
			sudo umount $Orig_OS/$SquashFS/proc
			sudo umount $Orig_OS/$SquashFS/dev/pts
			sudo umount $Orig_OS/$SquashFS/dev
			sudo umount $Orig_OS/$SquashFS/sys
			sudo umount $Orig_OS/$SquashFS/home
			sudo umount $Orig_OS
		fi
		
		rm /tmp/mounted
}

#Make sure the script did not receive too many arguments
if [[ "$#" < 1 ]] || [[ "$#" > 1 ]]
then
	usage
	exit 1
fi

case $1 in

-O)	
	#User chose to mount the Original OS

	#Check if something is already mounted.
	if [[ -e /tmp/mounted ]]
	then
		echo "Something is already mounted. Run $0 -U first."
		exit 1
	fi

	#Make note that something is about to be mounted
	echo "Original" > /tmp/mounted

	#Mount Original OS
	sudo mkdir -p $Orig_OS
	sudo mount $DEVICE $Orig_OS/ || { echo "$DEVICE failed to mount."; $0 -U; exit 1; }
	sudo mount -o bind /proc $Orig_OS/proc || { echo "/proc failed to bind to $Orig_OS/proc."; $0 -U; exit 1; }
	sudo mount -o bind /dev $Orig_OS/dev || { echo "/dev failed to bind to $Orig_OS/dev."; $0 -U; exit 1; }
	sudo mount -o bind /dev/pts $Orig_OS/dev/pts || { echo "/dev/pts failed to bind to $Orig_OS/dev/pts."; $0 -U; exit 1; }
	sudo mount -o bind /sys $Orig_OS/sys || { echo "/sys failed to bind to $Orig_OS/sys."; $0 -U; exit 1; }
	sudo mount -o bind /home $Orig_OS/home || { echo "/home failed to bind to $Orig_OS/home."; $0 -U; exit 1; }
	sudo cp /etc/resolv.conf $Orig_OS/etc/resolv.conf
	sudo chroot $Orig_OS /bin/bash

	sleep 1s
	unmount
	;;
-R)	
	#User chose to mount the RAM Session's /var/squashfs (located on the Original OS)

	#Check if something is already mounted
	if [[ -e /tmp/mounted ]]
	then
		echo "Something is already mounted. Run $0 -U first."
		exit 1
	fi

	#Make note that something is about to be mounted
	echo "RAM" > /tmp/mounted

	#Mount RAMDisk
	sudo mkdir -p $Orig_OS
	sudo mount $DEVICE $Orig_OS/ || { echo "$DEVICE failed to mount."; $0 -U; exit 1; }
	sudo mount -o bind /proc $Orig_OS/$SquashFS/proc || { echo "/proc failed to bind to $Orig_OS/$SquashFS/proc."; $0 -U; exit 1; }
	sudo mount -o bind /dev $Orig_OS/$SquashFS/dev || { echo "/dev failed to bind to $Orig_OS/$SquashFS/dev."; $0 -U; exit 1; }
	sudo mount -o bind /dev/pts $Orig_OS/$SquashFS/dev/pts || { echo "/dev/pts failed to bind to $Orig_OS/$SquashFS/dev/pts."; $0 -U; exit 1; }
	sudo mount -o bind /sys $Orig_OS/$SquashFS/sys || { echo "/sys failed to bind to $Orig_OS/$SquashFS/sys."; $0 -U; exit 1; }
	sudo mount -o bind /home $Orig_OS/$SquashFS/home || { echo "/home failed to bind to $Orig_OS/$SquashFS/home."; $0 -U; exit 1; }
	sudo cp /etc/resolv.conf $Orig_OS/$SquashFS/etc/resolv.conf
	echo -e "When you are finished, you will need to run the update script with the --force option to recreate the squashfs image.\n" | fmt -w `tput cols`
	sudo chroot $Orig_OS/$SquashFS /bin/bash
	echo -e "\nRemember to run the update script with the --force option to recreate the squashfs image or the changes you made will not appear until your next successful update.\n" | fmt -w `tput cols`

	sleep 1s
	unmount
	;;
-U)	
	#User chose to unmount everything

	#Unmount all
	echo "Unmounting all..."
	ERR=$(sudo umount $Orig_OS/$SquashFS/proc 2>&1) ||
	ERR_CHECK=$(echo $ERR | grep 'not found'); if [[ -z "$ERR_CHECK" ]]; then ERR_CHECK=$(echo $ERR | grep 'not mounted'); fi; if [[ -z "$ERR_CHECK" ]]; then echo $ERR; fi;
	ERR=$(sudo umount $Orig_OS/$SquashFS/dev/pts 2>&1) ||
	ERR_CHECK=$(echo $ERR | grep 'not found'); if [[ -z "$ERR_CHECK" ]]; then ERR_CHECK=$(echo $ERR | grep 'not mounted'); fi; if [[ -z "$ERR_CHECK" ]]; then echo $ERR; fi;
	ERR=$(sudo umount $Orig_OS/$SquashFS/dev 2>&1) ||
	ERR_CHECK=$(echo $ERR | grep 'not found'); if [[ -z "$ERR_CHECK" ]]; then ERR_CHECK=$(echo $ERR | grep 'not mounted'); fi; if [[ -z "$ERR_CHECK" ]]; then echo $ERR; fi;
	ERR=$(sudo umount $Orig_OS/$SquashFS/sys 2>&1) ||
	ERR_CHECK=$(echo $ERR | grep 'not found'); if [[ -z "$ERR_CHECK" ]]; then ERR_CHECK=$(echo $ERR | grep 'not mounted'); fi; if [[ -z "$ERR_CHECK" ]]; then echo $ERR; fi;
	ERR=$(sudo umount $Orig_OS/$SquashFS/home 2>&1) ||
	ERR_CHECK=$(echo $ERR | grep 'not found'); if [[ -z "$ERR_CHECK" ]]; then ERR_CHECK=$(echo $ERR | grep 'not mounted'); fi; if [[ -z "$ERR_CHECK" ]]; then echo $ERR; fi;
	ERR=$(sudo umount $Orig_OS/proc 2>&1) ||
	ERR_CHECK=$(echo $ERR | grep 'not found'); if [[ -z "$ERR_CHECK" ]]; then ERR_CHECK=$(echo $ERR | grep 'not mounted'); fi; if [[ -z "$ERR_CHECK" ]]; then echo $ERR; fi;
	ERR=$(sudo umount $Orig_OS/dev/pts 2>&1) ||
	ERR_CHECK=$(echo $ERR | grep 'not found'); if [[ -z "$ERR_CHECK" ]]; then ERR_CHECK=$(echo $ERR | grep 'not mounted'); fi; if [[ -z "$ERR_CHECK" ]]; then echo $ERR; fi;
	ERR=$(sudo umount $Orig_OS/dev 2>&1) ||
	ERR_CHECK=$(echo $ERR | grep 'not found'); if [[ -z "$ERR_CHECK" ]]; then ERR_CHECK=$(echo $ERR | grep 'not mounted'); fi; if [[ -z "$ERR_CHECK" ]]; then echo $ERR; fi;
	ERR=$(sudo umount $Orig_OS/sys 2>&1) ||
	ERR_CHECK=$(echo $ERR | grep 'not found'); if [[ -z "$ERR_CHECK" ]]; then ERR_CHECK=$(echo $ERR | grep 'not mounted'); fi; if [[ -z "$ERR_CHECK" ]]; then echo $ERR; fi;
	ERR=$(sudo umount $Orig_OS/home 2>&1) ||
	ERR_CHECK=$(echo $ERR | grep 'not found'); if [[ -z "$ERR_CHECK" ]]; then ERR_CHECK=$(echo $ERR | grep 'not mounted'); fi; if [[ -z "$ERR_CHECK" ]]; then echo $ERR; fi;
	ERR=$(sudo umount $Orig_OS 2>&1) ||
	ERR_CHECK=$(echo $ERR | grep 'not found'); if [[ -z "$ERR_CHECK" ]]; then ERR_CHECK=$(echo $ERR | grep 'not mounted'); fi; if [[ -z "$ERR_CHECK" ]]; then echo $ERR; fi;

	#Delete temp file if it exists
	if [[ -e /tmp/mounted ]]
	then
		sudo rm /tmp/mounted
	fi
	;;
*)
	usage
	exit 1	

esac
rchroot
) | sudo tee $DEST/usr/sbin/rchroot >/dev/null

sudo chmod a+x $DEST/usr/sbin/rchroot
sudo sed -i 's#\(DEVICE=\)#\1"'$ROOT_DEV'"#' $DEST/usr/sbin/rchroot
}

####################################################################
########################End of Functions############################
####################################################################

###################################
########Beginning of Script########
###################################

#Only run if user is root
uid=$(/usr/bin/id -u) && [ "$uid" = "0" ] ||
{ echo "You must be root to run $0. Try again with the command 'sudo $0'"; exit 1; }

#If $1 is --uninstall, force uninstall and exit
if [[ "$1" == "--uninstall" ]]
then
	clear
	RevertChanges
	exit 0
fi

clear
#Make sure OS is supported
Check_OS

clear
#Check if RAM_booster has already run on this machine
PrevRunCheck

#Check if user is trying to run this script from within
#the RAM Session
RAM_Sess_Check

clear
#Find out what the user wants to do with /home
FindPlaceForHome

#Ask if cronjob for updates should be added
clear
CronAsk

#This will make sure if the user hits Ctrl+C at any point,
#the script will offer to clean up after itself
trap CtrlC SIGINT

#Do a few things before copying the OS
Prepare

#Create Destination
DEST=/var/squashfs
sudo mkdir -p ${DEST}

#Write files to / to identify where you are if you forget
sudo bash -c 'echo "This is the RAM Session. Your OS is running from within RAM." > '${DEST}'/RAM_Session'
sudo bash -c 'echo "This is your original OS. You are NOT inside the RAM Session." > /Original_OS'

#Write down UUIDs of /boot and / for later use
#in 06_RAMSESS script
FindUUIDs

#Add grub2 entry to menu
GrubEntry

#Copy the OS to /var/squashfs
echo
CopyFileSystem

# Fix Missing eth adapter(s)
UpdateNetRules

#Add update job to crontab if necessary
if [[ "$ADDCRON" == "true" ]]
then
	sudo chroot $DEST /bin/bash -c "echo '@daily /usr/sbin/rupdate --popup --nice --both' | sudo crontab"
fi

#Fix time bug
sudo sed -i 's/exit 0$/dpkg-reconfigure --frontend noninteractive tzdata\n\nexit 0/' $DEST/etc/rc.local

#Add note to fake /boot
echo "This is NOT the real /boot. This is a temporary /boot that software you install in the RAM Session can use to stay happy. The real boot is mounted when you use one of the scripts to update or make changes." | sudo tee $DEST/boot/IMPORTANT_README >/dev/null

#Copy /home to new partition if necessary
if [[ "$NewHome" == "true" ]]
then
	echo "Ready to copy /home to new partition."
	echo -e "Press enter to begin\n"
	
	#If the user is present, let him read the output if he wishes before
	#continuing to scroll by. If the user is away, let the script finish
	#by timing out the readkey after 60 seconds
	read -t 60 key
	#Copy /home to new partition
	CopyHome
fi

#Remove entry for root directory in RAM session's fstab
sudo sed -i '/^UUID=[-0-9a-z]*[ ]*\/[ ]/d' $DEST/etc/fstab

#Remove entry for /boot in RAM session's fstab
#Reasoning:
#Because of the nature of the RAM session - the fact that it reverts back to a previous state after a reboot,
#if /boot was placed into a separate partition, it would be discluded from this action. In cases where software
#is installed that makes changes to /boot, such as vmware, which makes changes to the initrd image, and a reboot
#is performed, the software would be removed without giving it a chance to revert the initrd image back to its
#original state in /boot, and since /boot would still contain the changes, the OS would be in an inconsistent
#state. I'm no expert on the linux kernel by any means, and I have no idea if this is dangerous in any way, but
#updating /boot only when a permanent software update is going to be made just seems like the cleanest alternative.

#This comments out the /boot in RAM Session's /etc/fstab.
sudo sed -i 's/\(^UUID=[-0-9a-z]*[ \t]*\/boot[ \t]\)/#\1/' $DEST/etc/fstab
sudo sed -i 's/\(^\/dev\/...[0-9][ \t]*\/boot[ \t]\)/#\1/' $DEST/etc/fstab

#Perform cleanup
Cleanup

#Add scripts to RAM session
AddUpdate
AddChroot
#AddPanelFix

#Fix "Press enter to reboot" annoyance
sudo sed -i 's/\(read x < \/dev\/console\)/#\1/' $DEST/etc/init.d/live-initramfs

#Create the squashfs image
MakeSquashFS

#Unmount /mnt/home
if [[ "$NewHome" == "true" ]]
then
	sudo umount /mnt/home && sudo rmdir /mnt/home
fi

#Last words
clear

#Tell user how much RAM they should have
echo -e "The size of the image is $Image_Size. This MUST fit in your total RAM, with room to spare. If it does not, you either need to buy more RAM, or manually remove unimportant packages from your OS until the image fits.\n" | fmt -w `tput cols`

echo -e "Note: Do NOT format your original OS that you made the RAM Session out of as the image that gets loaded into RAM everytime you boot into the RAM Session still resides there. So does /var/squashfs, the folder the image gets recreated from everytime you make any changes to the RAM Session through the update scripts. You should be able to shrink the partition with your original OS however in order to save space. If saving space on that partition is your goal, and you chose to place your /home on a seporate partition, you can remove the old /home files which are still in the same place they used to be, they just get hidden by the new /home partition.\n" | fmt -w `tput cols`

echo "Also, if you switch between your original OS and your RAM Session a lot, and forget which one you are in, do an 'ls /'. If you see the /Original_OS file, you are in the original OS. If you see the /RAM_Session file, you are in the RAM Session." | fmt -w `tput cols`
