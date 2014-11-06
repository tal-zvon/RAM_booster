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

#Device of the /home partition
#Blank if same partition as /
#Note: It gets set automatically - do NOT modify
HOME_DEV=''

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

#Figure out the device of /home
#Note: $HOME_DEV will be blank if /home is on the same partition as /
HOME_DEV=$(readlink -f `df /home | tail -1 | grep '/home' | cut -d ' ' -f 1` 2>/dev/null)

clear
ECHO "This script will create a copy of your Ubuntu OS in /var/squashfs/ and then use that copy to create a squashfs image of it located at /live. After this separation, your old OS and your new OS (the RAM Session) will be two completely separate entities. Updates of one OS will not affect the update of the other (unless done so using the update script - in which case two separate updates take place one after the other), and the setup of packages on one will not transfer to the other. Depending on what you choose however, your /home may be shared between the two systems."

echo

ECHO "/home is the place where your desktop, documents, music, pictures, and program settings are stored. Would you like /home to be stored on a separate partition so that it can be writable? If you choose yes, you may need to provide a device name of a partition as this script will not attempt to partition your drives for you. If you choose no, /home will be copied to the RAM session as is, and will become permanent. This means everytime you reboot, it will revert to the way it is right now. Moving it to a separate partition will also make /home shared between the two systems."

#If /home is already on a separate partition, let the user know
if [[ -n $HOME_DEV ]]
then
	echo
	ECHO "Your /home is currently located on $HOME_DEV. If you choose to have it separate, the RAM Session will mount the $HOME_DEV device as /home as well."
fi

echo
echo -n "What would you like to do?: [(S)eporate/(c)opy as is]: "
read answer
