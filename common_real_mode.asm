;
;Data 2017/12/1
;Authon linzhanglong
;brief 实模式下的一些公用函数
;
[bits 16]
;*****************************************************
;@ brief 打印字符串
;@ param bx要打印字符串的地址，字符串以0结尾
print_string:
    pusha
    mov ah, 0x0e
_NEXT_CHAR:
    lodsb
    cmp al ,0
    ;如果是0，表示字符串结尾了
    je _END
    ;显示一个字符
    int 0x10
    jmp _NEXT_CHAR
    
_END:
    ;回车
    mov al,  0x0a
    int 0x10
    mov al,  0x0d
    int 0x10

    popa
    ret

;**********************************************************
;@ brief 获取磁盘结构参数，包括有磁盘有多少个柱面，磁头，扇区 
;@ param void
;@ return   [DISK_HEADS] 磁头数目
;           [DISK_CYLINDER] 柱面数目
;           [DISK_SECTOR] 扇区数目
get_diskparam:
    pusha

    cmp word [DISK_SECTOR], 0
    jne _GET_PARAM_OK
    ;获取磁盘信息
    mov ah, 0x08
    mov dl, 0x80
    int 0x13
    jc _GET_PARAM_ERR

    inc dh
    mov [DISK_HEADS], dh

    ;cylinder := ( (CX and 0xFF00) shr 8 ) or ( (CX and 0xC0) shl 2)
    push cx
    mov ax, cx      ;Cylinders
    and ax, 0C0h
    shl ax, 2
    and cx, 0FF00h
    shr cx, 8
    or cx, ax
    mov ax, cx
    inc ax
    mov [DISK_CYLINDER], ax
    ;sector := CX and 63;
    pop cx
    and cx, 3Fh
    mov [DISK_SECTOR], cx

_GET_PARAM_OK:
    popa
    ret

_GET_PARAM_ERR:
    mov si, DISK_GETPARAM_ERR
    call print_string
    jmp $ ;卡主
    ret ;Never go there

DISK_GETPARAM_ERR db 'Disk Param Get Error', 0
;磁盘结构信息
DISK_HEADS db 0x00, 0x00 ;磁盘数目
DISK_CYLINDER db 0x00, 0x00 ;柱面数
DISK_SECTOR db 0x00, 0x00 ;每一个隧道的扇区数目

;**********************************************************
;@ brief 这里实现把磁盘的数据拷贝到内存 
;@ param ax 拷贝那个扇区的数据,LBA寻址
;@ param cl 拷贝多少个扇区数据
;@ return 如果成功，函数直接返回，数据存放到ES:BX的地址。
;         如果失败，打印一条错误日志，然后卡主
;@ notes 调用者需要先设置好数据的拷贝地址 ： ES:BX的地址
;
read_diskdata:
    pusha

    call get_diskparam

    mov [READ_SECTER_NR], cl

_LBA2CHS:
    xor     dx, dx
    div     word [DISK_SECTOR]
    inc     dl
    mov     cl, dl
    xor     dx, dx
    div     word [DISK_HEADS]
    mov     dh, dl
    mov     ch, al

    ;开始拷贝的扇区地址分为 (Head)8bit:(Cylinder)10bit:(Sector)6bit
    ;其中Head -> DH, Cylinder -> CH, Sector -> CL
    ;这里目前只支持拷贝drive0，也就是磁盘hda --> 0x80
    mov al, [READ_SECTER_NR]
    mov dl, 0x80
    ;开始拷贝磁盘数据
    mov ah, 0x02
    int 0x13
    ;开始判断磁盘拷贝结果，如果CF表示磁盘拷贝失败
    jc _READ_ERR
    ;判断拷贝的磁盘扇区数目是不是和我们要拷贝的一样，不是也报错
    mov dl, al ;保存实际的拷贝的扇区数目到dl
    mov al, [READ_SECTER_NR] ;我们想要拷贝的扇区数目al
    cmp dl, al
    jne _READ_ERR
    ;成功拷贝，打印一条日志，然后返回
    mov si, DISK_READ_OK
    call print_string

    popa
    ret
    
_READ_ERR:
    mov si, DISK_READ_ERR
    call print_string
    jmp $ ;卡主
    ret ;Never go there
    
;定义打印的字符串
DISK_READ_OK db 'Disk Read Ok', 0
DISK_READ_ERR db 'Disk Read Error', 0
;拷贝的扇区数目我们需要保存起来
READ_SECTER_NR equ 0x00