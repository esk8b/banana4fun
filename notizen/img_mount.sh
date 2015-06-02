#!/bin/sh                                          
# Author: Dubravko Penezic, dpenezic@gmail.com     
#                                                  
# Credit to valuable answer from few users on Raspberry Pi Forum , http://www.raspberrypi.org/forums/viewtopic.php?f=63&t=28860
#

OPTION=$1
IMG_FILE=$2
MOUNT_POINT=/datacopy/RPI-raspbian-image/Work/Img

IMG_DIR=$(basename "$IMG_FILE")
IMG_DIR="${IMG_DIR%.*}"

if [[ "$#" -lt 2 || ("$1" != "m" && "$1" != "u") ]]
  then
    echo "Please use script as follow:"
    echo ""
    echo '> $0 m|u <disk_img_file>'
    echo "     m - mount"
    echo "     u - umount"
    exit 1
fi

if [[ "$1" == "m" ]]
  then
    SECTOR_OFFSET=$(sudo /sbin/fdisk -lu $IMG_FILE | awk '$6 == "Linux" { print $2 }')
    BYTE_OFFSET=$(expr 512 \* $SECTOR_OFFSET)
    SECTOR_OFFSET_BOOT=$(sudo /sbin/fdisk -lu $IMG_FILE | awk '$6 == "W95" { print $2 }')
    BYTE_OFFSET_BOOT=$(expr 512 \* $SECTOR_OFFSET_BOOT)

    echo Mounting image / at $MOUNT_POINT/$IMG_DIR
    echo Sector offset $SECTOR_OFFSET - Byte offset $BYTE_OFFSET

    sudo mkdir -p $MOUNT_POINT/$IMG_DIR
    sudo mount -t ext4 -o loop,offset=$BYTE_OFFSET $IMG_FILE $MOUNT_POINT/$IMG_DIR

    echo Sector offset $SECTOR_OFFSET_BOOT - Byte offset $BYTE_OFFSET_BOOT
    echo Mounting image /boot at $MOUNT_POINT/${IMG_DIR}_boot

    sudo mkdir -p $MOUNT_POINT/${IMG_DIR}_boot
    sudo mount -t vfat -o loop,offset=$BYTE_OFFSET_BOOT $IMG_FILE $MOUNT_POINT/${IMG_DIR}_boot
fi

if [[ "$1" == "u" ]]
  then

    echo Unmounting image / at $MOUNT_POINT/$IMG_DIR
    sudo umount $MOUNT_POINT/$IMG_DIR
    sudo rmdir $MOUNT_POINT/$IMG_DIR

    echo Unmounting image /boot at $MOUNT_POINT/${IMG_DIR}_boot
    sudo umount $MOUNT_POINT/${IMG_DIR}_boot
    sudo rmdir $MOUNT_POINT/${IMG_DIR}_boot

fi