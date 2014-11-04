#!/bin/bash

#Path to the file that contains all the functions for this script
RAM_LIB='./ram_lib'

if [[ -e $RAM_LIB ]]
then
	. $RAM_LIB
else
	echo "The library that comes with RAM Booster ($RAM_LIB) was not found!"
	exit 1
fi

#Only run if user is root
uid=$(/usr/bin/id -u) && [ "$uid" = "0" ] || 
{ echo "You must be root to run $0. Try again with the command 'sudo $0'" | fmt -w `tput cols`; exit 1; } 

#If $1 is --uninstall, force uninstall and exit
if [[ "$1" == "--uninstall" ]]
then
        clear
        RevertChanges
        exit 0
elif [[ "$1" != "" ]]
then
	clear
	echo "\"$1\" is not a valid argument" | fmt -w `tput cols`; exit 1; }
	exit 1
fi

