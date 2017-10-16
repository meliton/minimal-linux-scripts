#!/bin/sh
# set options: e- exit immediately if a command exits with a non-zero status
#              x- print commands and their arguments as they are executed 
set -ex

# Variables for files and start location
KERNEL_VERSION=2.6.39.4
BUSYBOX_VERSION=1.27.2
SYSLINUX_VERSION=6.03
SRC_DIR=$(pwd)

# Clean old isoimage folder and go into sources folder
rm -rf isoimage
mkdir -p sources
cd $SRC_DIR/sources

# Remove old folders... linux, busybox and syslinux
rm -rf linux-$KERNEL_VERSION
rm -rf busybox-$BUSYBOX_VERSION
rm -rf syslinux-$SYSLINUX_VERSION

# Get source files
wget -c -O linux-$KERNEL_VERSION.tar.xz http://kernel.org/pub/linux/kernel/v2.6/linux-$KERNEL_VERSION.tar.xz
wget -c -O busybox-$BUSYBOX_VERSION.tar.bz2 http://busybox.net/downloads/busybox-$BUSYBOX_VERSION.tar.bz2
wget -c -O syslinux-$SYSLINUX_VERSION.tar.xz http://kernel.org/pub/linux/utils/boot/syslinux/syslinux-$SYSLINUX_VERSION.tar.xz

# Extract source files, non-verbosely
echo "Extracting kernel... please wait..."
tar -xf linux-$KERNEL_VERSION.tar.xz
echo "Extracting busybox... please wait..."
tar -xf busybox-$BUSYBOX_VERSION.tar.bz2
echo "Extracting syslinux... please wait..."
tar -xf syslinux-$SYSLINUX_VERSION.tar.xz

cd $SRC_DIR
mkdir -p isoimage
cd $SRC_DIR/sources/busybox-$BUSYBOX_VERSION

# Configures a full-featured BusyBox w/o debugging
make distclean defconfig

# Configures for a static linked Busybox binary 
sed -i "s/.*CONFIG_STATIC.*/CONFIG_STATIC=y/" .config

# Checks for prebuilt busybox.config file and uses it if it exists
echo "Check if file exists"
if [ -e "$SRC_DIR/minimal_config/busybox.config" ]
then
   echo "File found! Copying config over..."
   cp $SRC_DIR/minimal_config/busybox.config ./.config
else
   echo "File Not found! Using default config..."
fi

# Builds busybox
make busybox install

# Remove the linuxrc shell script file... not needed
cd _install
rm -f linuxrc

# Build basic init file and compress the root filesystem
mkdir dev proc sys
echo '#!/bin/sh' > init
echo 'dmesg -n 1' >> init
echo 'mount -t devtmpfs none /dev' >> init
echo 'mount -t proc none /proc' >> init
echo 'mount -t sysfs none /sys' >> init
echo 'setsid cttyhack /bin/sh' >> init
chmod +x init
find . | cpio -R root:root -H newc -o | gzip > $SRC_DIR/isoimage/rootfs.gz

# Configures a default kernel configuration
cd $SRC_DIR/sources/linux-$KERNEL_VERSION
make mrproper defconfig 

# Enable CONFIG_DEVTMPFS and CONFIG_DEVTMPFS_MOUNT
sed -i "s/.*CONFIG_DEVTMPFS.*/CONFIG_DEVTMPFS=y\nCONFIG_DEVTMPFS_MOUNT=y/" .config

# Checks for prebuilt kernel.config file and uses it if it exists
echo "Check if file exists"
if [ -e "$SRC_DIR/minimal_config/kernel.config" ]
then
   echo "File found! Copying config over..."
   cp $SRC_DIR/minimal_config/kernel.config ./.config
else
   echo "File Not found! Using default config..."
fi

make bzImage
cp arch/x86/boot/bzImage $SRC_DIR/isoimage/kernel.gz
cd $SRC_DIR/isoimage

# Make syslinux folder to drop in files
mkdir -p syslinux
cp $SRC_DIR/sources/syslinux-$SYSLINUX_VERSION/bios/core/isolinux.bin ./syslinux
cp $SRC_DIR/sources/syslinux-$SYSLINUX_VERSION/bios/com32/elflink/ldlinux/ldlinux.c32 ./syslinux
echo 'default /kernel.gz initrd=/rootfs.gz' > ./syslinux/isolinux.cfg

# Make the ISO
genisoimage \
    -J \
    -r \
    -o ../minimal_linux_live.iso \
    -b syslinux/isolinux.bin \
    -c boot.cat \
    -input-charset UTF-8 \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -joliet-long \
    ./
cd $SRC_DIR
set +ex

