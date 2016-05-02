#!/sbin/busybox sh
#script init pull from neobuddy89 github

# Mount root as RW to apply tweaks and settings
mount -o remount,rw /;
mount -o rw,remount /system

# Make tmp folder
if [ -e /tmp]; then
	echo "tmp already exist"
else
mkdir /tmp;
fi

# Give permissions to execute
chmod -R 777 /tmp/;
chmod 6755 /sbin/*;
chmod 6755 /system/xbin/*;
echo "BHB27-Kernel Boot initiated on $(date)" > /tmp/bootcheck-bhb;

#enable, disable and tweak some features of the kernel by default for better performance vs battery

# Thremal - Disable msm core cotrol it doesnot work with intellitermal
echo 0 > /sys/module/msm_thermal/core_control/enabled

# CPU - Disable hotplug boost
echo 0 > /sys/module/cpu_boost/parameters/hotplug_boost

# CPU - set max clock to sotck value
chmod 644 /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
echo 2649600 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
chmod 444 /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq

chmod 644 /sys/devices/system/cpu/cpu1/cpufreq/scaling_max_freq
echo 2649600 > /sys/devices/system/cpu/cpu1/cpufreq/scaling_max_freq
chmod 444 /sys/devices/system/cpu/cpu1/cpufreq/scaling_max_freq

chmod 644 /sys/devices/system/cpu/cpu2/cpufreq/scaling_max_freq
echo 2649600 > /sys/devices/system/cpu/cpu2/cpufreq/scaling_max_freq
chmod 444 /sys/devices/system/cpu/cpu2/cpufreq/scaling_max_freq

chmod 644 /sys/devices/system/cpu/cpu3/cpufreq/scaling_max_freq
echo 2649600 > /sys/devices/system/cpu/cpu3/cpufreq/scaling_max_freq
chmod 444 /sys/devices/system/cpu/cpu3/cpufreq/scaling_max_freq

# GPU max clock to stock value, enable adreno_idler
echo 600000000 > /sys/devices/fdb00000.qcom,kgsl-3d0/kgsl/kgsl-3d0/max_gpuclk
echo Y > /sys/module/adreno_idler/parameters/adreno_idler_active

# Allow untrusted apps to read from debugfs
if [ -e /system/lib/libsupol.so ]; then
/system/xbin/supolicy --live \
	"allow untrusted_app debugfs file { open read getattr }" \
	"allow untrusted_app sysfs_lowmemorykiller file { open read getattr }" \
	"allow untrusted_app persist_file dir { open read getattr }" \
	"allow debuggerd gpu_device chr_file { open read getattr }" \
	"allow netd netd capability fsetid" \
	"allow netd { hostapd dnsmasq } process fork" \
	"allow { system_app shell } dalvikcache_data_file file write" \
	"allow { zygote mediaserver bootanim appdomain }  theme_data_file dir { search r_file_perms r_dir_perms }" \
	"allow { zygote mediaserver bootanim appdomain }  theme_data_file file { r_file_perms r_dir_perms }" \
	"allow system_server { rootfs resourcecache_data_file } dir { open read write getattr add_name setattr create remove_name rmdir unlink link }" \
	"allow system_server resourcecache_data_file file { open read write getattr add_name setattr create remove_name unlink link }" \
	"allow system_server dex2oat_exec file rx_file_perms" \
	"allow mediaserver mediaserver_tmpfs file execute" \
	"allow drmserver theme_data_file file r_file_perms" \
	"allow zygote system_file file write" \
	"allow atfwd property_socket sock_file write" \
	"allow debuggerd app_data_file dir search" \
	"allow sensors diag_device chr_file { read write open ioctl }" \
	"allow sensors sensors capability net_raw" \
	"allow init kernel security setenforce" \
	"allow netmgrd netmgrd netlink_xfrm_socket nlmsg_write" \
	"allow netmgrd netmgrd socket { read write open ioctl }" \
        "allow shell dalvikcache_data_file file { write create }" \
        "allow shell dalvikcache_data_file dir { add_name create relabelfrom relabelto remove_name rename reparent rmdir search setattr write }" \
        "allow mediaserver mediaserver_tmpfs file { read write execute }" \
        "allow isolated_app app_data_file dir search" \
        "allow untrusted_app kernel dir search" \
        "allow untrusted_app sysfs_mmi_touch dir search" \
        "allow untrusted_app healthd_service service_manager find" \
        "allow untrusted_app kernel file { ioctl read write getattr append open }" \
        "allow untrusted_app sysfs_cpuboost dir search" \
        "allow untrusted_app sysfs_cpuboost file { open read getattr }" \
        "allow init sysfs_cpuboost file getattr" \
        "allow init kernel security load_policy" \
	"allow platform_app { untrusted_app init system_app shell kernel ueventd logd vold healthd lmkd servicemanager surfaceflinger tee adbd netd debuggerd rild drmserver mediaserver installd keystore qmux netmgrd ims zygote gatekeeperd camera atfwd cnd fingerprintd system_server sdcardd wpa nfc radio isolated_app mdm_helper sensors adspd thermald bridge time dex2oat } dir search" \
        "allow platform_app { untrusted_app init system_app shell kernel ueventd logd vold healthd lmkd servicemanager surfaceflinger tee adbd netd debuggerd rild drmserver mediaserver installd keystore qmux netmgrd ims zygote gatekeeperd camera atfwd cnd fingerprintd system_server sdcardd wpa nfc radio isolated_app mdm_helper sensors adspd thermald bridge time dex2oat } file { open read getattr }" \
	"allow shell shell capability dac_override" \
	"allow dalvikcache_data_file shell file unlink"
fi;


exit;
