    .section .text.start, "ax", @progbits
    .globl _start
_start:
    la sp, __stack_top
    la t0, __bss_start
    la t1, __bss_end
1:
    bgeu t0, t1, 2f
    sw zero, 0(t0)
    addi t0, t0, 4
    j 1b
2:
    call main
3:
    j 3b

    # RV32I software multiplication: low 32 bits of a0 * a1.
    .section .text, "ax", @progbits
    .globl __mulsi3
    .type __mulsi3, @function
__mulsi3:
    mv t0, a0
    li a0, 0
1:
    beqz a1, 3f
    andi t1, a1, 1
    beqz t1, 2f
    add a0, a0, t0
2:
    slli t0, t0, 1
    srli a1, a1, 1
    j 1b
3:
    ret
    .size __mulsi3, .-__mulsi3
