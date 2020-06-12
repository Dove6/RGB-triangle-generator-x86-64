; description:   Contains the function for drawing interpolated horizontal lines on R8G8B8 bitmap.
; author:        Dawid Sygocki
; last modified: 2020-06-12

section .text
    global draw_horizontal_line

%macro clamp_0_255 2
    ; parameters:
    ;  %1 source and destination register (to be clamped)
    ;  %2 temporary helper register
    mov %2, 255
    cmp %1, %2
    cmovg %1, %2  ; replace %1 with 255 if %1 > 255
    xor %2, %2
    test %1, %1
    cmovs %1, %2  ; replace %1 with 0 if %1 < 0
%endmacro

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

    ; function prologue
    sub rsp, 8  ; align the stack

    ; check if image_data or info_header equal NULL
    mov rax, -1
    test rdi, rdi
    jz draw_end
    test rsi, rsi
    jz draw_end

    ; move left_x and right_x to general purpose registers
    mov r11, rdx  ; line_y
    cvtpd2dq xmm8, xmm0  ; left_x
    movd ecx, xmm8
    cvtpd2dq xmm8, xmm4  ; right_x
    movd edx, xmm8

    ; check if left_x and right_x are in right order
    mov rax, -2
    cmp ecx, edx
    jg draw_end
    ; if right_x < 0, skip drawing
    xor rax, rax
    cmp edx, eax
    jl draw_end
    ; if left_x >= image width, skip drawing
    mov r10d, [rsi+0x4]  ; info_header->biWidth
    mov r8d, r10d  ;
    sar r8d, 31    ;
    xor r10d, r8d  ;
    sub r10d, r8d  ; get absolute value of width
    cmp r10d, ecx
    jl draw_end
    ;  [r10d] abs(width)

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
    ; vector registers layout (high double, low double)
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
    ;  [xmm2] -1.0, -1.0  }
    ;  [xmm3] -1.0, -1.0  } to avoid dividing by zero
    ;  [xmm4] 0.0, 0.0
    ;  [xmm5] 0.0, 0.0
    ; else (left_x != right_x)
    ;  [xmm2] left_x - right_x, left_x - right_x
    ;  [xmm3] 0.0, 0.0
    ;  [xmm4] left_r - right_r, left_x - right_x
    ;  [xmm5] left_b - right_b, left_g - right_g
    divpd xmm4, xmm2
    divpd xmm5, xmm2
    ;  [xmm4] step_r, step_x
    ;  [xmm5] step_b, step_g
    ; (zeroed if left_x == right_x)
    movapd xmm2, xmm4
    movapd xmm3, xmm5
    ;  [xmm2] step_r, step_x
    ;  [xmm3] step_b, step_g

    ; prepare general purpose registers for looping
    xor r8d, r8d
    mov r9d, r8d
    sub r9d, ecx
    cmovg ecx, r8d  ; ecx = max(0, left_x)
    cmovl r9d, r8d
    movd xmm4, r9d  ; send max(0, 0 - left_x) to a vector register
    mov r9d, r10d  ; abs(width)
    mov r8d, r9d
    sub r8d, 1
    cmp edx, r8d
    cmovg edx, r8d  ; edx = min(width - 1, right_x)
    ; calculate stride
    mov r8d, r9d  ;
    shl r9d, 1    ;
    add r9d, r8d  ; multiply r9d by 3
    add r9d, 3
    and r9d, 0xfffffffc  ; discard 3 least-significant bits

    ; calculate initial value of current_x, current_r, current_g, current_b
    ;  by adding appropriate step values multiplied by max(0, 0 - left_x)
    ;  to left_x, left_r, left_g, left_b
    cvtdq2pd xmm4, xmm4
    unpcklpd xmm4, xmm4
    movapd xmm5, xmm4
    mulpd xmm4, xmm2
    mulpd xmm5, xmm3
    addpd xmm0, xmm4
    addpd xmm1, xmm5
    ;  [xmm0] current_r, current_x
    ;  [xmm1] current_b, current_g

    ; calculate memory address
    mov eax, r9d  ; stride
    mov r9d, edx  ; move min(width - 1, right_x), as edx content is destroyed after multiplication
    mul r11d  ; edx:eax <- stride * line_y
    shl rdx, 32
    or rax, rdx
    mov edx, ecx  ;
    shl rdx, 1    ;
    add rdx, rcx  ; multiply left_x by 3 (bytes per pixel)
    add rax, rdx
    add rdi, rax

    mov edx, r9d
horizontal_loop:
    ; general purpose registers layout
    ;  [rdi] current image data pointer
    ;  [rsi] info_header
    ;  [rcx] loop counter
    ;  [rdx] loop counter limit
    ; vector registers layout
    ;  [xmm0] current_r, current_x
    ;  [xmm1] current_b, current_g
    ;  [xmm2] step_r, step_x
    ;  [xmm3] step_b, step_g
    cmp ecx, edx
    jg horizontal_loop_end

    ; fetch current color values
    cvtpd2dq xmm4, xmm0
    cvtpd2dq xmm5, xmm1
    movq r9, xmm5
    mov rax, r9
    shr rax, 32
    clamp_0_255 eax, r8d
    mov [rdi], al  ; store blue
    mov eax, r9d
    clamp_0_255 eax, r8d
    mov [rdi+1], al  ; store green
    movq rax, xmm4
    shr rax, 32
    clamp_0_255 eax, r8d
    mov [rdi+2], al  ; store red

    ; perform a linear interpolation step
    addpd xmm0, xmm2
    addpd xmm1, xmm3

    add rdi, 3  ; increment memory destination pointer
    add ecx, 1
    jmp horizontal_loop

horizontal_loop_end:
    xor rax, rax

draw_end:
    ; function epilogue
    add rsp, 8  ; undo stack alignment
    ret
