# !/bin/bash
rm -rf stage1 stage2 disk.qcow2

#新建一个20G的磁盘文件
qemu-img create -f qcow2 disk.qcow2 20G
if [[ $? != 0 ]];then
    exit 1
fi
qemu-nbd -c /dev/nbd0 disk.qcow2
if [[ $? != 0 ]];then
    exit 1
fi

#格式化磁盘，分为两个分区，第一个分区（从1M偏移开始到1G的位置），剩余的是第二个分区
fdisk /dev/nbd0 <<EOF
n
p
1
2048
+1G

n
p
2



w
EOF
if [[ $? != 0 ]];then
    qemu-nbd -d /dev/nbd0
    exit 1
fi

#写入stage1到磁盘的MBR区
nasm stage1.asm -o stage1
if [[ $? != 0 ]];then
    qemu-nbd -d /dev/nbd0
    exit 1
fi
dd if=./stage1 of=/dev/nbd0 bs=446 count=1 conv=notrunc
if [[ $? != 0 ]];then
    qemu-nbd -d /dev/nbd0
    exit 1
fi

#写入stage2到第一个分区
nasm stage2.asm -o stage2
if [ ! -f "./stage2" ];then
	qemu-nbd -d /dev/nbd0
    exit 1
fi
dd if=./stage2 of=/dev/nbd0p1 conv=notrunc
if [[ $? != 0 ]];then
    qemu-nbd -d /dev/nbd0
    exit 1
fi

#写入内核到第一个分区，偏移第一个分区1M位置
dd if="./bzImage" of=/dev/nbd0p1 bs=1M seek=1 conv=notrunc
if [[ $? != 0 ]];then
    qemu-nbd -d /dev/nbd0
    exit 1
fi

#把磁盘文件系统/home/rootfs/写入到第二个分区去
mkfs.ext3 /dev/nbd0p2
mount /dev/nbd0p2 /media
if [[ $? != 0 ]];then
    qemu-nbd -d /dev/nbd0
    exit 1
fi
cp /home/rootfs/* /media -rdf
umount /media

qemu-nbd -d /dev/nbd0

#启动qemu，这里不通过vnc了，直接通过串口打印到当前终端
qemu-kvm  -hda disk.qcow2 -nographic  -m 512

exit 0
