#!/bin/bash
# build commands check the folders location before run change it to yours taste
# place a line like this... alias bk='home/your_user/kernel_folder/build/how_to_build_this.sh' ...
# to the end of ./bashrc file that is hide under home and just use a command shortcut to call the script
# call it from the kernel folder the kernel zip if made correct will be at build/bhbkernel/

#the only thing to edit here is CROSS_COMPILE set yours, the rest is auto if the kernel doesnot build check the log build/build_log.txt
export CROSS_COMPILE=/home/fella/m/prebuilts/gcc/linux-x86/arm/arm-eabi-4.8.1/bin/arm-eabi-

rm -rf ./build/temp
rm -rf ./build/bhbkernel/modules/*.ko
rm -rf ./build/bhbkernel/modules/qca_cld/*.ko
mkdir ./build/temp
export ARCH=arm
export KBUILD_OUTPUT=./build/temp
make clean && make mrproper
time make quark_defconfig && time make -j4 2>&1 | tee ./build/build_log.txt && ./build/dtbToolCM -2 -o ./build/temp/arch/arm/boot/dt.img -s 4096 -p ./build/temp/scripts/dtc/ ./build/temp/arch/arm/boot/dts/
lz4 -9 ./build/temp/arch/arm/boot/dt.img
find  -iname '*.ko' -exec cp -rf '{}' ./build/bhbkernel/modules/ \;
${CROSS_COMPILE}strip --strip-unneeded ./build/bhbkernel/modules/*
mv ./build/bhbkernel/modules/wlan.ko ./build/bhbkernel/modules/qca_cld/qca_cld_wlan.ko
cp -rf ./build/temp/arch/arm/boot/zImage ./build/bhbkernel/zImage
cp -rf ./build/temp/arch/arm/boot/dt.img.lz4 ./build/bhbkernel/dtb
rm -rf ./build/bhbkernel/*.zip
cd ./build/bhbkernel/
zip -r9 BHB27-Kernel * -x README .gitignore modules/.gitignore ZipScriptSign/* ZipScriptSign/bin/* how_to_build_this.sh
mv BHB27-Kernel.zip ./ZipScriptSign
./ZipScriptSign/sign.sh test BHB27-Kernel.zip
rm -rf ./ZipScriptSign/BHB27-Kernel.zip
mv ./ZipScriptSign/BHB27-Kernel-signed.zip ./BHB27-Kernel-V129-7-M.zip
cd -
grep -B 3 -C 6 -r error: build/build_log.txt
grep -B 3 -C 6 -r warn build/build_log.txt


