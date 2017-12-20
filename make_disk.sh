# !/bin/bash
rm -rf stage1 stage2 disk.raw

#dd if=/dev/zero of=./sda bs=1M count=100

nasm stage1.asm -o stage1
if [[ $? != 0 ]];then
    exit 1
fi

#写入MBR
if [ ! -f "./stage1" ];then
	echo "./stage1 not exit"
    exit 1
fi

dd if=./stage1 of=./disk.raw bs=512 count=1 conv=notrunc
if [[ $? != 0 ]];then
    exit 1
fi

#写入stage2
nasm stage2.asm -o stage2
if [ ! -f "./stage2" ];then
	echo "./stage2 not exit"
    exit 1
fi
dd if=./stage2 of=./disk.raw bs=1M seek=1 conv=notrunc
if [[ $? != 0 ]];then
    exit 1
fi

#写入内核
if [ ! -f "./bzImage" ];then
	echo "./bzImage not exit"
    exit 1
fi
dd if="./bzImage" of=./disk.raw bs=1M seek=2 conv=notrunc
if [[ $? != 0 ]];then
    exit 1
fi
#启动qemu
qemu-kvm disk.raw -vnc :6

exit 0