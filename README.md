# mini_bootloader
自己实现了一个小型的bootloader，用于引导linux内核

step 1 配置和编译内核

下载一个linux内核，配置 linux内核，添加以下信息：initram文件系统（用于引导真正的文件系统）,PIIX控制器（qemu模拟的IDE控制器）驱动，ATA磁盘驱动，还有ext3文件系统驱动。

    General setup  --->
    
           [*] Initial RAM filesystem and RAM disk (initramfs/initrd) support
           
           ( /usr/src/initramfs) Initramfs source file(s)
           
    Device Drivers  --->
    
    <*> ATA/ATAPI/MFM/RLL support (DEPRECATED)  --->
    
        <*>   generic ATA/ATAPI disk support
        
        [*]     ATA disk support
        
        <*>   Intel PIIX/ICH chipsets support
        
    File systems  --->
    
        <*> Ext3 journalling file system suppor
        
        [*]   Default to 'data=ordered' in ext3
        
        [*]   Ext3 extended attributes

然后就是解压我们的内存文件系统到/usr/src/目录：

#tar xvf initramfs.tar.gz2 -C /usr/src/

最后编译内核得到bzImage文件



step 2 解压磁盘文件系统

tar xvf rootfs.tar.gz2 -C /home/


step 3 最后编译我们bootloader，还有烧写程序，得到一个可以引导系统的磁盘

把bzImage放到mini_bootloader目录下，执行 bah -x make_disk.sh，得到磁盘disk.qcow2

这样我们就可以通过 qemu-kvm  -hda disk.qcow2 -nographic  -m 512,启动我们的系统了。
最终的效果图：

/ # ls

bin         home        lost+found  root        tmp
dev         lib         mnt         sbin        usr
etc         linuxrc     proc        sys         var



说明：我们是通过nbd来写入qcow2磁盘数据，如果没有/dev/nbdx文件，那么需要安装nbd驱动。
      #insmod drivers/block/nbd.ko max_part=16

