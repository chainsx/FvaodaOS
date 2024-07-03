#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0
#
# This file is a part of the Avaota Build Framework
# https://github.com/AvaotaSBC/AvaotaOS/

__usage="
Usage: pack [OPTIONS]
Pack bootable image.
The target sdcard.img will be generated in the build folder of the directory where the mklinux.sh script is located.

Options: 
  -b,  -board BOARD                   The target board.
  -t, --type ROOTFS_TYPE              The rootfs type.
  -h, --help                          Show command help.
"

help()
{
    echo "$__usage"
    exit $1
}

default_param() {
    TYPE=cli
    VERSION=jammy
    BOARD=avaota-a1
}

parseargs()
{
    if [ "x$#" == "x0" ]; then
        return 0
    fi

    while [ "x$#" != "x0" ];
    do
        if [ "x$1" == "x-h" -o "x$1" == "x--help" ]; then
            return 1
        elif [ "x$1" == "x" ]; then
            shift
        elif [ "x$1" == "x-b" -o "x$1" == "x--board" ]; then
            BOARD=`echo $2`
            shift
            shift
        elif [ "x$1" == "x-t" -o "x$1" == "x--type" ]; then
            TYPE=`echo $2`
            shift
            shift
        elif [ "x$1" == "x-v" -o "x$1" == "x--version" ]; then
            VERSION=`echo $2`
            shift
            shift
        else
            echo `date` - ERROR, UNKNOWN params "$@"
            return 2
        fi
    done
}

UMOUNT_ALL(){
    set +e
    if [ -d ${workspace}/rootfs_dir ]; then
        if grep -q "${workspace}/rootfs_dir " /proc/mounts ; then
            umount ${workspace}/rootfs_dir
        fi
    fi
    
    if [ -d ${workspace}/boot_dir ]; then
        if grep -q "${workspace}/boot_dir " /proc/mounts ; then
            umount ${workspace}/boot_dir
        fi
    fi
    
    if [ -d ${workspace}/rootfs_dir ]; then
        rm -rf ${workspace}/rootfs_dir
    fi
    
    if [ -d ${workspace}/boot_dir ]; then
        rm -rf ${workspace}/boot_dir
    fi
    
    set -e
}

LOSETUP_D_IMG(){
    set +e
    if [ -d ${root_mnt} ]; then
        if grep -q "${root_mnt} " /proc/mounts ; then
            umount ${root_mnt}
        fi
    fi
    if [ -d ${boot_mnt} ]; then
        if grep -q "${boot_mnt} " /proc/mounts ; then
            umount ${boot_mnt}
        fi
    fi
    if [ -d ${emmc_boot_mnt} ]; then
        if grep -q "${emmc_boot_mnt} " /proc/mounts ; then
            umount ${emmc_boot_mnt}
        fi
    fi
    if [ -d ${rootfs_dir} ]; then
        if grep -q "${rootfs_dir} " /proc/mounts ; then
            umount ${rootfs_dir}
        fi
    fi
    if [ -d ${boot_dir} ]; then
        if grep -q "${boot_dir} " /proc/mounts ; then
            umount ${boot_dir}
        fi
    fi
    if [ "x$device" != "x" ]; then
        kpartx -d ${device}
        losetup -d ${device}
        device=""
    fi
    if [ -d ${root_mnt} ]; then
        rm -rf ${root_mnt}
    fi
    if [ -d ${boot_mnt} ]; then
        rm -rf ${boot_mnt}
    fi
    if [ -d ${emmc_boot_mnt} ]; then
        rm -rf ${emmc_boot_mnt}
    fi
    if [ -d ${rootfs_dir} ]; then
        rm -rf ${rootfs_dir}
    fi
    if [ -d ${boot_dir} ]; then
        rm -rf ${boot_dir}
    fi
    set -e
}

gen_preimage()
{
    device=""
    LOSETUP_D_IMG
    size=`du -sh --block-size=1MiB ${workspace}/rootfs.img | cut -f 1 | xargs`
    size=$(($size+1100))
    losetup -D
    
    dd if=/dev/zero of=${img_file} bs=1MiB count=$size status=progress && sync

    parted ${img_file} mklabel ${IMG_PARTITION} mkpart primary fat32 32768s 524287s
    parted ${img_file} -s set 1 boot on
    parted ${img_file} mkpart primary ext4 524288s 100%
}

pack_boot()
{
    cd ${workspace}
    if [ -f ${workspace}/boot.vfat ];then rm ${workspace}/boot.vfat; fi
    if [ -d ${workspace}/boot_dir ];then rm -rf ${workspace}/boot_dir; fi
    
    dd if=/dev/zero of=${workspace}/boot.vfat bs=1MiB count=128 status=progress && sync
    mkfs.vfat -n boot -F 32 ${workspace}/boot.vfat
    
    trap 'UMOUNT_ALL' EXIT
    
    mkdir ${workspace}/boot_dir
    mount ${workspace}/boot.vfat ${workspace}/boot_dir
    
    mv ${workspace}/ubuntu-${VERSION}-${TYPE}/boot/* ${workspace}/boot_dir
    
    cp -r ${workspace}/bootloader-${BOARD}/* ${workspace}/boot_dir
    
    UMOUNT_ALL
}

pack_rootfs()
{
    cd ${workspace}
    if [ -f ${workspace}/rootfs.ext4 ];then rm ${workspace}/rootfs.ext4; fi
    if [ -d ${workspace}/rootfs_dir ];then rm -rf ${workspace}/rootfs_dir; fi
    
    rootfs_size=`du -sh --block-size=1MiB ${workspace}/ubuntu-${VERSION}-${TYPE} | cut -f 1 | xargs`

    size=$(($rootfs_size+880))
    dd if=/dev/zero of=${workspace}/rootfs.ext4 bs=1MiB count=$size status=progress && sync
    
    mkfs.ext4 -L rootfs ${workspace}/rootfs.ext4
    
    trap 'UMOUNT_ALL' EXIT
    
    mkdir ${workspace}/rootfs_dir
    mount ${workspace}/rootfs.ext4 ${workspace}/rootfs_dir
    rsync -avHAXq ${workspace}/ubuntu-${VERSION}-${TYPE}/* ${workspace}/rootfs_dir
    
    rm ${workspace}/rootfs_dir/THIS-IS-NOT-YOUR-ROOT
    rm -f ${workspace}/rootfs_dir/root/.bash_history
    sed -i "s|avaota-sbc|${BOARD_NAME}|g" ${workspace}/rootfs_dir/etc/hosts
    sed -i "s|avaota-sbc|${BOARD_NAME}|g" ${workspace}/rootfs_dir/etc/hostname
    
    cp -rfp ${workspace}/../target/firmware ${workspace}/rootfs_dir/lib/
    
    sync
    sync
    sleep 10
    
    UMOUNT_ALL
}

pack_sdcard()
{
    cd ${workspace}
    if [ -f ${workspace}/sdcard.img ];then rm -rf ${workspace}/sdcard.img; fi
    
    device=`losetup -f --show -P ${img_file}`
    trap 'LOSETUP_D_IMG' EXIT
    kpartx -va ${device}
    loopX=${device##*\/}
    partprobe ${device}

    bootp=/dev/mapper/${loopX}p1
    rootp=/dev/mapper/${loopX}p2
    
    mkfs.vfat -n boot ${bootp}
    mkfs.ext4 -L rootfs ${rootp}
    mkdir -p ${root_mnt} ${boot_mnt}
    mount -t vfat -o uid=root,gid=root,umask=0000 ${bootp} ${boot_mnt}
    mount -t ext4 ${rootp} ${root_mnt}
}

xz_image()
{
    cd ${workspace}
    if [ -f sdcard.img ];then
        pixz sdcard.img
        echo "xz success."
    else
        echo "sdcard.img not found, xz sdcard image failed!"
        exit 2
    fi
}

workspace=$(pwd)
cd ${workspace}

default_param
parseargs "$@" || help $?

source ../boards/${BOARD}.conf
source ../scripts/lib/bootloader/bootloader-${BL_CONFIG}.sh

img_file=${workspace}/sdcard.img

gen_preimage
pack_boot
pack_rootfs
pack_sdcard
xz_image
