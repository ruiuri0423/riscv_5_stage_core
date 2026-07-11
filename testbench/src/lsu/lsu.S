.section .text
.globl _start

_start:
    # Test lw (load word)
    li t0, 0x12345678       # Load word value into t0
    li t1, 0xFFFF1000       # Address within range
    sw t0, 0(t1)            # Store word at address
    lw t2, 0(t1)            # Load word from address
    bne t0, t2, error       # Check if written and read word values match

    # Test lh (load halfword signed) with signed-extension check
    li t0, 0x5678           # Load halfword value into t0
    li t1, 0xFFFF1010       # Address within range
    sh t0, 0(t1)            # Store halfword at address
    lh t2, 0(t1)            # Load halfword from address
    li t3, 0x00005678       # Expected signed-extended value
    bne t2, t3, error       # Check if read value matches golden data

    # Test lb (load byte signed) with signed-extension check
    li t0, 0x88             # Load byte value into t0
    li t1, 0xFFFF1011       # Address within range
    sb t0, 0(t1)            # Store byte at address
    lb t2, 0(t1)            # Load byte from address
    li t3, 0xFFFFFF88       # Expected signed-extended value
    bne t2, t3, error       # Check if read value matches golden data

    # Test lhu (load halfword unsigned)
    li t0, 0xFFFF           # Load unsigned halfword value into t0
    li t1, 0xFFFF1020       # Address within range
    sh t0, 0(t1)            # Store halfword at address
    lhu t2, 0(t1)           # Load unsigned halfword from address
    bne t0, t2, error       # Check if written and read unsigned halfword values match

    # Test lbu (load byte unsigned)
    li t0, 0xFF             # Load unsigned byte value into t0
    li t1, 0xFFFF1021       # Address within range
    sb t0, 0(t1)            # Store byte at address
    lbu t2, 0(t1)           # Load unsigned byte from address
    bne t0, t2, error       # Check if written and read unsigned byte values match

    # Test word store and byte load with reconstruction using a loop
    li t0, 0x12345678       # Load word value into t0
    li t1, 0xFFFF1030       # Address within range
    sw t0, 0(t1)            # Store word at address

    # Initialize loop variables
    li t2, 0                # Clear t2 for reconstruction
    li t3, 0                # Byte offset (0 to 3)

reconstruct_loop:
    lb t4, 0(t1)            # Load byte at offset
    sll t4, t4, t3          # Shift byte to its correct position using register
    or t2, t2, t4           # Concatenate byte into t2

    addi t1, t1, 1          # Increment address to next byte
    addi t3, t3, 8          # Increment shift amount by 8 bits
    li t5, 32               # Total shift amount (4 bytes * 8 bits)
    blt t3, t5, reconstruct_loop # Continue loop if not done

    # Compare reconstructed word with the original stored value
    bne t2, t0, error       # If mismatch, jump to error

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
