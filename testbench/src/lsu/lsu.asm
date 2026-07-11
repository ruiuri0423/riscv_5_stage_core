
lsu.elf:     file format elf32-littleriscv


Disassembly of section .text:

ffff0000 <_start>:
ffff0000:	123452b7          	lui	t0,0x12345
ffff0004:	67828293          	addi	t0,t0,1656 # 12345678 <__text_size+0x12344678>
ffff0008:	ffff1337          	lui	t1,0xffff1
ffff000c:	00532023          	sw	t0,0(t1) # ffff1000 <end+0xf18>
ffff0010:	00032383          	lw	t2,0(t1)
ffff0014:	0c729063          	bne	t0,t2,ffff00d4 <error>
ffff0018:	000052b7          	lui	t0,0x5
ffff001c:	67828293          	addi	t0,t0,1656 # 5678 <__text_size+0x4678>
ffff0020:	ffff1337          	lui	t1,0xffff1
ffff0024:	01030313          	addi	t1,t1,16 # ffff1010 <end+0xf28>
ffff0028:	00531023          	sh	t0,0(t1)
ffff002c:	00031383          	lh	t2,0(t1)
ffff0030:	00005e37          	lui	t3,0x5
ffff0034:	678e0e13          	addi	t3,t3,1656 # 5678 <__text_size+0x4678>
ffff0038:	09c39e63          	bne	t2,t3,ffff00d4 <error>
ffff003c:	08800293          	li	t0,136
ffff0040:	ffff1337          	lui	t1,0xffff1
ffff0044:	01130313          	addi	t1,t1,17 # ffff1011 <end+0xf29>
ffff0048:	00530023          	sb	t0,0(t1)
ffff004c:	00030383          	lb	t2,0(t1)
ffff0050:	f8800e13          	li	t3,-120
ffff0054:	09c39063          	bne	t2,t3,ffff00d4 <error>
ffff0058:	000102b7          	lui	t0,0x10
ffff005c:	fff28293          	addi	t0,t0,-1 # ffff <__text_size+0xefff>
ffff0060:	ffff1337          	lui	t1,0xffff1
ffff0064:	02030313          	addi	t1,t1,32 # ffff1020 <end+0xf38>
ffff0068:	00531023          	sh	t0,0(t1)
ffff006c:	00035383          	lhu	t2,0(t1)
ffff0070:	06729263          	bne	t0,t2,ffff00d4 <error>
ffff0074:	0ff00293          	li	t0,255
ffff0078:	ffff1337          	lui	t1,0xffff1
ffff007c:	02130313          	addi	t1,t1,33 # ffff1021 <end+0xf39>
ffff0080:	00530023          	sb	t0,0(t1)
ffff0084:	00034383          	lbu	t2,0(t1)
ffff0088:	04729663          	bne	t0,t2,ffff00d4 <error>
ffff008c:	123452b7          	lui	t0,0x12345
ffff0090:	67828293          	addi	t0,t0,1656 # 12345678 <__text_size+0x12344678>
ffff0094:	ffff1337          	lui	t1,0xffff1
ffff0098:	03030313          	addi	t1,t1,48 # ffff1030 <end+0xf48>
ffff009c:	00532023          	sw	t0,0(t1)
ffff00a0:	00000393          	li	t2,0
ffff00a4:	00000e13          	li	t3,0

ffff00a8 <reconstruct_loop>:
ffff00a8:	00030e83          	lb	t4,0(t1)
ffff00ac:	01ce9eb3          	sll	t4,t4,t3
ffff00b0:	01d3e3b3          	or	t2,t2,t4
ffff00b4:	00130313          	addi	t1,t1,1
ffff00b8:	008e0e13          	addi	t3,t3,8
ffff00bc:	02000f13          	li	t5,32
ffff00c0:	ffee44e3          	blt	t3,t5,ffff00a8 <reconstruct_loop>
ffff00c4:	00539863          	bne	t2,t0,ffff00d4 <error>
ffff00c8:	00000013          	nop
ffff00cc:	00000013          	nop
ffff00d0:	0180006f          	j	ffff00e8 <end>

ffff00d4 <error>:
ffff00d4:	123402b7          	lui	t0,0x12340
ffff00d8:	00010337          	lui	t1,0x10
ffff00dc:	fff30313          	addi	t1,t1,-1 # ffff <__text_size+0xefff>
ffff00e0:	34029073          	csrw	mscratch,t0
ffff00e4:	34032073          	csrs	mscratch,t1

ffff00e8 <end>:
ffff00e8:	000012b7          	lui	t0,0x1
ffff00ec:	23428293          	addi	t0,t0,564 # 1234 <__text_size+0x234>
ffff00f0:	ffff0337          	lui	t1,0xffff0
ffff00f4:	34029073          	csrw	mscratch,t0
ffff00f8:	34032073          	csrs	mscratch,t1
	...
