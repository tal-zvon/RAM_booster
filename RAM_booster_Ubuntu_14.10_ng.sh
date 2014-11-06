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

#True if home is already on another partition. False otherwise
HOME_ALREADY_MOUNTED=$(df /home | tail -1 | grep -q '/home' && echo true || echo false)

#True if /home should just be copied over to /var/squashfs/home
#False otherwise
#Note: Do NOT remove the default value
COPY_HOME=true

#The new location of /home
#Note: Here, we check the old location of /home, but later we can change it
#to reflect the new location
HOME_DEV=$(readlink -f `df /home | tail -1 | grep '/home' | cut -d ' ' -f 1` 2>/dev/null)

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
ECHO "This script will create a copy of your Ubuntu OS in /var/squashfs/ and then use that copy to create a squashfs image of it located at /live. After this separation, your old OS and your new OS (the RAM Session) will be two completely separate entities. Updates of one OS will not affect the update of the other (unless done so using the update script - in which case two separate updates take place one after the other), and the setup of packages on one will not transfer to the other. Depending on what you choose however, your /home may be shared between the two systems."

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
			#Ask user which partition to use for /home
			clear
			ECHO "Which partition do you want to use as /home?"
			read -p "Your choice: " -e HOME_DEV

			#Check if device exists
			if [[ ! -b "$HOME_DEV" ]]
			then
				echo
				ECHO "\"$HOME_DEV\" is not a valid device. Please rerun the script and specify the device name of a partition or logical volume."
				echo "Exiting..."
				exit 1
			fi

			#Make sure the device is a partition (not an entire physical drive) or a logical volume
			if ! (echo $HOME_DEV | grep -q '/dev/sd[a-z][0-9]') && ! (sudo lvdisplay $HOME_DEV &>/dev/null)
			then
				echo
				ECHO "\"$HOME_DEV\" is neither a partition, nor a logical volume. Please rerun the script and specify the device name of a partition or logical volume."
				echo "Exiting..."
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

			sudo mount $HOME_DEV /mnt/tmp 2>/dev/null

			#Check if there were problems mounting the device
			if [[ "$?" != 0 ]]
			then
				ECHO "There was a problem with the device you gave. It would not mount. If this is a brand new drive and the partition has never been formatted, please format it as ext4 before running this script. Otherwise, please fix the problem before rerunning the script."
				echo
				echo "Exiting..."
				sudo rmdir /mnt/tmp
				exit 1
			fi

			#Count how many files are on the newly mounted device
			FILE_COUNT=`sudo ls -lR /mnt/tmp | grep ^- | wc -l`
			if [[ "$FILE_COUNT" -gt 0 ]]
			then
				clear
				ECHO "The device you chose is NOT empty! Are you sure you want to delete all data on it? Type \"I am sure\" to proceed, or \"ls\" to see what's on the device you chose."
				echo
				read -p "Your choice: " answer

				#Convert answer to lowercase
				answer=$(toLower $answer)

				echo

				if [[ "$answer" == "ls" ]]
				then
					#Without running in the background, nautilus doesn't release the terminal
					nautilus /mnt/tmp 2>/dev/null >/dev/null &
					clear
					echo "Do you still wish to format the device and erase all this data? Type \"I do\" to proceed or anything else to exit." | fmt -w `tput cols`
					echo
					read -p "Your choice: " answer

					#Convert answer to lowercase
					answer=$(toLower $answer)

					if [[ "$answer" == "I do" ]]
					then
						echo -e "Formatting $HOME_DEV\n"
					else
						echo "Exiting..."
						sudo umount /mnt/tmp && sudo rmdir /mnt/tmp
						exit 1
					fi
				elif [[ "$answer" == "I am sure" ]]
				then
					echo -e "Formatting $HOME_DEV\n"
				else
					echo "$answer is an invalid choice"
					echo "Exiting..."
					sudo umount /mnt/tmp && sudo rmdir /mnt/tmp
					exit 1
				fi
			else
				echo "Everything checks out."
				echo -e "Formatting $HOME_DEV\n"
			fi

			#Unmount the device
			sudo umount /mnt/tmp
			sudo rmdir /mnt/tmp

			#Format the device
			sudo mkfs.ext4 -L home $HOME_DEV

			#Check if there was a problem formatting the device
			if [[ "$?" != 0 ]]
			then
				echo "Formatting $HOME_DEV failed."
				echo "Exiting..."
				exit 1
			fi
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
