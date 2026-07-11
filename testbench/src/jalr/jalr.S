.section .text
.globl _start

_start:
    la sp, _eusrstack       # Initialize stack pointer
    addi sp, sp, -16        # Allocate stack space

    # Call print function to print "Hello, World!"
    la a0, hello_world      # Load address of the string into a0
    la t0, print            # Load address of the print function into t0
    jalr ra, t0             # Call the print function

    # Call print function to print "Hello, World!"
    la a0, hello_world      # Load address of the string into a0
    la t0, print            # Load address of the print function into t0
    jalr ra, t0             # Call the print function
    
    # Call print function to print "Hello, World!"
    la a0, hello_world      # Load address of the string into a0
    la t0, print            # Load address of the print function into t0
    jalr ra, t0             # Call the print function

    addi sp, sp, 16         # Deallocate stack space

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

print:
    ## Save caller-saved registers
    addi sp, sp, -12        # Allocate stack space
    sw ra, 8(sp)            # Save return address
    sw t0, 4(sp)            # Save temporary register t0
    sw t1, 0(sp)            # Save temporary register t1

print_loop:
    lbu t0, 0(a0)           # Load the next byte of the string
    beqz t0, print_done     # If null terminator, exit loop
    li t1, 0xFFFF2000       # Output device address
    sb t0, 0(t1)            # Write the byte to the output device
    addi a0, a0, 1          # Move to the next character
    j print_loop            # Repeat

print_done:
    ## Restore caller-saved registers
    lw ra, 8(sp)            # Restore return address
    lw t0, 4(sp)            # Restore temporary register t0
    lw t1, 0(sp)            # Restore temporary register t1
    addi sp, sp, 12         # Deallocate stack space
    jr ra                   # Return to caller

.section .data
hello_world:
    .asciz "Hello, World!"  # Null-terminated string
