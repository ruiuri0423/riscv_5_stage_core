
imm.elf:     file format elf32-littleriscv


Disassembly of section .text:

ffff0000 <_start>:
ffff0000:	000012b7          	lui	t0,0x1
ffff0004:	23428293          	addi	t0,t0,564 # 1234 <__stack_size+0x234>
ffff0008:	56700313          	li	t1,1383
ffff000c:	56728393          	addi	t2,t0,1383
ffff0010:	00001e37          	lui	t3,0x1
ffff0014:	79be0e13          	addi	t3,t3,1947 # 179b <__stack_size+0x79b>
ffff0018:	0fc39063          	bne	t2,t3,ffff00f8 <error>
ffff001c:	000012b7          	lui	t0,0x1
ffff0020:	23428293          	addi	t0,t0,564 # 1234 <__stack_size+0x234>
ffff0024:	5672a393          	slti	t2,t0,1383
ffff0028:	00000e13          	li	t3,0
ffff002c:	0dc39663          	bne	t2,t3,ffff00f8 <error>
ffff0030:	fff00293          	li	t0,-1
ffff0034:	0002b393          	sltiu	t2,t0,0
ffff0038:	00000e13          	li	t3,0
ffff003c:	0bc39e63          	bne	t2,t3,ffff00f8 <error>
ffff0040:	000012b7          	lui	t0,0x1
ffff0044:	23428293          	addi	t0,t0,564 # 1234 <__stack_size+0x234>
ffff0048:	0ff2f393          	zext.b	t2,t0
ffff004c:	03400e13          	li	t3,52
ffff0050:	0bc39463          	bne	t2,t3,ffff00f8 <error>
ffff0054:	000012b7          	lui	t0,0x1
ffff0058:	23428293          	addi	t0,t0,564 # 1234 <__stack_size+0x234>
ffff005c:	0ff2e393          	ori	t2,t0,255
ffff0060:	00001e37          	lui	t3,0x1
ffff0064:	2ffe0e13          	addi	t3,t3,767 # 12ff <__stack_size+0x2ff>
ffff0068:	09c39863          	bne	t2,t3,ffff00f8 <error>
ffff006c:	000012b7          	lui	t0,0x1
ffff0070:	23428293          	addi	t0,t0,564 # 1234 <__stack_size+0x234>
ffff0074:	0ff2c393          	xori	t2,t0,255
ffff0078:	00001e37          	lui	t3,0x1
ffff007c:	2cbe0e13          	addi	t3,t3,715 # 12cb <__stack_size+0x2cb>
ffff0080:	07c39c63          	bne	t2,t3,ffff00f8 <error>
ffff0084:	000012b7          	lui	t0,0x1
ffff0088:	23428293          	addi	t0,t0,564 # 1234 <__stack_size+0x234>
ffff008c:	00429393          	slli	t2,t0,0x4
ffff0090:	00012e37          	lui	t3,0x12
ffff0094:	340e0e13          	addi	t3,t3,832 # 12340 <__stack_size+0x11340>
ffff0098:	07c39063          	bne	t2,t3,ffff00f8 <error>
ffff009c:	000012b7          	lui	t0,0x1
ffff00a0:	23428293          	addi	t0,t0,564 # 1234 <__stack_size+0x234>
ffff00a4:	0042d393          	srli	t2,t0,0x4
ffff00a8:	12300e13          	li	t3,291
ffff00ac:	05c39663          	bne	t2,t3,ffff00f8 <error>
ffff00b0:	fffff2b7          	lui	t0,0xfffff
ffff00b4:	23428293          	addi	t0,t0,564 # fffff234 <end+0xf128>
ffff00b8:	4042d393          	srai	t2,t0,0x4
ffff00bc:	f2300e13          	li	t3,-221
ffff00c0:	03c39c63          	bne	t2,t3,ffff00f8 <error>
ffff00c4:	000012b7          	lui	t0,0x1
ffff00c8:	23428293          	addi	t0,t0,564 # 1234 <__stack_size+0x234>
ffff00cc:	00005337          	lui	t1,0x5
ffff00d0:	67830313          	addi	t1,t1,1656 # 5678 <__stack_size+0x4678>
ffff00d4:	7ff28393          	addi	t2,t0,2047
ffff00d8:	7ff3f393          	andi	t2,t2,2047
ffff00dc:	0f03e393          	ori	t2,t2,240
ffff00e0:	0aa3c393          	xori	t2,t2,170
ffff00e4:	25900e13          	li	t3,601
ffff00e8:	01c39863          	bne	t2,t3,ffff00f8 <error>
ffff00ec:	00000013          	nop
ffff00f0:	00000013          	nop
ffff00f4:	0180006f          	j	ffff010c <end>

ffff00f8 <error>:
ffff00f8:	123402b7          	lui	t0,0x12340
ffff00fc:	00010337          	lui	t1,0x10
ffff0100:	fff30313          	addi	t1,t1,-1 # ffff <__stack_size+0xefff>
ffff0104:	34029073          	csrw	mscratch,t0
ffff0108:	34032073          	csrs	mscratch,t1

ffff010c <end>:
ffff010c:	000012b7          	lui	t0,0x1
ffff0110:	23428293          	addi	t0,t0,564 # 1234 <__stack_size+0x234>
ffff0114:	ffff0337          	lui	t1,0xffff0
ffff0118:	34029073          	csrw	mscratch,t0
ffff011c:	34032073          	csrs	mscratch,t1
