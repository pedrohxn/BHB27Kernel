#!/system/bin/sh

# Install Busybox
/sbin/busybox --install -s /sbin

# Init.d Support
/sbin/busybox run-parts /system/etc/init.d

exit
