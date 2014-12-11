#!/bin/bash
sudo rm -v /usr/sbin/redit /usr/sbin/rupdate /usr/sbin/rupgrade
sudo rm -v /var/lib/ram_booster/rlib

sudo ln -s -v /home/test/Documents/RAM_Booster/extras_14.10/RAM_Session/rupdate /usr/sbin/
sudo ln -s -v /home/test/Documents/RAM_Booster/extras_14.10/RAM_Session/rupgrade /usr/sbin/
sudo ln -s -v /home/test/Documents/RAM_Booster/extras_14.10/RAM_Session/redit /usr/sbin/
sudo ln -s -v /home/test/Documents/RAM_Booster/extras_14.10/RAM_Session/rlib /var/lib/ram_booster/

sudo chmod -v a+x /home/test/Documents/RAM_Booster/extras_14.10/RAM_Session/rupdate
sudo chmod -v a+x /home/test/Documents/RAM_Booster/extras_14.10/RAM_Session/rupgrade
sudo chmod -v a+x /home/test/Documents/RAM_Booster/extras_14.10/RAM_Session/redit

cd /home/test/Documents/RAM_Booster/
echo "Telling RAM_Booster repo to ignore exec permissions"
git config core.fileMode false
