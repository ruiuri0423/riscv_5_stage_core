.section .text
.globl _start

_start:
    # Test ADDI
    li t0, 0x1234
    li t1, 0x567
    addi t2, t0, 0x567    # t2 = t0 + 0x567 (adjusted immediate)
    li t3, 0x179B         # Golden value
    bne t2, t3, error     # Check result

    # Test SLTI
    li t0, 0x1234
    slti t2, t0, 0x567    # t2 = (t0 < 0x567) ? 1 : 0 (adjusted immediate)
    li t3, 0              # Golden value
    bne t2, t3, error     # Check result

    # Test SLTIU
    li t0, 0xFFFFFFFF
    sltiu t2, t0, 0x0    # t2 = (t0 < 0x0) ? 1 : 0
    li t3, 0             # Golden value
    bne t2, t3, error    # Check result

    # Test ANDI
    li t0, 0x1234
    andi t2, t0, 0x00FF  # t2 = t0 & 0x00FF
    li t3, 0x0034        # Golden value
    bne t2, t3, error    # Check result

    # Test ORI
    li t0, 0x1234
    ori t2, t0, 0x00FF   # t2 = t0 | 0x00FF
    li t3, 0x12FF        # Golden value
    bne t2, t3, error    # Check result

    # Test XORI
    li t0, 0x1234
    xori t2, t0, 0x00FF  # t2 = t0 ^ 0x00FF
    li t3, 0x12CB        # Golden value
    bne t2, t3, error    # Check result

    # Test SLLI
    li t0, 0x1234
    slli t2, t0, 4       # t2 = t0 << 4
    li t3, 0x12340       # Golden value
    bne t2, t3, error    # Check result

    # Test SRLI
    li t0, 0x1234
    srli t2, t0, 4       # t2 = t0 >> 4 (logical)
    li t3, 0x123         # Golden value
    bne t2, t3, error    # Check result

    # Test SRAI
    li t0, 0xFFFFF234    # Negative value
    srai t2, t0, 4       # t2 = t0 >> 4 (arithmetic)
    li t3, 0xFFFFFF23    # Precomputed value: 0xFFFFF234 >> 4 = 0xFFFFFF23
    bne t2, t3, error    # Check result

    # Second stage test with a complex immediate function
    li t0, 0x1234
    li t1, 0x5678
    addi t2, t0, 0x7FF     # t2 = t0 + 0x7FF (12-bit limited)
    andi t2, t2, 0x7FF     # t2 = t2 & 0x7FF (12-bit limited)
    ori t2, t2, 0x0F0      # t2 = t2 | 0x0F0 (12-bit limited)
    xori t2, t2, 0x0AA     # t2 = t2 ^ 0x0AA (12-bit limited)
    li t3, 0x259           # Golden value
    bne t2, t3, error      # Check result

    ## End of program
    nop
    nop
    j end

error:
    li t0, 0x12340000
    li t1, 0x0000FFFF
    csrw mscratch, t0
    csrs mscratch, t1

end:
    li t0, 0x00001234
    li t1, 0xFFFF0000
    csrw mscratch, t0
    csrs mscratch, t1
