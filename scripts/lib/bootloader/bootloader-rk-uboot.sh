#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0
#
# This file is a part of the Avaota Build Framework
# https://github.com/AvaotaSBC/AvaotaOS/

uboot_rkbin(){
case "$BOOT_SOC" in
	rk3399)
		DDR_BLOB="rk33/rk3399_ddr_933MHz_v1.25.bin"
		MINILOADER_BLOB="rk33/rk3399_loader_v1.30.130.bin"
		BL31_BLOB="rk33/rk3399_bl31_v1.35.elf"
		;;

	rk3528)
		DDR_BLOB="rk35/rk3528_ddr_1056MHz_v1.09.bin"
		BL31_BLOB="rk35/rk3528_bl31_v1.17.elf"
		;;

	rk3566)
		DDR_BLOB="rk35/rk3566_ddr_1056MHz_v1.21.bin"
		BL31_BLOB="rk35/rk3568_bl31_v1.44.elf"
		ROCKUSB_BLOB="rk35/rk356x_spl_loader_v1.21.113.bin"
		;;

	rk3568)
		DDR_BLOB="rk35/rk3568_ddr_1560MHz_v1.21.bin"
		BL31_BLOB="rk35/rk3568_bl31_v1.44.elf"
		ROCKUSB_BLOB="rk35/rk356x_spl_loader_v1.21.113.bin"
		;;

	rk3588)
		DDR_BLOB="rk35/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.16.bin"
		BL31_BLOB="rk35/rk3588_bl31_v1.45.elf"
		ROCKUSB_BLOB="rk35/rk3588_spl_loader_v1.16.113.bin"
		;;
esac
}

build_bootloader(){
    uboot_rkbin
    
    if [ -d u-boot ];then
        rm -rf u-boot
    fi
    git clone --depth=1 ${UBOOT_REPO} u-boot
    cd u-boot
    

    wget https://github.com/rockchip-linux/rkbin/raw/master/bin/${DDR_BLOB} -O ddr.bin
    wget https://github.com/rockchip-linux/rkbin/raw/master/bin/${BL31_BLOB} -O bl31.elf
    make ARCH=arm CROSS_COMPILE=${KERNEL_GCC} ${UBOOT_CONFIG} BL31=ddr.bin ROCKCHIP_TPL=bl31.elf
    make ARCH=arm CROSS_COMPILE=${KERNEL_GCC} BL31=ddr.bin ROCKCHIP_TPL=bl31.elf -j$(nproc)
    
    if [ -d ${workspace}/bootloader-${BOARD} ];then rm -rf ${workspace}/bootloader-${BOARD}; fi
    cp u-boot-rockchip-bin ${workspace}/bootloader-${BOARD}/bootloader.bin
    echo "${BOARD}" > ${workspace}/bootloader-${BOARD}/.done
}

apply_bootloader(){
    dd if= of=$1 seek=64 conv=notrunc status=none
}
