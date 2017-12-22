;
; Date 2017/11/28
; Authon: linzhanglong
; notes: 这里是加载内核。
[org 0x9000]
	;这个文件主要功能就是加载内核，需要分为几个主要步骤:
	;step 1 初始化GDT表
	;step 2 开始A20
	;step 3 进入保护模式
	;step 4 加载bzImage的启动扇区和setup到0x9000内存地址
	;step 5 加载vmlinux到0x100000内存地址
	;step 6 设置内核参数
	;step 7 启动内核
	cli
	call init_gdt ;step 1 初始化GDT表
	call EnableA20_KB ;step 2 启用A20

;step 3 进入保护模式
enter_protect:
	mov eax, cr0
	or eax, 0x1
	mov cr0, eax
	jmp GDT_SYSTEMCOLD_OFFSET:init_protect

[bits 32]
	;开始进入保护模式了
init_protect:
	;现在设置我们的数据段使用GDT_SYSTEMDATA_OFFSET描述符
	mov ax, GDT_SYSTEMDATA_OFFSET
	mov ds, ax
	mov ss, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	;设置堆栈s
	mov ebp, PROTECT_STACK_MEMBASE
	mov esp, ebp
	mov esi, MSG_ENTER_PROTECT_OK
	call print_string_protect

;step 4 加载bzImage的启动扇区和setup到0x10000内存地址
	mov eax, BZIMAGE_DISKBASE
	mov edi, BZIMAGE_BOOTSECTOR_MEMBASE
	call read_disk_onesector_pm

	;setup 扇区数目，1个字节
	mov eax, BZIMAGE_BOOTSECTOR_MEMBASE
	add eax, SETUP_SECTS
	mov ebx, [eax]
	mov byte [BZIMAGE_SETUP_SECTS], bl

	;kernel的大小，16字节为单位
	mov eax, BZIMAGE_BOOTSECTOR_MEMBASE
	add eax, SYSSIZE
	mov ebx, [eax]
	shl ebx, 4 ;乘以16
	;如果字节数目不是512字节对齐的话，需要多拷贝一个扇区
	add ebx, 511
	shr ebx, 9 ;转为扇区单位
	mov [BZIMAGE_SYSSIZE_SECTS], ebx

	;加载setup到紧接着boot sector的内存地址
	mov cl, [BZIMAGE_SETUP_SECTS]
	mov eax, BZIMAGE_DISKBASE
	add eax, 1

	mov edi, BZIMAGE_BOOTSECTOR_MEMBASE
	add edi, 512
_LOAD_SETUP_NEXT:
	call read_disk_onesector_pm
	;准备读取下一个扇区
	add edi, 512
	add eax, 1 
	dec cl
	jnz _LOAD_SETUP_NEXT

	;加载bzImage的vmlinux.bin到0x100000内存位置
	mov edi, VMLINUX_BIN_BASENAME
	;磁盘位置
	mov eax, BZIMAGE_DISKBASE
	add eax, 1
	xor ecx, ecx
	mov cl, [BZIMAGE_SETUP_SECTS]
	add eax, ecx
	;拷贝的扇区数目
	mov ecx, [BZIMAGE_SYSSIZE_SECTS]
_LOAD_VMLINUX_NEXT:
	call read_disk_onesector_pm
	;准备读取下一个扇区
	add edi, 512
	add eax, 1
	dec ecx
	jnz _LOAD_VMLINUX_NEXT

	;debug
	;mov eax, 0x100000
	;add eax, 0x595100
	;mov ebx, [eax]
	;call print_hex_pm
	;jmp $
	;end debug
_SETUP_PARAM:
	;设置bootloader类型
	mov eax, BZIMAGE_BOOTSECTOR_MEMBASE
	add eax, TYPE_OF_LOADER
	mov ebx, [eax]
	or ebx, 0xff;Boot loader identifier,我们是自己的bootloader，所以设置为0xff
	mov [eax], ebx

	;设置setup代码执行完之后调转到内核的地址，这里就是 0x100000
	;bzImage的vmlinux.bin代码的加载内存地址
	;mov eax, BZIMAGE_BOOTSECTOR_MEMBASE
	;add eax, CODE32_START
	;mov ebx, VMLINUX_BIN_BASENAME
	;mov [eax], ebx

	;启用CAN_USE_HEAP
	mov eax, BZIMAGE_BOOTSECTOR_MEMBASE
	add eax, LOADFLAGS
	mov ebx, [eax]
	or ebx, 0x80
	mov [eax], ebx


	;0x0000-0x7fff	Real mode kernel
	;0x8000-0xdfff	Stack and heap, heap_end = 0xe000 => heap_end_ptr = heap_end - 0x200;
	;0xe000-0xffff	Kernel command line
	;stack/heap 设置
	mov eax, BZIMAGE_BOOTSECTOR_MEMBASE
	add eax, HEAP_END_PTR
	mov ebx, [eax]
	and ebx, 0xffff0000
	or ebx, 0xde00
	mov [eax], ebx
	;设置命令行
	mov eax, BZIMAGE_BOOTSECTOR_MEMBASE
	add eax, CMD_LINE_PTR
	mov ebx, 0xe000
	mov [eax], ebx

    mov ebx, 0xe000
    mov edx, cmd_line
_SET_CMDLINE:
    mov al, [edx]
    cmp al, 0x00
    jz RUN_KERNEL
    mov byte [ebx], al
    inc ebx
    inc edx
    jmp _SET_CMDLINE

RUN_KERNEL:
	;开始启动内核
	;由于setup代码是在实模式下运行，我们需要退回实模式
	;http://www.mouseos.com/arch/backto_real_mode.html
	;切换回 real mode 的 segment
	mov ax, GDT_USERDATA_OFFSET
	mov ds, ax
	mov es, ax
	mov ss, ax
	;更新 CS 寄存器
	jmp GDT_USERCOLD_OFFSET:_ENTER_REAL_MODE
[bits 16]
_ENTER_REAL_MODE:
	; 加载 real mode 下的 IDT 表
    LIDT [IDT_POINTER16]
	; 关闭 protected mode 和 paging 机制
	mov eax, cr0
	btr eax, 31              ; clear CR0.PG
	btr eax, 0               ; clear CR0.PE
	mov cr0, eax             ; disable protected mode
	;设置最终的 real mode 段
	jmp 0:_INIT_REAL_MODE
_INIT_REAL_MODE:
	;BZIMAGE_BOOTSECTOR_MEMBASE + 0x200
	mov ax, BZIMAGE_BOOTSECTOR_MEMBASE_SEG
	mov es, ax
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov bp, STAGE1_STACK_MEMBASE ;使用stage1的堆栈就好了
	mov sp, bp
	jmp BZIMAGE_BOOTSECTOR_MEMBASE_SEG:512

	;现在我们进入保护模式
	;call enter_protect
%include "common.asm"
%include "common_protect_mode.asm"
%include "common_real_mode.asm"

IDT_POINTER16:
IDT_LIMIT16     dw      0xffff
IDT_BASE16      dd      0

MSG_ENTER_PROTECT_OK db 'Enter protect mode ok', 0
MSG_ENTER_REAL_MODE_OK db 'Enter real mode ok', 0

BZIMAGE_SETUP_SECTS db 0x00 ;setup的大小
BZIMAGE_SYSSIZE_SECTS db 0x00,0x00,0x00,0x00 ;The size of the 32-bit code in 16-byte paras

times 32766-($-$$) db 1
dw 0x4433