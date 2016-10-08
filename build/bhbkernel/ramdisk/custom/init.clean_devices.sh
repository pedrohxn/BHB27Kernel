#!/system/bin/sh

if [ ! -e /data/tmp ]; then
	mkdir /data/tmp;
	echo "boot start $(date)" > /data/tmp/bootcheck.txt;
else
	echo "boot start $(date)" > /data/tmp/bootcheck.txt;
fi;

# Isu support
mount -o rw,remount /system
if [ -e /system/bin/temp_su ]; then
	mv /system/bin/temp_su /system/bin/su
fi

if [ -e /system/xbin/isu ]; then
	mv /system/xbin/isu /system/xbin/su
	if [ ! -e /system/bin/su ]; then
		ln -s -f /system/xbin/su /system/bin/su
	fi
# give su root:root to adb su work optional/recommended
if [ -e /system/xbin/su ]; then
	chown root:root /system/xbin/su
fi
reboot
fi
umount /system;
# Isu end

fsgid=`getprop ro.boot.fsg-id`;
device=`getprop ro.boot.hardware.sku`

## Clean Verizon blobs on others devices
if  [ "$device" == XT1225 ] ||  [ "$fsgid" == emea ] || [ "$fsgid" == singlela ]; then

	mount -o rw,remount /system
	# delete main folders
	app="system/app";
	bin="system/bin";
	etc="system/etc/permissions";
	frameworks="system/frameworks";
	lib="system/lib";
	priv_app="system/priv-app";
	vendor_lib="system/vendor/lib";

	##delete:
	#apps
	rm -rf $app/ims;
	rm -rf $app/VZWAPNLib;
	rm -rf $priv_app/AppDirectedSMSProxy;
	rm -rf $priv_app/BuaContactAdapter;
	rm -rf $priv_app/VZWAPNService;

	#bin
	rm -rf $bin/imsdatadaemon;
	rm -rf $bin/imsqmidaemon;

	#etc
	rm -rf $etc/com.verizon.hardware.telephony.ehrpd.xml;
	rm -rf $etc/com.verizon.hardware.telephony.lte.xml;
	rm -rf $etc/com.verizon.ims.xml;
	rm -rf $etc/rcsimssettings.xml;
	rm -rf $etc/rcsservice.xml;
	rm -rf $etc/com.motorola.DirectedSMSProxy.xml
	rm -rf $etc/com.vzw.vzwapnlib.xml

	#frameworks
	rm -rf $frameworks/com.verizon.hardware.telephony.ehrpd.jar;
	rm -rf $frameworks/com.verizon.hardware.telephony.lte.jar;
	rm -rf $frameworks/com.verizon.ims.jar;
	rm -rf $frameworks/rcsimssettings.jar;
	rm -rf $frameworks/rcsservice.jar;

	#libs
	rm -rf $lib/libimscamera_jni.so;
	rm -rf $lib/libimsmedia_jni.so;

	# vendor/lib
	rm -rf $vendor_lib/lib-dplmedia.so;
	rm -rf $vendor_lib/lib-ims-setting-jni.so;
	rm -rf $vendor_lib/lib-ims-settings.so;
	rm -rf $vendor_lib/lib-imsSDP.so;
	rm -rf $vendor_lib/lib-imsdpl.so;
	rm -rf $vendor_lib/lib-imsqimf.so;
	rm -rf $vendor_lib/lib-imsrcs.so;
	rm -rf $vendor_lib/lib-imss.so;
	rm -rf $vendor_lib/lib-imsvt.so;
	rm -rf $vendor_lib/lib-imsxml.so;
	rm -rf $vendor_lib/lib-rcsimssjni.so;
	rm -rf $vendor_lib/lib-rcsjni.so;
	rm -rf $vendor_lib/lib-rtpcommon.so;
	rm -rf $vendor_lib/lib-rtpcore.so;
	rm -rf $vendor_lib/lib-rtpdaemoninterface.so;
	rm -rf $vendor_lib/lib-rtpsl.so;
	rm -rf $vendor_lib/libvcel.so;
	umount /system;
	echo "init.clean_devices $(date) file deleted for device = $device fsgid = $fsgid" >> /data/tmp/bootcheck.txt;
else
	echo "init.clean_devices $(date) file not deleted for device = $device fsgid = $fsgid" >> /data/tmp/bootcheck.txt;
fi;

