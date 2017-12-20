;
;Data 2017/12/1
;Authon linzhanglong
;brief 初始化GDT表,启动A20地址线，进入保护模式

;***************初始化GDT表****************************
;第一条是空的描述符
[bits 16]
gdt_start:
	dd 0x0
	dd 0x0
;定义内核代码段访问权限
;Base_address-Base_address+4G代码段：权限只读，CPU处于ring0级别
gdt_system_cold:
	dw 0xffff ;Limit 
	dw 0x0 ;Base adderess[15:0]
	db 0x0 ;Base adderess[23:16]
	db 10011010b ;P:1->描述符在内存中;DPL:00->ring0,S:1->存储段[代码数据段] 1010->代码段，权限是：执行，可读
	db 11001111b ;G:1->Limit单位是4k，D/B:1->使用32位地址，未使用:00，Limit:1111
	db 0x0 ;Base address[31:24]:0

;定义内核数据段访问权限
;Base_address-Base_address+4G数据段：权限读写，CPU处于ring0级别
gdt_system_data:
	dw 0xffff ;Limit 
	dw 0x0 ;Base adderess[15:0]
	db 0x0 ;Base adderess[23:16]
	db 10010010b ;P:1->描述符在内存中;DPL:00->ring0,S:1->存储段[代码数据段] 010->数据段，权限是：读写
	db 11001111b ;Base address[31:24]:0, G:1->Limit单位是4k，D/B:1->使用32位地址，未使用:00，Limit:1111
	db 0x0 ;Base address[31:24]:0

;我们从保护模式切回实模式时候，需要对应修改一下段描述描述符
gdt_user_code:
	dw 0xffff
	dw 0x0
	db 0x0
	db 0x9a
	db 0x0 
	db 0x0
gdt_user_data:
	dw 0xffff
	dw 0x0
	db 0x0
	db 0x92
	db 0x0 
	db 0x0
gdt_end:

dgt_descriptors:
	dw gdt_end - gdt_start -1
	dd gdt_start

;进入保护模式之后，我们需要设置代码段将使用gdt_system_cold描述符，数据段将使用gdt_system_data描述符
GDT_SYSTEMCOLD_OFFSET  equ gdt_system_cold - gdt_start ;在描述符表的偏移位置
GDT_SYSTEMDATA_OFFSET  equ gdt_system_data - gdt_start ;在描述符表的偏移位置
GDT_USERCOLD_OFFSET equ gdt_user_code - gdt_start
GDT_USERDATA_OFFSET equ gdt_user_data - gdt_start

;向外提供的函数，初始化GDT描述符表
init_gdt:
	pusha	
	lgdt [dgt_descriptors]
	popa
	ret

;******************启用A20*************
;摘自 http://mrhopehub.github.io/2014/12/26/enabling-the-A20-Gate.html
EnableA20_KB:
	push    ax         ;Saves AX
	mov al, 0xdd  ;Look at the command list 
	out 0x64, al   ;Command Register 
	pop ax          ;Restore's AX
	ret

;***************保护模式下的打印，不能通过BIOS，但是可以通过显卡映射的内存来操作*****
VIDEO_MEMERY_START equ 0xb8000

;@ brief  保护模式下的打印字符串
;@ param ebx 字符串的地址
[bits 32]
print_string_protect:
    pusha
    ;先读取当前光标位置
    ;光标位置高8位
	xor eax, eax
    mov dx, 3D4H
	mov al, 0xE
	out dx, al ;设置索引：读取高8位
	mov dx, 3D5H
	in al, dx  ;从VGA寄存器读取数据
	mov ah, al
	;光标位置低8位
	mov al, 0xF
	mov dx, 3D4H
	out dx, al ;设置索引：读取低8位
	mov dx, 3D5H
	in al, dx ;从VGA寄存器读取数据

	;设置光标对应的显卡内存位置，两个字节对应一个字符
    mov edx, VIDEO_MEMERY_START
    add edx, eax
    add edx, eax

    ;保存光标的位置
    mov ecx, eax
print_next_protect:
    lodsb ;显示的字符
    ;判断是否为结束符
    cmp al ,0
    je print_ok_protect

    mov ah, 0x0f ;显示的字符颜色和背景设置
    mov [edx], ax

    add edx, 2
    inc ecx ;更新光标位置
    jmp print_next_protect
print_ok_protect: 
	;设置光标显示到下一行,每一行有80个字符
	;下一行的位置 = (当前的位置 + 79) / 80 * 80
	;ecx 保存要设置的坐标位置
	add ecx, 79
	mov eax, ecx
	mov ebx, 80
	xor edx,edx
	div ebx
	mul ebx
	mov ecx, eax

    mov dx, 3D4H
	mov al, 0xE
	out dx, al ;设置索引：读取高8位
	mov dx, 3D5H
	mov al, ch
	out dx, al  ;从VGA寄存器写入数据
	;光标位置低8位
	mov al, 0xF
	mov dx, 3D4H
	out dx, al ;设置索引：读取低8位
	mov dx, 3D5H
	mov al, cl
	out dx, al ;从VGA寄存器读取数据	
    popa
    ret

;保护模式下打印ebx寄存器的数值
;这里把数值转为字符串，然后调用print_string_protect即可
[bits 32]
init_print_hex_pm:
    pusha
    mov ah, 0x0f    
    mov al, '0'
    mov [edx], ax   
    add edx, 1
    mov al, 'x'
    mov [edx], ax       
    popa
    add edx, 1
    ret

;@ brief 直接把bl转为字符对应的ASCII码，例如3->'3',10->'a'
convert_bx_hex2str_pm:
    ;如果数字大于15，异常。打印？号
    cmp bl, 15
    jg _ERROR_pm

    ;如果数字大于10，那么转为A-F
    cmp bl, 10
    jge _LETTER_pm

    ;如果数字是0-10，就只加上'0'，就可以把0-10转为对应数字的ascii码
    add bl, '0'
    jmp _EXIT_pm

_LETTER_pm:
    ;先把数字减去10，然后加上A，就可以把10-15的数字转为A-F
    sub bl, 10
    add bl, 'A'
    jmp _EXIT_pm
_ERROR_pm:
    mov bl, '?'
_EXIT_pm:
    ret

;@ brief 把一个数字转为多位十六进制输出
;@ param bx保存要打印的数字
print_hex_pm:
    pusha
    ;首先通过掩码和移位的方式，把数字以十六进制的方式从最后一位开始一个个压入堆栈
    ;然后输出时候才从堆栈里一个个取出来，这样就可以实现顺序打印
    xor cx, cx
_NEED_PUSH_pm:
    ;取掩码获取数字以十六进制形式的最后一位，例如数字0x1234取出4,其中4保存到al,0x123保存到bx。cl计数
    mov eax, ebx
    and eax, 0x0f
    shr ebx, 4
    ;入栈并且计数
    push ax
    inc cl
    ;如果bx数值为0，表示我们已经全部处理完
    cmp ebx, 0
    jne _NEED_PUSH_pm
    
    mov eax,CONVERT_HEX2str
    add eax, 2
    ;开始出栈，并且显示
_NEED_POP_pm:
    pop bx
    call convert_bx_hex2str_pm
    mov [eax], bx
    inc eax
    dec cl
    cmp cl, 0
    jne _NEED_POP_pm
    ;开始打印
    mov si, CONVERT_HEX2str
    call print_string_protect
    popa
    ret
;8个字节，还有一个结束符
CONVERT_HEX2str: db '0','x',0,0,0,0,0,0,0,0,0

;brief 保护模式下读取磁盘数据
;param eax LBA扇区号
;param edi 保存的内存地址
;notes http://www.cnblogs.com/weiweishuo/archive/2013/05/26/3100254.html
;      IDE的端口，写入的数据大小都是字节
[bits 32]
read_disk_onesector_pm:
	pusha
	;我们首先设置LBA扇区号
	;因为后面我们会用到eax
	mov edx, 0x1f3
	out dx, al ;LBA[7:0]

	mov edx, 0x1f4
	shr eax, 8
	out dx, al ;LBA[15:8]

	mov edx, 0x1f5
	shr eax, 8
	out dx, al ;LBA[23:16]

	mov edx, 0x1f6
	shr eax, 8
	and al, 0x0f ;LBA[27:24]
	or al, 0xe0 ;LBA模式
	out dx, al ;LBA[23:16]

	;设置扇区数目,这个设置读取1扇区
	mov dx, 0x1f2
	mov al, 1
	out dx, al
	;设置读指令
	mov dx, 0x1f7
	mov al, 0x20
	out dx, al
_not_ready:
;一次只能读取512字节
	mov ecx, 256
	in al, dx
	and al, 0x88
	cmp al, 0x08
	jnz _not_ready
	;开始读取数据	
	mov dx, 0x1f0
	rep insw
	popa
	ret  