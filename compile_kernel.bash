#!/usr/bin/env bash

# a script to compile and run linux kernel using qemu and gdb
# 
# author: hadi_sfr(info@hadisafari.ir)
# 
# Usage:
# Download .tar.gz kernel file from https://www.kernel.org/pub/linux/kernel/
# Put .tar.gz file besdie this script
# Run the script
# 
# Some sources:
# https://nostillsearching.wordpress.com/2012/09/22/compiling-linux-kernel-and-running-it-using-qemu/
# https://stackoverflow.com/a/33203642
# 
# This script is provided AS-IS WITHOUT WARRANTY OF ANY KIND. Use it at your own risk.
# I strongly suggest using script on a VirtualBox VM and backing up any sensitive data before usage.
# 

SRC="linux-3.19"
SIGN=">\t"

echo -e "extracting..."
tar -xzvf ${SRC}.tar.gz
cd ${SRC}

echo -e "${SIGN}compiling..."
make mrproper
make x86_64_defconfig
cat <<EOF >.config-fragment
CONFIG_DEBUG_INFO=y
CONFIG_DEBUG_KERNEL=y
CONFIG_GDB_SCRIPTS=y
EOF
./scripts/kconfig/merge_config.sh .config .config-fragment
time make -j"$(nproc)"

echo -e "${SIGN}preparing to run..."
cd arch/x86_64/boot/
mkinitramfs -o initrd.img
cd ../../../
mv arch/x86_64/boot/initrd.img initrd.img
qemu-img create disk_img.ext4 2G
mkfs -t ext4 disk_img.ext4 

echo -e "${SIGN}starting qemu..."
qemu-system-x86_64 -S -s \
    -kernel arch/x86_64/boot/bzImage \
    -initrd initrd.img \
    -hda disk_img.ext4 \
    -append "root=/dev/sda rw" &

echo -e "${SIGN}starting gdb..."
# The messy disconnect and what come after it are to work around the error:
# `Remote 'g' packet reply is too long`
# See: https://stackoverflow.com/a/33203642 for more details.
gdb \
    -ex "add-auto-load-safe-path $(pwd)" \
    -ex "file vmlinux" \
    -ex 'set arch i386:x86-64:intel' \
    -ex 'target remote localhost:1234' \
    -ex 'break start_kernel' \
    -ex 'continue' \
    -ex 'disconnect' \
    -ex 'set arch i386:x86-64' \
    -ex 'target remote localhost:1234'\
    -ex 'la src'
