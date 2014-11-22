#!/bin/bash
#Check if there is a backup of the original script
if [[ ! -e /usr/sbin/update-grub.orig ]]
then
	#If the script is unmodded, make one
	if ! grep -q 'RAM_Session' /usr/sbin/update-grub
	then
		sudo cp -av /usr/sbin/update-grub /usr/sbin/update-grub.orig
	else
		echo update-grub already modded - not backing up
	fi
else
	echo update-grub.orig already exists
fi

#Only do this if it hasn't already been done
#Outside of the if statement above in case there was already a backup
#But the original file was never modded
! grep -q 'RAM_Session' /usr/sbin/update-grub &&
sudo sed -i '$i\
if [ -e /RAM_Session ]\
then\
	if [ "$(ls -di / | cut -d " " -f 1)" = 2 ] || [ "$(ls -di / | cut -d " " -f 1)" = 128 ]\
	then\
		echo "update-grub cannot be run from RAM Session. Ignoring grub-update request"\
		exit 0\
	fi\
fi' /usr/sbin/update-grub ||
echo "update-grub already modded - not modding again"
