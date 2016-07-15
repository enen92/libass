;******************************************************************************
;* add_bitmaps.asm: SSE2 and x86 add_bitmaps
;******************************************************************************
;* Copyright (C) 2013 Rodger Combs <rcombs@rcombs.me>
;*
;* This file is part of libass.
;*
;* Permission to use, copy, modify, and distribute this software for any
;* purpose with or without fee is hereby granted, provided that the above
;* copyright notice and this permission notice appear in all copies.
;*
;* THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
;* WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
;* MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
;* ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
;* WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
;* ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
;* OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
;******************************************************************************

%include "x86inc.asm"

SECTION_RODATA 32

words_255: dw 0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF
last_255: dw 0x00,0x00,0x00,0xFF,0x00,0x00,0x00,0xFF,0x00,0x00,0x00,0xFF,0x00,0x00,0x00,0xFF
magic_0x4000: dd -2139062143,-2139062143,-2139062143,-2139062143,-2139062143,-2139062143,-2139062143,-2139062143

SECTION .text

;------------------------------------------------------------------------------
; void add_bitmaps( uint8_t *dst, intptr_t dst_stride,
;                   uint8_t *src, intptr_t src_stride,
;                   intptr_t width, intptr_t height );
;------------------------------------------------------------------------------

INIT_XMM
cglobal add_bitmaps_x86, 6,7
.skip_prologue:
    imul r5, r3
    add r5, r2
    PUSH r5
    mov r5, r3
.height_loop:
    xor r6, r6 ; x offset
.stride_loop:
    movzx r3, byte [r0 + r6]
    add r3b, byte [r2 + r6]
    jnc .continue
    mov r3b, 0xff
.continue:
    mov byte [r0 + r6], r3b
    inc r6
    cmp r6, r4
    jl .stride_loop ; still in scan line
    add r0, r1
    add r2, r5
    cmp r2, [rsp]
    jl .height_loop
    ADD rsp, gprsize
    RET

%macro ADD_BITMAPS 0
    cglobal add_bitmaps, 6,7
    .skip_prologue:
        cmp r4, mmsize
        %if mmsize == 16
            jl add_bitmaps_x86.skip_prologue
        %else
            jl add_bitmaps_sse2.skip_prologue
        %endif
        %if mmsize == 32
            vzeroupper
        %endif
        imul r5, r3
        add r5, r2 ; last address
    .height_loop:
        xor r6, r6 ; x offset
    .stride_loop:
        movu m1, [r0 + r6]
        paddusb m1, [r2 + r6]
        movu [r0 + r6], m1
        add r6, mmsize
        cmp r6, r4
        jl .stride_loop ; still in scan line
        add r0, r1
        add r2, r3
        cmp r2, r5
        jl .height_loop
        RET
%endmacro

INIT_XMM sse2
ADD_BITMAPS
INIT_YMM avx2
ADD_BITMAPS

;------------------------------------------------------------------------------
; void sub_bitmaps( uint8_t *dst, intptr_t dst_stride,
;                   uint8_t *src, intptr_t src_stride,
;                   intptr_t width, intptr_t height );
;------------------------------------------------------------------------------

INIT_XMM
cglobal sub_bitmaps_x86, 6,10
.skip_prologue:
    imul r5, r3
    add r5, r2 ; last address
    PUSH r5
    mov r5, r3
.height_loop:
    xor r6, r6 ; x offset
.stride_loop:
    mov r3b, byte [r0 + r6]
    sub r3b, byte [r2 + r6]
    jnc .continue
    mov r3b, 0x0
.continue:
    mov byte [r0 + r6], r3b
    inc r6
    cmp r6, r4
    jl .stride_loop ; still in scan line
    add r0, r1
    add r2, r5
    cmp r2, [rsp]
    jl .height_loop
    ADD rsp, gprsize
    RET

%if ARCH_X86_64

%macro SUB_BITMAPS 0
    cglobal sub_bitmaps, 6,10
    .skip_prologue:
        cmp r4, mmsize
        %if mmsize == 16
            jl sub_bitmaps_x86.skip_prologue
        %else
            jl sub_bitmaps_sse2.skip_prologue
        %endif
        %if mmsize == 32
            vzeroupper
        %endif
        imul r5, r3
        add r5, r2 ; last address
        mov r7, r4
        and r7, -mmsize ; &= (16);
        xor r9, r9
    .height_loop:
        xor r6, r6 ; x offset
    .stride_loop:
        movu m1, [r0 + r6]
        movu m2, [r2 + r6]
        psubusb m1, m2
        movu [r0 + r6], m1
        add r6, mmsize
        cmp r6, r7
        jl .stride_loop ; still in scan line
    .stride_loop2
        cmp r6, r4
        jge .finish
        movzx r8, byte [r0 + r6]
        sub r8b, byte [r2 + r6]
        cmovc r8, r9
        mov byte [r0 + r6], r8b
        inc r6
        jmp .stride_loop2
    .finish
        add r0, r1
        add r2, r3
        cmp r2, r5
        jl .height_loop
        RET
%endmacro

INIT_XMM sse2
SUB_BITMAPS
INIT_YMM avx2
SUB_BITMAPS

;------------------------------------------------------------------------------
; void mul_bitmaps( uint8_t *dst, intptr_t dst_stride,
;                   uint8_t *src1, intptr_t src1_stride,
;                   uint8_t *src2, intptr_t src2_stride,
;                   intptr_t width, intptr_t height );
;------------------------------------------------------------------------------

INIT_XMM
cglobal mul_bitmaps_x86, 8,12
.skip_prologue:
    imul r7, r3
    add r7, r2 ; last address
.height_loop:
    xor r8, r8 ; x offset
.stride_loop:
    movzx r9, byte [r2 + r8]
    movzx r10, byte [r4 + r8]
    imul r9, r10
    add r9, 255
    shr r9, 8
    mov byte [r0 + r8], r9b
    inc r8
    cmp r8, r6
    jl .stride_loop ; still in scan line
    add r0, r1
    add r2, r3
    add r4, r5
    cmp r2, r7
    jl .height_loop
    RET

INIT_XMM sse2
cglobal mul_bitmaps, 8,12
.skip_prologue:
    cmp r6, 8
    jl mul_bitmaps_x86.skip_prologue
    imul r7, r3
    add r7, r2 ; last address
    pxor xmm2, xmm2
    movdqa xmm3, [words_255 wrt rip]
    mov r9, r6
    and r9, -8 ; &= (~8);
.height_loop:
    xor r8, r8 ; x offset
.stride_loop:
    movq xmm1, [r2 + r8]
    movq xmm2, [r4 + r8]
    punpcklbw xmm1, xmm2
    punpcklbw xmm2, xmm2
    pmullw xmm1, xmm2
    paddw xmm1, xmm3
    psrlw xmm1, 0x08
    packuswb xmm1, xmm1
    movq [r0 + r8], xmm1
    add r8, 8
    cmp r8, r9
    jl .stride_loop ; still in scan line
.stride_loop2
    cmp r8, r6
    jge .finish
    movzx r10, byte [r2 + r8]
    movzx r11, byte [r4 + r8]
    imul r10, r11
    add r10, 255
    shr r10, 8
    mov byte [r0 + r8], r10b
    inc r8
    jmp .stride_loop2
.finish:
    add r0, r1
    add r2, r3
    add r4, r5
    cmp r2, r7
    jl .height_loop
    RET

INIT_YMM avx2
cglobal mul_bitmaps, 8,12
    cmp r6, 16
    jl mul_bitmaps_sse2.skip_prologue
    %if mmsize == 32
        vzeroupper
    %endif
    imul r7, r3
    add r7, r2 ; last address
    vpxor ymm2, ymm2
    vmovdqa ymm3, [words_255 wrt rip]
    mov r9, r6
    and r9, -16 ; &= (~16);
.height_loop:
    xor r8, r8 ; x offset
.stride_loop:
    vmovdqu xmm1, [r2 + r8]
    vpermq ymm1, ymm1, 0x10
    vmovdqu xmm2, [r4 + r8]
    vpermq ymm2, ymm2, 0x10
    vpunpcklbw ymm1, ymm1, ymm2
    vpunpcklbw ymm2, ymm2, ymm2
    vpmullw ymm1, ymm1, ymm2
    vpaddw ymm1, ymm1, ymm3
    vpsrlw ymm1, ymm1, 0x08
    vextracti128 xmm4, ymm1, 0x1
    vpackuswb ymm1, ymm1, ymm4
    vmovdqa [r0 + r8], xmm1
    add r8, 16
    cmp r8, r9
    jl .stride_loop ; still in scan line
.stride_loop2
    cmp r8, r6
    jge .finish
    movzx r10, byte [r2 + r8]
    movzx r11, byte [r4 + r8]
    imul r10, r11
    add r10, 255
    shr r10, 8
    mov byte [r0 + r8], r10b
    inc r8
    jmp .stride_loop2
.finish:
    add r0, r1
    add r2, r3
    add r4, r5
    cmp r2, r7
    jl .height_loop
    RET

;------------------------------------------------------------------------------
; void rgba_blend(uint8_t *dst, intptr_t dst_stride,
;                 uint8_t *src, intptr_t src_stride,
;                 intptr_t src_w, intptr_t src_h,
;                 uint32_t color);
;------------------------------------------------------------------------------

;INIT_XMM sse2
;INIT_YMM avx2
%macro RGBA_BLEND 0
cglobal rgba_blend, 7,12
    cmp r6b, 0xFF
    je .end
    test r4, r4
    je .end
    test r5, r5
    je .end
    pxor m0, m0
    movd xm1, r6d ; m1 = rgba
    punpcklbw m1, m0
    pshuflw m1, m1, 0x39
    %if mmsize == 16
        punpcklqdq m1, m1
    %else
        vpbroadcastq m1, xm1
    %endif
    por m1, [last_255 wrt rip]
    movd xm2, r6d ; m2 = alpha
    %if mmsize == 16
        punpcklbw m2, m2
        punpcklbw m2, m2
        pshufd m2, m2, 0
    %else
        vpbroadcastb m2, xm2
    %endif
    imul r5, r3
    add r5, r2 ; end = src + (src_stride * src_h)
.height_loop:
    xor r6, r6 ; i = 0
.width_loop:
    %if mmsize == 16
        movzx r7d, word [r2 + r6]
    %else
        mov r7d, [r2 + r6]
    %endif
    movd xm3, r7d ; m3 = v
    punpcklbw m3, m0
    punpcklwd m3, m0
    %if mmsize == 32
        vpermq m3, m3, 0x98
    %endif
    punpckldq m3, m0
    psllq m3, 14
    pmuludq m3, [magic_0x4000 wrt rip]
    psrlq m3, 39
    pshuflw m3, m3, 0
    pshufhw m3, m3, 0
    %if mmsize == 16
        movdqu m4, m3
        pmulhuw m4, m2
    %else
        vpmulhuw m4, m3, m2
    %endif
    psubw m3, m4
    %if mmsize == 16
        movq m4, [r0 + r6 * 4]
        punpcklbw m4, m0
    %else
        vmovdqu xm4, [r0 + r6 * 4]
        vpermq m4, m4, 0x98
        punpcklbw m4, m0
    %endif
    mova m5, m1
    psubw m5, m4
    psllw m5, 1
    pmulhrsw m5, m3
    paddw m4, m5
    %if mmsize == 16
        packuswb m4, m4
        movh [r0 + r6 * 4], m4
    %else
        vpackuswb m4, m4
        vpermq m4, m4, 0x8
        movu [r0 + r6 * 4], xm4
    %endif
    add r6, mmsize / 8 ; i += 2 (or 4)
    cmp r6, r4 ; i < w
    jl .width_loop
    add r0, r1 ; dst += dst_stride
    add r2, r3 ; src += src_stride
    cmp r2, r5 ; src < end
    jl .height_loop
.end:
    RET
%endmacro

INIT_XMM sse2
RGBA_BLEND
INIT_YMM avx2
RGBA_BLEND

%endif
