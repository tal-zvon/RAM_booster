#!/bin/bash
sudo rm -v /usr/sbin/rchroot /usr/sbin/rupdate /usr/sbin/rupgrade
sudo rm -v /var/lib/ram_booster/rlib

sudo ln -s -v /home/test/Documents/RAM_Booster/extras_14.10/rupdate /usr/sbin/
sudo ln -s -v /home/test/Documents/RAM_Booster/extras_14.10/rupgrade /usr/sbin/
sudo ln -s -v /home/test/Documents/RAM_Booster/extras_14.10/rchroot /usr/sbin/
sudo ln -s -v /home/test/Documents/RAM_Booster/extras_14.10/rlib /var/lib/ram_booster/
sudo ln -s -v /home/test/Documents/RAM_Booster/extras_14.10/postinst.d/version_check.sh /etc/kernel/postinst.d/

sudo chmod -v a+x /home/test/Documents/RAM_Booster/extras_14.10/rupdate
sudo chmod -v a+x /home/test/Documents/RAM_Booster/extras_14.10/rupgrade
sudo chmod -v a+x /home/test/Documents/RAM_Booster/extras_14.10/rchroot
sudo chmod -v a+x /home/test/Documents/RAM_Booster/extras_14.10/postinst.d/version_check.sh

cd /home/test/Documents/RAM_Booster/
echo "Telling RAM_Booster repo to ignore exec permissions"
git config core.fileMode false
