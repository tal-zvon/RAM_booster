#!/bin/bash
apt-get -y install ssh
cp -av /lib/lsb/init-functions /root/init-functions.orig
cp -av /etc/init.d/ssh /root/ssh.orig
cp -av /var/lib/dpkg/info/openssh-server.postinst /root/openssh-server.postinst.orig

mv -v init-functions /lib/lsb/
mv -v ssh /etc/init.d/
mv -v openssh-server.postinst /var/lib/dpkg/info/

