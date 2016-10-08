#!/system/bin/sh
mount -o rw,remount /system
if [ ! -e /data/tmp ]; then
	mkdir /data/tmp;
	echo "boot start $(date)" > /data/tmp/bootcheck.txt;
else
	echo "boot start $(date)" > /data/tmp/bootcheck.txt;
fi;

#enable, disable and tweak some features of the kernel by default for better performance vs battery

# CPU - Disable hotplug boost
echo 0 > /sys/module/cpu_boost/parameters/hotplug_boost

# GPU max clock to stock value, enable adreno_idler
echo 600000000 > /sys/devices/fdb00000.qcom,kgsl-3d0/kgsl/kgsl-3d0/max_gpuclk
echo Y > /sys/module/adreno_idler/parameters/adreno_idler_active

# Ena adaptive lmk Tune LMK
echo 1 > /sys/module/lowmemorykiller/parameters/enable_adaptive_lmk
echo 52992 > /sys/module/lowmemorykiller/parameters/vmpressure_file_min
echo 4096,8192,16640,29184,47104,52224 > /sys/module/lowmemorykiller/parameters/minfree

echo "Post init Kernel Boot initiated on $(date)" >> /data/tmp/bootcheck.txt
umount /system;
exit
