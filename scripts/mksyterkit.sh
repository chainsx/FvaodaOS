#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0
#
# This file is a part of the Avaota Build Framework
# https://github.com/AvaotaSBC/AvaotaOS/

__usage="
Usage: mksyterkit [OPTIONS]
Build SyterKit bin.
The target bootloader.bin will be generated in the build folder of the directory where the mksyterkit.sh script is located.

Options: 
  -b, --board BOARD                   The target board.
  -h, --help                          Show command help.
"

help()
{
    echo "$__usage"
    exit $1
}

default_param() {
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
        else
            echo `date` - ERROR, UNKNOWN params "$@"
            return 2
        fi
    done
}

workspace=$(pwd)
cd ${workspace}

default_param
parseargs "$@" || help $?

source ../boot/SyterKit/SyterKit.conf
source ../boards/${BOARD}.conf
if [ -f ${workspace}/bootloader.bin ];then rm ${workspace}/bootloader.bin; fi
if [ -f ${workspace}/bl31.bin ];then rm ${workspace}/bl31.bin; fi
if [ -f ${workspace}/scp.bin ];then rm ${workspace}/scp.bin; fi
if [ -f ${workspace}/splash.bin ];then rm ${workspace}/splash.bin; fi
if [ -f ${workspace}/exlinux.conf ];then rm ${workspace}/exlinux.conf; fi
cd SyterKit && mkdir build-${BOARD} && cd build-${BOARD}
cmake -DCMAKE_BOARD_FILE=${BOARD}.cmake -DCMAKE_BUILD_TYPE=Debug ..
make -j$(nproc)
cp ${workspace}/../boot/SyterKit/extlinux.conf ${workspace}
sed -i "s|BOARD_NAME|${DEVICE_DTS}|g" ${workspace}/extlinux.conf
cp board/${BOARD}/${SYTERKIT_TYPE}/${SYTERKIT_TYPE}_bin_card.bin ${workspace}/bootloader.bin
cp ../board/${BOARD}/${SYTERKIT_TYPE}/bl31/bl31.bin ${workspace}/bl31.bin
cp ../board/${BOARD}/${SYTERKIT_TYPE}/scp/scp.bin ${workspace}/scp.bin
cp ../board/${BOARD}/${SYTERKIT_TYPE}/splash/splash.bin ${workspace}/splash.bin
