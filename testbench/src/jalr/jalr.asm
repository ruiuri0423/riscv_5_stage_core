
jalr.elf:     file format elf32-littleriscv


Disassembly of section .text:

ffff0000 <_start>:
ffff0000:	00002117          	auipc	sp,0x2
ffff0004:	00010113          	mv	sp,sp
ffff0008:	ff010113          	addi	sp,sp,-16 # ffff1ff0 <hello_world+0xff0>
ffff000c:	00001517          	auipc	a0,0x1
ffff0010:	ff450513          	addi	a0,a0,-12 # ffff1000 <hello_world>
ffff0014:	00000297          	auipc	t0,0x0
ffff0018:	06c28293          	addi	t0,t0,108 # ffff0080 <print>
ffff001c:	000280e7          	jalr	t0
ffff0020:	00001517          	auipc	a0,0x1
ffff0024:	fe050513          	addi	a0,a0,-32 # ffff1000 <hello_world>
ffff0028:	00000297          	auipc	t0,0x0
ffff002c:	05828293          	addi	t0,t0,88 # ffff0080 <print>
ffff0030:	000280e7          	jalr	t0
ffff0034:	00001517          	auipc	a0,0x1
ffff0038:	fcc50513          	addi	a0,a0,-52 # ffff1000 <hello_world>
ffff003c:	00000297          	auipc	t0,0x0
ffff0040:	04428293          	addi	t0,t0,68 # ffff0080 <print>
ffff0044:	000280e7          	jalr	t0
ffff0048:	01010113          	addi	sp,sp,16
ffff004c:	00000013          	nop
ffff0050:	00000013          	nop
ffff0054:	0180006f          	j	ffff006c <end>

ffff0058 <error>:
ffff0058:	123402b7          	lui	t0,0x12340
ffff005c:	00010337          	lui	t1,0x10
ffff0060:	fff30313          	addi	t1,t1,-1 # ffff <__text_size+0xefff>
ffff0064:	34029073          	csrw	mscratch,t0
ffff0068:	34032073          	csrs	mscratch,t1

ffff006c <end>:
ffff006c:	000012b7          	lui	t0,0x1
ffff0070:	23428293          	addi	t0,t0,564 # 1234 <__text_size+0x234>
ffff0074:	ffff0337          	lui	t1,0xffff0
ffff0078:	34029073          	csrw	mscratch,t0
ffff007c:	34032073          	csrs	mscratch,t1

ffff0080 <print>:
ffff0080:	ff410113          	addi	sp,sp,-12
ffff0084:	00112423          	sw	ra,8(sp)
ffff0088:	00512223          	sw	t0,4(sp)
ffff008c:	00612023          	sw	t1,0(sp)

ffff0090 <print_loop>:
ffff0090:	00054283          	lbu	t0,0(a0)
ffff0094:	00028a63          	beqz	t0,ffff00a8 <print_done>
ffff0098:	ffff2337          	lui	t1,0xffff2
ffff009c:	00530023          	sb	t0,0(t1) # ffff2000 <_eusrstack>
ffff00a0:	00150513          	addi	a0,a0,1
ffff00a4:	fedff06f          	j	ffff0090 <print_loop>

ffff00a8 <print_done>:
ffff00a8:	00812083          	lw	ra,8(sp)
ffff00ac:	00412283          	lw	t0,4(sp)
ffff00b0:	00012303          	lw	t1,0(sp)
ffff00b4:	00c10113          	addi	sp,sp,12
ffff00b8:	00008067          	ret
	...
