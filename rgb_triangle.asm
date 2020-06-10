; description:   Contains the function for drawing triangles on R8G8B8 bitmap.
; author:        Dawid Sygocki
; last modified: 2020-05-15

section	.text
    global draw_triangle
    extern memset
    extern swap_vertices

draw_triangle:
    ; function arguments
    ;  BYTE *image_data
    %define image_data ebp+0x8
    ;  struct BITMAPINFOHEADER *info_header
    %define info_header ebp+0xc
    ;  struct VERTEXDATA (*vertices)[3]
    %define vertices ebp+0x10

    ; stack layout
    ;  ebp-0x30  vertical_step - vertical linear interpolation step for three sides of a triangle
    ;    ebp-0x30  vertical_step[0].x (float dword)
    ;    ebp-0x2c  vertical_step[0].r (float dword)
    ;    ebp-0x28  vertical_step[0].g (float dword)
    ;    ebp-0x24  vertical_step[0].b (float dword)
    ;    ebp-0x20  vertical_step[1].x (float dword)
    ;    ebp-0x1c  vertical_step[1].r (float dword)
    ;    ebp-0x18  vertical_step[1].g (float dword)
    ;    ebp-0x14  vertical_step[1].b (float dword)
    ;    ebp-0x10  vertical_step[2].x (float dword)
    ;    ebp-0x0c  vertical_step[2].r (float dword)
    ;    ebp-0x08  vertical_step[2].g (float dword)
    ;    ebp-0x04  vertical_step[2].b (float dword)
    %define vertical_step ebp-0x30
    ;  ebp-0x50  right - right end of horizontal line
    ;    ebp-0x50  right.x (float dword)
    ;    ebp-0x4c  right.r (float dword)
    ;    ebp-0x48  right.g (float dword)
    ;    ebp-0x44  right.b (float dword)
    ;    ebp-0x40  right.int_x (signed int dword)
    ;    ebp-0x3c  right.int_r (signed int dword)
    ;    ebp-0x38  right.int_g (signed int dword)
    ;    ebp-0x34  right.int_b (signed int dword)
    %define right ebp-0x50
    ;  ebp-0x70  left - left end of horizontal line
    ;    ebp-0x70  left.x (float dword)
    ;    ebp-0x6c  left.r (float dword)
    ;    ebp-0x68  left.g (float dword)
    ;    ebp-0x64  left.b (float dword)
    ;    ebp-0x60  left.int_x (signed int dword)
    ;    ebp-0x5c  left.int_r (signed int dword)
    ;    ebp-0x58  left.int_g (signed int dword)
    ;    ebp-0x54  left.int_b (signed int dword)
    %define left ebp-0x70
    ;  ebp-0x7c  horizontal_step - horizontal linear interpolation step between "left" and "right"
    ;    ebp-0x7c  horizontal_step.r (float dword)
    ;    ebp-0x78  horizontal_step.g (float dword)
    ;    ebp-0x74  horizontal_step.b (float dword)
    %define horizontal_step ebp-0x7c
    ;  ebp-0x80  abs_width - image width in pixels (unsigned int dword)
    %define abs_width ebp-0x80
    ;  ebp-0x84  max_y - maximal Y position of triangle fitting into the bitmap (signed int dword)
    %define max_y ebp-0x84
    ;  ebp-0x88  min_y - minimal Y position of triangle fitting into the bitmap (signed int dword)
    %define min_y ebp-0x88
    ;  ebp-0x8c  max_x - maximal X position of triangle fitting into the bitmap (signed int dword)
    %define max_x ebp-0x8c
    ;  ebp-0x90  min_x - minimal X position of triangle fitting into the bitmap (signed int dword)
    %define min_x ebp-0x90
    ;  ebp-0x94  stride - image width in bytes rounded up to the nearest dword (unsigned int dword)
    %define stride ebp-0x94
    ;  ebp-0x98  row_address - address of the first pixel in the current row (pointer dword)
    %define row_address ebp-0x98

    ; total size of local variables put initially on the stack
    %define local_size 0x98
    
    ; prologue
    enter local_size, 0

    ; make sure provided pointer arguments are not null
    mov eax, -1  ; error indicator
    cmp [image_data], dword 0
    jz draw_triangle_end
    cmp [info_header], dword 0
    jz draw_triangle_end
    cmp [vertices], dword 0
    jz draw_triangle_end
    
    ; zero-initialize local variables
    push dword local_size
    push dword 0  ; memory value after initialization
    lea eax, [ebp-local_size]
    push eax
    call memset  ; memset(ebp-local_size, 0, local_size)
    add esp, 12
    
    ; prepare FPU
    finit
    
    ; save the callee-saved registers on the stack
    push ebx
    push esi
    push edi

calc_vertical_step0:
    ; calculate vertical steps for line interpolation of x position and colors
    ;  between the first and the second vertex
    ; first vertex offset = 0 * 12
    ; second vertex offset = 1 * 12
    mov ebx, [vertices]
    mov eax, [ebx+0x0+0x4]  ; (*vertices)[0].posY
    mov [min_y], eax  ; save (*vertices)[0].posY as min_y (assuming the vertices are sorted)
    sub eax, [ebx+0xc+0x4]  ; (*vertices)[1].posY
    jz calc_vertical_step1  ; if positions are equal, skip to the next step
    push eax          ;
    fild dword [esp]  ; load y position difference into FPU
    ; vertical_step[0].x = ((*vertices)[0].posX - (*vertices)[1].posX) / ((*vertices)[0].posY - (*vertices)[1].posY)
    fild dword [ebx+0x0+0x0]  ; load (*vertices)[0].posX into FPU
    fisub dword [ebx+0xc+0x0]  ; subtract (*vertices)[1].posX
    fdiv st0, st1
    fstp dword [vertical_step+0x0]  ; store result in vertical_step[0].x
    ; vertical_step[0].r = ((*vertices)[0].colR - (*vertices)[1].colR) / ((*vertices)[0].posY - (*vertices)[1].posY)
    movzx eax, byte [ebx+0x0+0x8]  ; zero-extend 8-bit (*vertices)[0].colR to 32-bits
    mov [esp], eax
    fild dword [esp]
    movzx eax, byte [ebx+0xc+0x8]  ; zero-extend 8-bit (*vertices)[1].colR to 32-bits
    mov [esp], eax
    fisub dword [esp]
    fdiv st0, st1
    fstp dword [vertical_step+0x4]  ; store result in vertical_step[0].r
    ; vertical_step[0].g = ((*vertices)[0].colG - (*vertices)[1].colG) / ((*vertices)[0].posY - (*vertices)[1].posY)
    movzx eax, byte [ebx+0x0+0x9]  ; (*vertices)[0].colG
    mov [esp], eax
    fild dword [esp]
    movzx eax, byte [ebx+0xc+0x9]  ; (*vertices)[1].colG
    mov [esp], eax
    fisub dword [esp]
    fdiv st0, st1
    fstp dword [vertical_step+0x8]  ; store result in vertical_step[0].g
    ; vertical_step[0].b = ((*vertices)[0].colB - (*vertices)[1].colB) / ((*vertices)[0].posY - (*vertices)[1].posY)
    movzx eax, byte [ebx+0x0+0xa]  ; (*vertices)[0].colB
    mov [esp], eax
    fild dword [esp]
    movzx eax, byte [ebx+0xc+0xa]  ; (*vertices)[1].colB
    mov [esp], eax
    fisub dword [esp]
    fdiv st0, st1
    fstp dword [vertical_step+0xc]  ; store result in vertical_step[0].b
    fstp st0
    add esp, 4

calc_vertical_step1:
    ; calculate vertical steps for line interpolation of x position and colors
    ;  between the first and the third vertex
    ; first vertex offset = 0 * 12
    ; third vertex offset = 2 * 12
    mov eax, [ebx+0x0+0x4]  ; (*vertices)[0].posY
    mov edx, [ebx+0x18+0x4]  ; (*vertices)[2]posY
    mov [max_y], edx  ; save (*vertices[2]).posY as max_y (assuming the vertices are sorted)
    sub eax, edx
    jz calc_vertical_step2
    push eax          ;
    fild dword [esp]  ; load position difference into FPU
    ; vertical_step[1].x = ((*vertices)[0].posX - (*vertices)[2].posX) / ((*vertices)[0].posY - (*vertices)[2].posY)
    fild dword [ebx+0x0+0x0]  ; (*vertices)[0].posX
    fisub dword [ebx+0x18+0x0]  ; (*vertices)[2].posX
    fdiv st0, st1
    fstp dword [vertical_step+0x10+0x0]  ; store result in vertical_step[1].x
    ; vertical_step[1].r = ((*vertices)[0].colR - (*vertices)[2].colR) / ((*vertices)[0].posY - (*vertices)[2].posY)
    movzx eax, byte [ebx+0x0+0x8]  ; (*vertices)[0].colR
    mov [esp], eax
    fild dword [esp]
    movzx eax, byte [ebx+0x18+0x8]  ; (*vertices)[2].colR
    mov [esp], eax
    fisub dword [esp]
    fdiv st0, st1
    fstp dword [vertical_step+0x10+0x4]  ; store result in vertical_step[1].r
    ; vertical_step[1].g = ((*vertices)[0].colG - (*vertices)[2].colG) / ((*vertices)[0].posY - (*vertices)[2].posY)
    movzx eax, byte [ebx+0x0+0x9]  ; (*vertices)[0].colG
    mov [esp], eax
    fild dword [esp]
    movzx eax, byte [ebx+0x18+0x9]  ; (*vertices)[2].colG
    mov [esp], eax
    fisub dword [esp]
    fdiv st0, st1
    fstp dword [vertical_step+0x10+0x8]  ; store result in vertical_step[1].g
    ; vertical_step[1].b = ((*vertices)[0].colB - (*vertices)[2].colB) / ((*vertices)[0].posY - (*vertices)[2].posY)
    movzx eax, byte [ebx+0x0+0xa]  ; (*vertices)[0].colB
    mov [esp], eax
    fild dword [esp]
    movzx eax, byte [ebx+0x18+0xa]  ; (*vertices)[2].colB
    mov [esp], eax
    fisub dword [esp]
    fdiv st0, st1
    fstp dword [vertical_step+0x10+0xc]  ; store result in vertical_step[1].b
    fstp st0
    add esp, 4

calc_vertical_step2:
    ; calculate vertical steps for line interpolation of x position and colors
    ;  between the second and the third vertex
    ; second vertex offset = 1 * 12
    ; third vertex offset = 2 * 12
    mov eax, [ebx+0xc+0x4]  ; (*vertices)[1].posY
    sub eax, [ebx+0x18+0x4]  ; (*vertices)[2].posY
    jz calc_minmax_y
    push eax          ;
    fild dword [esp]  ; load position difference into FPU
    ; vertical_step[2].x = ((*vertices)[1].posX - (*vertices)[2].posX) / ((*vertices)[1].posY - (*vertices)[2].posY)
    fild dword [ebx+0xc+0x0]  ; (*vertices)[1].posX
    fisub dword [ebx+0x18+0x0]  ; (*vertices)[2].posX
    fdiv st0, st1
    fstp dword [vertical_step+0x20+0x0]  ; store result in vertical_step[2].x
    ; vertical_step[2].r = ((*vertices)[1].colR - (*vertices)[2].colR) / ((*vertices)[1].posY - (*vertices)[2].posY)
    movzx eax, byte [ebx+0xc+0x8]  ; (*vertices)[1].colR
    mov [esp], eax
    fild dword [esp]
    movzx eax, byte [ebx+0x18+0x8]  ; (*vertices)[2].colR
    mov [esp], eax
    fisub dword [esp]
    fdiv st0, st1
    fstp dword [vertical_step+0x20+0x4]  ; store result in vertical_step[2].r
    ; vertical_step[2].g = ((*vertices)[1].colG - (*vertices)[2].colG) / ((*vertices)[1].posY - (*vertices)[2].posY)
    movzx eax, byte [ebx+0xc+0x9]  ; (*vertices)[1].colG
    mov [esp], eax
    fild dword [esp]
    movzx eax, byte [ebx+0x18+0x9]  ; (*vertices)[2].colG
    mov [esp], eax
    fisub dword [esp]
    fdiv st0, st1
    fstp dword [vertical_step+0x20+0x8]  ; store result in vertical_step[2].g
    ; vertical_step[2].b = ((*vertices)[1].colB - (*vertices)[2].colB) / ((*vertices)[1].posY - (*vertices)[2].posY)
    movzx eax, byte [ebx+0xc+0xa]  ; (*vertices)[1].colB
    mov [esp], eax
    fild dword [esp]
    movzx eax, byte [ebx+0x18+0xa]  ; (*vertices)[2].colB
    mov [esp], eax
    fisub dword [esp]
    fdiv st0, st1
    fstp dword [vertical_step+0x20+0xc]  ; store result in vertical_step[2].b
    fstp st0
    add esp, 4

calc_minmax_y:
    ; clamp minimal and maximal y values to fit the bitmap
    ;  this allows to draw triangles only partially present inside bitmap boundaries
    ;  with correct coloring
    ; min_y = max(min_y, 0)
    mov esi, ebx
    xor ebx, ebx
    mov eax, [min_y]  ; load min_y
    test eax, eax
    cmovl eax, ebx
    mov [min_y], eax  ; store min_y

    ; max_y = min(max_y, abs(info_header->biHeight) - 1)
    mov ebx, [info_header]
    mov eax, [ebx+0x8]  ; info_header->biHeight
    mov edx, eax  ;
    sar edx, 31   ;
    xor eax, edx  ;
    sub eax, edx  ; get absolute height
    sub eax, 1
    mov edx, [max_y]  ; load max_y
    cmp eax, edx
    cmovl edx, eax
    mov [max_y], edx  ; store max_y

    ; calculate row stride
    mov eax, [ebx+0x4]  ; info_header->biWidth
    mov ebx, eax  ;
    sar ebx, 31   ;
    xor eax, ebx  ;
    sub eax, ebx  ; get absolute value of width
    mov [abs_width], eax  ; store that value for later use
    mov ebx, eax  ;
    shl eax, 1    ;
    add eax, ebx  ; multiply eax by 3
    add eax, 3
    and eax, 0xfffffffc  ; discard 3 least-significant bits
    mov [stride], eax

draw_triangle_y_before_loop:
    ; prepare vertical loop counter and calculate initial position/color values
    ;  for the convenience of modification in-loop
    ; esi - vertices
    mov ecx, [min_y]
    cmp ecx, [max_y]
    jg draw_triangle_y_after_loop
    ; choose currently needed vertex and vertical step data
    mov edi, esi ;
    add edi, 12  ; edi - address of (*vertices)[1]
    lea ebx, [vertical_step+0x0]  ; vertical_step[0]
    mov edx, ebx
    add ebx, 32  ; ebx - vertical_step[2]
    cmp ecx, [edi+0x0+0x4]  ; compare initial counter value against (*vertices)[1].posY
    cmovl edi, esi  ; reset to the address of (*vertices)[0]
    cmovl ebx, edx  ; reset to vertical_step[0]
    xor eax, eax
    xor edx, edx
    ; ebx - suitable vertical_step
    ; edi - suitable vertex

    ; calculate the initial value of left.x (and left.int_x)
    ; left.x = (*vertices)[?].posX + (i - (*vertices)[?].posY) * vertical_step[?].x
    ;  where i = counter (ecx) = current row index
    mov eax, ecx
    sub eax, [edi+0x4]
    push eax  ; vertical step multiplier: (i - (*vertices)[?].posY)
    fild dword [esp]
    mov eax, [ebx+0x0]
    mov [esp], eax  ; vertical_step[?].x
    fld dword [esp]
    fmul st0, st1
    mov eax, [edi+0x0]
    mov [esp], eax  ; (*vertices)[?].posX
    fiadd dword [esp]
    fst dword [left+0x0]  ; left.x
    fistp dword [left+0x10]  ; left.int_x
    ; st0 - vertical step multiplier for the left

    ; calculate the initial value of left.r (and left.int_r)
    ; left.r = (*vertices)[?].colR + (i - (*vertices)[?].posY) * vertical_step[?].r
    mov eax, [ebx+0x4]
    mov [esp], eax  ; vertical_step[?].r
    fld dword [esp]
    fmul st0, st1
    mov al, [edi+0x8]
    movzx eax, al
    mov [esp], eax  ; expanded (*vertices)[?].colR
    fiadd dword [esp]
    fst dword [left+0x4]  ; left.r
    fistp dword [left+0x14]  ; left.int_r

    ; calculate the initial value of left.g (and left.int_g)
    ; left.g = (*vertices)[?].colG + (i - (*vertices)[?].posY) * vertical_step[?].g
    mov eax, [ebx+0x8]
    mov [esp], eax  ; vertical_step[?].g
    fld dword [esp]
    fmul st0, st1
    mov al, [edi+0x9]
    movzx eax, al
    mov [esp], eax  ; expanded (*vertices)[?].colG
    fiadd dword [esp]
    fst dword [left+0x8]  ; left.g
    fistp dword [left+0x18]  ; left.int_g

    ; calculate the initial value of left.b (and left.int_b)
    ; left.b = (*vertices)[?].colB + (i - (*vertices)[?].posY) * vertical_step[?].b
    mov eax, [ebx+0xc]
    mov [esp], eax  ; vertical_step[?].b
    fld dword [esp]
    fmul st0, st1
    mov al, [edi+0xa]
    movzx eax, al
    mov [esp], eax  ; expanded (*vertices)[?].colB
    fiadd dword [esp]
    fst dword [left+0xc]  ; left.b
    fistp dword [left+0x1c]  ; left.int_b
    fstp st0

    ; calculate the initial value of right.x (and right.int_x)
    ; right.x = (*vertices)[0].posX + (i - (*vertices)[0].posY) * vertical_step[1].x
    mov eax, ecx
    sub eax, [esi+0x0+0x4]
    mov [esp], eax  ; vertical step multiplier: (i - (*vertices)[0].posY)
    fild dword [esp]
    mov eax, [vertical_step+0x10+0x0]
    mov [esp], eax  ; vertical_step[1].x
    fld dword [esp]
    fmul st0, st1
    mov eax, [esi+0x0+0x0]
    mov [esp], eax  ; vertices[0].posX
    fiadd dword [esp]
    fst dword [right+0x0]  ; right.x
    fistp dword [right+0x10]  ; right.int_x
    ; st0 - vertical step multiplier for the right

    ; calculate the initial value of right.r (and right.int_r)
    ; right.r = (*vertices)[0].colR + (i - (*vertices)[0].posY) * vertical_step[1].r
    mov eax, [vertical_step+0x10+0x4]
    mov [esp], eax  ; vertical_step[1].r
    fld dword [esp]
    fmul st0, st1
    mov al, [esi+0x8]
    movzx eax, al
    mov [esp], eax  ; expanded vertices[0].colR
    fiadd dword [esp]
    fst dword [right+0x4]  ; right.r
    fistp dword [right+0x14]  ; right.int_r

    ; calculate the initial value of right.g (and right.int_g)
    ; right.g = (*vertices)[0].colG + (i - (*vertices)[0].posY) * vertical_step[1].g
    mov eax, [vertical_step+0x10+0x8]
    mov [esp], eax  ; vertical_step[1].g
    fld dword [esp]
    fmul st0, st1
    mov al, [esi+0x9]
    movzx eax, al
    mov [esp], eax  ; expanded vertices[0].colG
    fiadd dword [esp]
    fst dword [right+0x8]  ; right.g
    fistp dword [right+0x18]  ; right.int_g

    ; calculate the initial value of right.b (and right.int_b)
    ; right.b = (*vertices)[0].colB + (i - (*vertices)[0].posY) * vertical_step[1].b
    mov eax, [vertical_step+0x10+0xc]
    mov [esp], eax  ; vertical_step[1].b (float)
    fld dword [esp]
    fmul st0, st1
    mov al, [esi+0xa]
    movzx eax, al
    mov [esp], eax  ; expanded vertices[0].colB
    fiadd dword [esp]
    fst dword [right+0xc]  ; right.b
    fistp dword [right+0x1c]  ; right.int_b
    fstp st0
    add esp, 4

    ; calculate row address
    mov eax, [stride]
    mul dword [min_y]
    add eax, [image_data]
    mov [row_address], eax

draw_triangle_y_loop:
    ; vertical loop for y (ecx) in range <min_y; max_y>
    lea edi, [left]
    lea edx, [right]
    mov eax, [edi+0x10]  ; left.int_x
    mov ebx, [edx+0x10]  ; right.int_x
    cmp eax, ebx
    jz draw_triangle_x_before_loop
    ; exchange left and right pointer if left.int_x > right.int_x
    cmovg eax, edi
    cmovg edi, edx
    cmovg edx, eax
    cmovg eax, ebx
    cmovg ebx, [edx+0x10]
    
    ; calculate horizontal steps for line interpolation of colors between the ends of the horizontal line
    sub eax, ebx
    push eax  ; x position difference
    fild dword [esp]
    add esp, 4
    ; horizontal_step.r = (left r - right r) / (left x - right x)
    fld dword [edi+0x4]
    fsub dword [edx+0x4]
    fdiv st0, st1
    fstp dword [horizontal_step+0x0]
    ; horizontal_step.g = (left g - right g) / (left x - right x)
    fld dword [edi+0x8]
    fsub dword [edx+0x8]
    fdiv st0, st1
    fstp dword [horizontal_step+0x4]
    ; horizontal_step.b = (left b - right b) / (left x - right x)
    fld dword [edi+0xc]
    fsub dword [edx+0xc]
    fdiv st0, st1
    fstp dword [horizontal_step+0x8]
    fstp st0 ; clear fpu

draw_triangle_x_before_loop:
    ; prepare horizontal loop counter and calculate initial color values
    ;  for the convenience of modification in-loop
    ; clamp minimal and maximal x values to fit the bitmap
    ; min_x = max(left x, 0)
    mov eax, [edi+0x10]  ; left-most int_x
    xor ebx, ebx
    cmp eax, ebx
    cmovl eax, ebx
    mov [min_x], eax
    ; max_x = min(right x, abs_width - 1)
    mov eax, [edx+0x10]  ; right-most int_x
    mov ebx, [abs_width]
    dec ebx
    cmp eax, ebx
    cmovg eax, ebx
    mov [max_x], eax
    push ecx  ; put vertical counter on the stack
    mov ecx, [min_x]  ; fetch initial horizontal counter
    cmp ecx, eax
    jg draw_triangle_x_after_loop
    ; calculate initial color values
    ;  the values are stored in FPU during the horizontal loop
    ;  st3 - horizontal step multiplier
    ;  st2 - red
    ;  st1 - green
    ;  st0 - blue
    mov eax, ecx
    mov ebx, [edi+0x10]  ; left-most int_x
    sub eax, ebx
    push eax
    ; load horizontal_step values for quick addition
    fld dword [horizontal_step+0x0]
    fld dword [horizontal_step+0x4]
    fld dword [horizontal_step+0x8]
    ; red = left r + (i - left x) * horizontal_step.r
    fld st2
    fimul dword [esp]
    fiadd dword [edi+0x14]  ; left-most int_r
    ; green = left g + (i - left x) * horizontal_step.g
    fld st2
    fimul dword [esp]
    fiadd dword [edi+0x18]  ; left-most int_g
    ; blue = left b + (i - left x) * horizontal_step.b
    fld st2
    fimul dword [esp]
    fiadd dword [edi+0x1c]  ; left-most int_b
    ; calculate memory address of the first pixel in a row
    mov edi, ecx  ;
    shl edi, 1    ;
    add edi, ecx  ; multiply min_x by 3
    add edi, [row_address]
    mov ebx, [max_x]
draw_triangle_x_loop:
    ; horizontal loop for x (ecx) in range <min_x; max_x>
    ; fetch and store blue
    fist dword [esp]
    fincstp
    mov eax, [esp]
    mov edx, 255    ;
    cmp eax, edx    ;
    cmovg eax, edx  ;
    xor edx, edx    ;
    test eax, eax   ;
    cmovs eax, edx  ; clamp to <0; 255>
    mov [edi], al
    ; fetch and store green
    fist dword [esp]
    fincstp
    mov eax, [esp]
    mov edx, 255    ;
    cmp eax, edx    ;
    cmovg eax, edx  ;
    xor edx, edx    ;
    test eax, eax   ;
    cmovs eax, edx  ; clamp to <0; 255>
    mov [edi+1], al
    ; fetch and store red
    fist dword [esp]
    mov eax, [esp]
    mov edx, 255    ;
    cmp eax, edx    ;
    cmovg eax, edx  ;
    xor edx, edx    ;
    test eax, eax   ;
    cmovs eax, edx  ; clamp to <0; 255>
    mov [edi+2], al
    ; calculate colors for the next pixel
    fadd st3  ; red
    fdecstp
    fadd st3  ; green
    fdecstp
    fadd st3  ; blue
    add edi, 3
    inc ecx
    cmp ecx, ebx  ; check loop condition
    jle draw_triangle_x_loop

    add esp, 4
    times 6 fstp st0  ; clear FPU
draw_triangle_x_after_loop:
    pop ecx  ; get back the vertical loop counter
    inc ecx
    mov eax, [row_address]  ;
    add eax, [stride]       ;
    mov [row_address], eax  ; calculate the memory address of the next row
    ; update left and right ends of horizontal line
    ;  by adding appropriate step values to their position/color
    fld dword [left+0x0]
    mov eax, [esi+0xc+0x4]  ; (*vertices)[1].posY
    lea ebx, [vertical_step+0x20]  ;
    cmp ecx, eax                   ;
    lea eax, [vertical_step+0x0]   ;
    cmovg eax, ebx                 ; place suitable vertical_step in eax
    fadd dword [eax+0x0]  ; vertical_step[?].x
    fst dword [left+0x0]    ;
    fistp dword [left+0x10]  ; save left.x
    fld dword [left+0x4]
    fadd dword [eax+0x4]  ; vertical_step[?].r
    fst dword [left+0x4]     ;
    fistp dword [left+0x14]  ; save left.r
    fld dword [left+0x8]
    fadd dword [eax+0x8]  ; vertical_step[?].g
    fst dword [left+0x8]     ;
    fistp dword [left+0x18]  ; save left.g
    fld dword [left+0xc]
    fadd dword [eax+0xc]  ; vertical_step[?].b
    fst dword [left+0xc]     ;
    fistp dword [left+0x1c]  ; save left.b
    fld dword [right+0x0]
    fadd dword [vertical_step+0x10] ; vertical_step[1].x
    fst dword [right+0x0]     ;
    fistp dword [right+0x10]  ; save right.x
    fld dword [right+0x4]
    fadd dword [vertical_step+0x14] ; vertical_step[1].r
    fst dword [right+0x4]     ;
    fistp dword [right+0x14]  ; save right.r
    fld dword [right+0x8]
    fadd dword [vertical_step+0x18] ; vertical_step[1].g
    fst dword [right+0x8]     ;
    fistp dword [right+0x18]  ; save right.g
    fld dword [right+0xc]
    fadd dword [vertical_step+0x1c] ; vertical_step[1].b
    fst dword [right+0xc]     ;
    fistp dword [right+0x1c]  ; save right.b
    cmp ecx, [max_y]
    jle draw_triangle_y_loop

draw_triangle_y_after_loop:
    xor eax, eax ; return 0
    ; restore the callee-saved registers
    pop edi
    pop esi
    pop ebx

draw_triangle_end:
    leave
    ret
