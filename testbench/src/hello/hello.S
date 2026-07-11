.section .text
.globl _start

_start:
    nop
    li t0, 0xaa55aa55     # Load immediate value 1 into register a0 (exit code) - Golden: t0 = 0xaa55aa55
    li t1, 0xFFFF1000     # Load immediate value 93 into register a7 (ECALL for exit) - Golden: t1 = 0xFFFF1000
    li t3, 0xbb44bb44
    sw t0, 0(t1)          # Store the register t0 to address t1 - Golden: Memory[t1] = 0xaa55aa55
    sw t0, 4(t1)          # Store the register t0 to address t1 + 4 - Golden: Memory[t1+4] = 0xaa55aa55
    sw t0, 8(t1)          # Store the register t0 to address t1 + 8 - Golden: Memory[t1+8] = 0xaa55aa55
    sw t0,12(t1)          # Store the register t0 to address t1 + 12 - Golden: Memory[t1+12] = 0xaa55aa55
    li t2, 0x0000a500     # Load immediate value 0x0000a500 into register t2 - Golden: t2 = 0x0000a500
    lw t2,12(t1)          # Load the register t2 from address t1 + 12 - Golden: t2 = 0xaa55aa55
    sw t3,12(t1)          # Store
    lw t2, 8(t1)          # Load the register t2 from address t1 +  8 - Golden: t2 = 0xaa55aa55
    sw t3, 8(t1)          # Store
    lw t2, 4(t1)          # Load the register t2 from address t1 +  4 - Golden: t2 = 0xaa55aa55
    sw t3, 4(t1)          # Store
    lw t2, 0(t1)          # Load the register t2 from address t1 +  0 - Golden: t2 = 0xaa55aa55
    sw t3, 0(t1)          # Store
    li t2, 0x00aa00aa     # Load the register t2 from address t1 +  8 - Golden: t2 = 0x00aa00aa
#--- Test the forward Unit : NOP insertion
    sw t2,16(t1)          # Store the register t0 to address t1 + 16 - Golden: Memory[t1+16] = 0x00aa00aa
#--- Test add/sub
    li t0, 0x000055aa     # Golden: t0 = 0x000055aa
    li t1, 0x55aa0000     # Golden: t1 = 0x55aa0000
    add t2, t1, t0        # Golden: t2 = 0x55aa55aa
    sub t2, t2, t0        # Read after write - Golden: t2 = 0x55aa0000
#--- Test basic R-type instructions
    li t0, 0x12345678     # Golden: t0 = 0x12345678
    li t1, 0x87654321     # Golden: t1 = 0x87654321
    add t2, t0, t1        # Add t0 and t1, store result in t2 - Golden: t2 = 0x99999999
    sub t3, t0, t1        # Subtract t1 from t0, store result in t3 - Golden: t3 = 0x8acf1357
    and t4, t0, t1        # Bitwise AND of t0 and t1, store result in t4 - Golden: t4 = 0x02244220
    or  t5, t0, t1        # Bitwise OR of t0 and t1, store result in t5 - Golden: t5 = 0x97755779
    xor t6, t0, t1        # Bitwise XOR of t0 and t1, store result in t6 - Golden: t6 = 0x95511559
    li t6, 5              # Load immediate value 5 into t6 (shift amount) - Golden: t6 = 0x00000005
    sll t6, t0, t6        # Logical left shift t0 by 5, store result in t6 - Golden: t6 = 0x468acf00
    srl t0, t1, t0        # Logical right shift t1 by the value in t0[4:0], store result in t0 - Golden: t0 = 0x00000087
    sra t1, t0, t1        # Arithmetic right shift t0 by the value in t1[4:0], store result in t1 - Golden: t1 = 0x00000043
#--- Test write after read
    nop
    nop
    nop
    li t0, 0x0000ffff     # Load immediate value 0x0000ffff into t0
    li t1, 0xffff0000     # Load immediate value 0xffff0000 into t1
    li t6, 0xffff1000     
    and t2, t0, t1        # Perform bitwise AND, store result in t2 - Golden: t2 = 0x00000000
    lw t3, 0(t6)          # Read memory at address t1 (0xFFFF0000) into t3
    or  t3, t0, t1        # Perform bitwise OR, store result in t3 - Golden: t3 = 0xffffffff
    lw t4, 4(t6)          # Read memory at address t1 + 4 (0xFFFF0004) into t4
    xor t4, t0, t1        # Perform bitwise XOR, store result in t4 - Golden: t4 = 0xffffffff
    lw t5, 8(t6)          # Read memory at address t1 + 8 (0xFFFF0008) into t5
    add t5, t0, t1        # Add t0 and t1, store result in t5 - Golden: t5 = 0xffffffff
    lw t6, 12(t6)         # Read memory at address t1 + 12 (0xFFFF000C) into t6
    sub t6, t5, t0        # Subtract t0 from t5, store result in t6 - Golden: t6 = 0xffff0000
    sll t0, t0, 8         # Logical left shift t0 by 8, store result in t0 - Golden: t0 = 0x00ffff00
    srl t1, t1, 16        # Logical right shift t1 by 16, store result in t1 - Golden: t1 = 0x0000ffff
    srl t2, t5, 8         # Arithmetic right shift t5 by 8, store result in t2 - Golden: t2 = 0xffffffff
