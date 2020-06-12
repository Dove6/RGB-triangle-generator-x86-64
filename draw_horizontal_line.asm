section .text
    global draw_horizontal_line

draw_horizontal_line:
    ; function arguments
    ;  [rdi] BYTE *image_data
    ;  [rsi] struct BITMAPINFOHEADER *info_header
    ;  [rdx] DWORD line_y
    ;  [xmm0] double left_x
    ;  [xmm1] double left_r
    ;  [xmm2] double left_g
    ;  [xmm3] double left_b
    ;  [xmm4] double right_x
    ;  [xmm5] double right_r
    ;  [xmm6] double right_g
    ;  [xmm7] double right_b

    sub rsp, 8

    ; move left_x and right_x to general purpose registers
    mov r11, rdx  ; line_y
    cvtpd2dq xmm8, xmm0
    movd ecx, xmm8
    cvtpd2dq xmm8, xmm4
    movd edx, xmm8

    ; prepare vector registers for looping
    unpcklpd xmm0, xmm1
    unpcklpd xmm2, xmm3
    unpcklpd xmm4, xmm5 ; punpcklqdq for integers
    unpcklpd xmm6, xmm7
    movapd xmm1, xmm2
    movapd xmm2, xmm4
    movapd xmm3, xmm6
    movapd xmm4, xmm0
    movapd xmm5, xmm1
    ; vector registers layout
    ;  [xmm0] left_r, left_x
    ;  [xmm1] left_b, left_g
    ;  [xmm2] right_r, right_x
    ;  [xmm3] right_b, right_g
    ;  [xmm4] left_r, left_x
    ;  [xmm5] left_b, left_g
    subpd xmm4, xmm2
    subpd xmm5, xmm3
    ;  [xmm4] left_r - right_r, left_x - right_x
    ;  [xmm5] left_b - right_b, left_g - right_g
    movsd xmm6, xmm0
    cmpeqpd xmm6, xmm2
    pmovsxdq xmm6, xmm6
    pcmpeqd xmm7, xmm7
    pxor xmm7, xmm6
    ;  [xmm6] left_x == right_x, left_x == right_x
    ;  [xmm7] left_x != right_x, left_x != right_x
    movsd xmm2, xmm4
    unpcklpd xmm2, xmm4
    movdqa xmm3, xmm6
    ;  [xmm2] left_x - right_x, left_x - right_x
    ;  [xmm3] left_x == right_x, left_x == right_x
    pand xmm4, xmm7
    pand xmm5, xmm7
    cvtdq2pd xmm3, xmm3
    addpd xmm2, xmm3
    ; if left_x == right_x
    ;  [xmm2] -1.0, -1.0
    ;  [xmm3] -1.0, -1.0
    ;  [xmm4] 0.0, 0.0
    ;  [xmm5] 0.0, 0.0
    ; else (left_x != right_x)
    ;  [xmm2] left_x - right_x, left_x - right_x
    ;  [xmm3] 0.0, 0.0
    ;  [xmm4] left_r - right_r, left_x - right_x
    ;  [xmm5] left_b - right_b, left_g - right_g
    divpd xmm4, xmm2
    divpd xmm5, xmm2
    ; if left_x == right_x
    ;  [xmm4] 0.0, 0.0
    ;  [xmm5] 0.0, 0.0
    ; else (left_x != right_x)
    ;  [xmm4] step_r, step_x
    ;  [xmm5] step_b, step_g
    movapd xmm2, xmm0
    movapd xmm3, xmm1
    ; final pre-loop vector registers layout
    ;  [xmm0] left_r, left_x
    ;  [xmm1] left_b, left_g
    ;  [xmm2] current_r, current_x
    ;  [xmm3] current_b, current_g
    ;  [xmm4] step_r, step_x
    ;  [xmm5] step_b, step_g

    ; prepare general purpose registers for looping
    xor r8d, r8d
    mov r9d, r8d
    sub r9d, ecx
    cmovg ecx, r8d  ; ecx = max(0, left_x)
    cmovl r9d, r8d
    movd xmm6, r9d  ; send 0 - left_x to vector registers
    mov r8d, [rsi+0x4]  ; info_header->biWidth
    mov r9d, r8d  ;
    sar r9d, 31   ;
    xor r8d, r9d  ;
    sub r8d, r9d  ; get absolute value of width
    mov r9d, r8d
    sub r8d, 1
    cmp edx, r8d
    cmovg edx, r8d  ; edx = min(width - 1, right_x)
    ; calculate stride
    mov r8d, r9d  ;
    shl r9d, 1    ;
    add r9d, r8d  ; multiply r9d by 3
    add r9d, 3
    and r9d, 0xfffffffc  ; discard 3 least-significant bits

    ; offset initial current_x, current_r, current_g, current_b
    cvtdq2pd xmm6, xmm6
    unpcklpd xmm6, xmm6
    movapd xmm7, xmm6
    mulpd xmm6, xmm4
    mulpd xmm7, xmm5
    addpd xmm2, xmm6
    addpd xmm3, xmm7

    ; calculate memory address
    mov eax, r9d  ; stride
    mov r9d, edx  ; min(width - 1, right_x)
    mul r11d  ; line_y
    shl rdx, 32
    or rax, rdx
    mov edx, ecx  ;
    shl rdx, 1    ;
    add rdx, rcx  ; multiply left_x by 3
    add rax, rdx
    add rdi, rax

    mov edx, r9d
    ; general purpose registers layout
    ;  [rdi] current image data pointer
    ;  [rsi] info_header
    ;  [rcx] loop counter
    ;  [rdx] loop counter limit
horizontal_loop:
    cmp ecx, edx
    jg horizontal_loop_end

    ; fetch current color values
    cvtpd2dq xmm6, xmm2
    cvtpd2dq xmm7, xmm3
    movq r9, xmm7
    mov rax, r9
    shr rax, 32
    mov r8d, 255    ;
    cmp eax, r8d    ;
    cmovg eax, r8d  ;
    xor r8d, r8d    ;
    test eax, eax   ;
    cmovs eax, r8d  ; clamp eax to <0; 255>
    mov [rdi], al  ; store blue
    mov eax, r9d
    mov r8d, 255    ;
    cmp eax, r8d    ;
    cmovg eax, r8d  ;
    xor r8d, r8d    ;
    test eax, eax   ;
    cmovs eax, r8d  ; clamp eax to <0; 255>
    mov [rdi+1], al  ; store green
    movq rax, xmm6
    shr rax, 32
    mov r8d, 255    ;
    cmp eax, r8d    ;
    cmovg eax, r8d  ;
    xor r8d, r8d    ;
    test eax, eax   ;
    cmovs eax, r8d  ; clamp eax to <0; 255>
    mov [rdi+2], al  ; store red

    ; perform a linear step
    addpd xmm2, xmm4
    addpd xmm3, xmm5

    add rdi, 3  ; increment memory destination pointer

    add ecx, 1
    jmp horizontal_loop

horizontal_loop_end:
    xor rax, rax

draw_end:
    add rsp, 8
    ret
