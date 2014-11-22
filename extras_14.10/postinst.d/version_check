#!/bin/bash
OUTPUT=''

if [[ -e /Original_OS ]]
then
	OUTPUT=/boot/Orig
fi

if [[ -e /RAM_Session ]]
then
	OUTPUT=/boot/RAM_Sess
fi

[[ -z $OUTPUT ]] && { echo "We are not in the Original OS or RAM Session"; exit 1; }

#Clear the $OUTPUT file
echo -n '' | sudo tee $OUTPUT

#For ever folder under /lib/modules, write it down to $OUTPUT
for DIR in $(find /lib/modules -maxdepth 1 -mindepth 1 -type d)
do
	basename $DIR | sudo tee -a $OUTPUT >/dev/null
done
