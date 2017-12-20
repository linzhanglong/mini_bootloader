;
; Date 2017/11/28
; Authon: linzhanglong
; notes: 这里是MBR分区，用途：用于加载stage2代码到指定内存位置，然后执行
; https://www.kernel.org/doc/Documentation/x86/boot.txt
[org 0x7c00]

	; step 1 先初始化号堆栈，免得出异常[xxxxx, 0x8000]
	mov bp, STAGE1_STACK_MEMBASE
	mov sp, bp

	; step 2 先初始化stage2内存拷贝地址[0x9000, 0x9000 + 64k]
	mov ax, STAGE2_LOAD_MEMBASE
	shr ax, 4
	mov es, ax
	mov bx, STAGE2_LOAD_MEMBASE
	and bx, 0xf ;es:bx = STAGE2_LOAD_MEMBASE

	; step 3 从磁盘位置[0x200, 0x200 + 64k]拷贝stage2代码到内存
	mov ax, STAGE2_DISKBASE
    mov cx, STAGE2_SIZE
	call read_diskdata

	mov si, MSG_LOAD_STAGE2_OK
	call print_string

	jmp STAGE2_LOAD_MEMBASE   ;跳到stage2代码执行

%include "common_real_mode.asm"
%include "common.asm"

MSG_LOAD_STAGE2_OK db  'Load stage2 Ok', 0

times 510-($-$$) db 0
dw 0xaa55