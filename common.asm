;
; brief:  这个文件只是定义MBR,stage2,bzImage的内存分布和磁盘位置
; Author: linzhanglong
; Date 2017/12/13

;***********************stage1 阶段设置******************
;STAGE1磁盘位置是固定的，就是磁盘的第一个扇区
;STAGE1数据在内存的位置也是固定的，就是[0x7c00,0x7e00],共512字节
;STAGE1的堆栈设置，这里设置为 0x8000
STAGE1_STACK_MEMBASE equ 0x8000

;***********************stage2 阶段设置******************
;STAGE2磁盘位置是固定的，就是磁盘的第二个扇区开始
;STAGE2的长度，这里定义为16k，这算为扇区数目为32个扇区
;STAGE2数据在内存的位置是 0x9000到0xd000
;STAGE2的堆栈设置，这里设置为 0x8000
;STAGE2位于第几号扇区，从0开始计算
STAGE2_STACK_MEMBASE equ 0x8000
STAGE2_LOAD_MEMBASE  equ 0x9000
STAGE2_SIZE equ 0x20
STAGE2_DISKBASE equ 0x800

;********************保护模式下设置******************
PROTECT_STACK_MEMBASE equ 0x90000

;********************bzImage 加载阶段设置***************
;bzImage位于磁盘的开始位置,2M的位置，折算为扇区 4096
BZIMAGE_DISKBASE equ  0x1000
;bzImage的bootsector加载的内存地址是0x10000，对应的段地址是0x1000
BZIMAGE_BOOTSECTOR_MEMBASE equ 0x90000
BZIMAGE_BOOTSECTOR_MEMBASE_SEG equ 0x9000 ;Segment

;https://www.kernel.org/doc/Documentation/x86/boot.txt
;bzImage的bootsector结尾包含有内核的头部信息结构体 
SETUP_SECTS equ 0x01f1 ;The size of the setup in sectors
SYSSIZE equ 0x01f4 ;The size of the 32-bit code in 16-byte paras
;bzImage的setup开头包含有内核的头部信息结构体
TYPE_OF_LOADER equ 0x0210  ;Boot loader identifier,我们是自己的bootloader，所以设置为0xff
LOADFLAGS equ 0x0211   ;Boot protocol option flags，主要使能使用我们设置的堆栈
HEAP_END_PTR equ 0x0224; Free memory after setup end，设置setup代码执行的堆栈
CMD_LINE_PTR equ 0x0228 ;32-bit pointer to the kernel command line

;bzImage的vmlinux.bin代码的加载内存地址
VMLINUX_BIN_BASENAME equ 0x100000

;命令行设置
cmd_line    db  'root=/dev/sda2', 0
cmd_length  equ $ - cmd_line

