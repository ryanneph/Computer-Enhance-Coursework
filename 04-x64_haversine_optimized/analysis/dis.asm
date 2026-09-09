
libhaversinecpp.so:     file format elf64-x86-64


Disassembly of section .init:

0000000000001000 <_init>:
    1000:	f3 0f 1e fa          	endbr64
    1004:	48 83 ec 08          	sub    rsp,0x8
    1008:	48 8b 05 e1 2f 00 00 	mov    rax,QWORD PTR [rip+0x2fe1]        ; 3ff0 <__gmon_start__@Base>
    100f:	48 85 c0             	test   rax,rax
    1012:	74 02                	je     1016 <_init+0x16>
    1014:	ff d0                	call   rax
    1016:	48 83 c4 08          	add    rsp,0x8
    101a:	c3                   	ret

Disassembly of section .plt:

0000000000001020 <sin@plt-0x10>:
    1020:	ff 35 e2 2f 00 00    	push   QWORD PTR [rip+0x2fe2]        ; 4008 <_GLOBAL_OFFSET_TABLE_+0x8>
    1026:	ff 25 e4 2f 00 00    	jmp    QWORD PTR [rip+0x2fe4]        ; 4010 <_GLOBAL_OFFSET_TABLE_+0x10>
    102c:	0f 1f 40 00          	nop    DWORD PTR [rax+0x0]

0000000000001030 <sin@plt>:
    1030:	ff 25 e2 2f 00 00    	jmp    QWORD PTR [rip+0x2fe2]        ; 4018 <sin@GLIBC_2.2.5>
    1036:	68 00 00 00 00       	push   0x0
    103b:	e9 e0 ff ff ff       	jmp    1020 <_init+0x20>

0000000000001040 <sqrt@plt>:
    1040:	ff 25 da 2f 00 00    	jmp    QWORD PTR [rip+0x2fda]        ; 4020 <sqrt@GLIBC_2.2.5>
    1046:	68 01 00 00 00       	push   0x1
    104b:	e9 d0 ff ff ff       	jmp    1020 <_init+0x20>

0000000000001050 <asin@plt>:
    1050:	ff 25 d2 2f 00 00    	jmp    QWORD PTR [rip+0x2fd2]        ; 4028 <asin@GLIBC_2.2.5>
    1056:	68 02 00 00 00       	push   0x2
    105b:	e9 c0 ff ff ff       	jmp    1020 <_init+0x20>

0000000000001060 <cos@plt>:
    1060:	ff 25 ca 2f 00 00    	jmp    QWORD PTR [rip+0x2fca]        ; 4030 <cos@GLIBC_2.2.5>
    1066:	68 03 00 00 00       	push   0x3
    106b:	e9 b0 ff ff ff       	jmp    1020 <_init+0x20>

Disassembly of section .plt.got:

0000000000001070 <__cxa_finalize@plt>:
    1070:	ff 25 6a 2f 00 00    	jmp    QWORD PTR [rip+0x2f6a]        ; 3fe0 <__cxa_finalize@GLIBC_2.2.5>
    1076:	66 90                	xchg   ax,ax

Disassembly of section .text:

0000000000001080 <deregister_tm_clones>:
    1080:	48 8d 3d b9 2f 00 00 	lea    rdi,[rip+0x2fb9]        ; 4040 <completed.0>
    1087:	48 8d 05 b2 2f 00 00 	lea    rax,[rip+0x2fb2]        ; 4040 <completed.0>
    108e:	48 39 f8             	cmp    rax,rdi
    1091:	74 15                	je     10a8 <deregister_tm_clones+0x28>
    1093:	48 8b 05 4e 2f 00 00 	mov    rax,QWORD PTR [rip+0x2f4e]        ; 3fe8 <_ITM_deregisterTMCloneTable@Base>
    109a:	48 85 c0             	test   rax,rax
    109d:	74 09                	je     10a8 <deregister_tm_clones+0x28>
    109f:	ff e0                	jmp    rax
    10a1:	0f 1f 80 00 00 00 00 	nop    DWORD PTR [rax+0x0]
    10a8:	c3                   	ret
    10a9:	0f 1f 80 00 00 00 00 	nop    DWORD PTR [rax+0x0]

00000000000010b0 <register_tm_clones>:
    10b0:	48 8d 3d 89 2f 00 00 	lea    rdi,[rip+0x2f89]        ; 4040 <completed.0>
    10b7:	48 8d 35 82 2f 00 00 	lea    rsi,[rip+0x2f82]        ; 4040 <completed.0>
    10be:	48 29 fe             	sub    rsi,rdi
    10c1:	48 89 f0             	mov    rax,rsi
    10c4:	48 c1 ee 3f          	shr    rsi,0x3f
    10c8:	48 c1 f8 03          	sar    rax,0x3
    10cc:	48 01 c6             	add    rsi,rax
    10cf:	48 d1 fe             	sar    rsi,1
    10d2:	74 14                	je     10e8 <register_tm_clones+0x38>
    10d4:	48 8b 05 1d 2f 00 00 	mov    rax,QWORD PTR [rip+0x2f1d]        ; 3ff8 <_ITM_registerTMCloneTable@Base>
    10db:	48 85 c0             	test   rax,rax
    10de:	74 08                	je     10e8 <register_tm_clones+0x38>
    10e0:	ff e0                	jmp    rax
    10e2:	66 0f 1f 44 00 00    	nop    WORD PTR [rax+rax*1+0x0]
    10e8:	c3                   	ret
    10e9:	0f 1f 80 00 00 00 00 	nop    DWORD PTR [rax+0x0]

00000000000010f0 <__do_global_dtors_aux>:
    10f0:	f3 0f 1e fa          	endbr64
    10f4:	80 3d 45 2f 00 00 00 	cmp    BYTE PTR [rip+0x2f45],0x0        ; 4040 <completed.0>
    10fb:	75 2b                	jne    1128 <__do_global_dtors_aux+0x38>
    10fd:	55                   	push   rbp
    10fe:	48 83 3d da 2e 00 00 	cmp    QWORD PTR [rip+0x2eda],0x0        ; 3fe0 <__cxa_finalize@GLIBC_2.2.5>
    1105:	00
    1106:	48 89 e5             	mov    rbp,rsp
    1109:	74 0c                	je     1117 <__do_global_dtors_aux+0x27>
    110b:	48 8b 3d 26 2f 00 00 	mov    rdi,QWORD PTR [rip+0x2f26]        ; 4038 <__dso_handle>
    1112:	e8 59 ff ff ff       	call   1070 <__cxa_finalize@plt>
    1117:	e8 64 ff ff ff       	call   1080 <deregister_tm_clones>
    111c:	c6 05 1d 2f 00 00 01 	mov    BYTE PTR [rip+0x2f1d],0x1        ; 4040 <completed.0>
    1123:	5d                   	pop    rbp
    1124:	c3                   	ret
    1125:	0f 1f 00             	nop    DWORD PTR [rax]
    1128:	c3                   	ret
    1129:	0f 1f 80 00 00 00 00 	nop    DWORD PTR [rax+0x0]

0000000000001130 <frame_dummy>:
    1130:	f3 0f 1e fa          	endbr64
    1134:	e9 77 ff ff ff       	jmp    10b0 <register_tm_clones>
    1139:	0f 1f 80 00 00 00 00 	nop    DWORD PTR [rax+0x0]

0000000000001140 <sqrt_intrin_cpp>:
    1140:	f2 0f 51 c0          	sqrtsd xmm0,xmm0
    1144:	c3                   	ret
    1145:	66 2e 0f 1f 84 00 00 	cs nop WORD PTR [rax+rax*1+0x0]
    114c:	00 00 00
    114f:	90                   	nop

0000000000001150 <sqrt_intrin_f32_cpp>:
    1150:	f2 0f 5a c0          	cvtsd2ss xmm0,xmm0
    1154:	f3 0f 51 c0          	sqrtss xmm0,xmm0
    1158:	f3 0f 5a c0          	cvtss2sd xmm0,xmm0
    115c:	c3                   	ret
    115d:	0f 1f 00             	nop    DWORD PTR [rax]

0000000000001160 <sqrt_intrin_rcp_cpp>:
    1160:	f2 0f 5a c0          	cvtsd2ss xmm0,xmm0
    1164:	f3 0f 52 c0          	rsqrtss xmm0,xmm0
    1168:	f3 0f 53 c0          	rcpss  xmm0,xmm0
    116c:	f3 0f 5a c0          	cvtss2sd xmm0,xmm0
    1170:	c3                   	ret
    1171:	66 2e 0f 1f 84 00 00 	cs nop WORD PTR [rax+rax*1+0x0]
    1178:	00 00 00
    117b:	0f 1f 44 00 00       	nop    DWORD PTR [rax+rax*1+0x0]

0000000000001180 <sinq_zero_to_pi_cpp>:
    1180:	66 0f 28 c8          	movapd xmm1,xmm0
    1184:	f2 0f 59 c8          	mulsd  xmm1,xmm0
    1188:	f2 0f 59 0d 70 0e 00 	mulsd  xmm1,QWORD PTR [rip+0xe70]        ; 2000 <_fini+0xab0>
    118f:	00
    1190:	f2 0f 59 05 70 0e 00 	mulsd  xmm0,QWORD PTR [rip+0xe70]        ; 2008 <_fini+0xab8>
    1197:	00
    1198:	f2 0f 58 c1          	addsd  xmm0,xmm1
    119c:	c3                   	ret
    119d:	0f 1f 00             	nop    DWORD PTR [rax]

00000000000011a0 <sinq_intrin_cpp>:
    11a0:	66 0f 28 c8          	movapd xmm1,xmm0
    11a4:	66 0f 57 db          	xorpd  xmm3,xmm3
    11a8:	66 0f 2e d8          	ucomisd xmm3,xmm0
    11ac:	66 0f 28 15 9c 0e 00 	movapd xmm2,XMMWORD PTR [rip+0xe9c]        ; 2050 <_fini+0xb00>
    11b3:	00
    11b4:	66 0f 28 e0          	movapd xmm4,xmm0
    11b8:	66 0f 57 e2          	xorpd  xmm4,xmm2
    11bc:	f2 0f c2 c3 01       	cmpltsd xmm0,xmm3
    11c1:	66 0f 54 e0          	andpd  xmm4,xmm0
    11c5:	66 0f 55 c1          	andnpd xmm0,xmm1
    11c9:	66 0f 56 c4          	orpd   xmm0,xmm4
    11cd:	66 0f 28 c8          	movapd xmm1,xmm0
    11d1:	f2 0f 59 c8          	mulsd  xmm1,xmm0
    11d5:	f2 0f 59 0d 23 0e 00 	mulsd  xmm1,QWORD PTR [rip+0xe23]        ; 2000 <_fini+0xab0>
    11dc:	00
    11dd:	f2 0f 59 05 23 0e 00 	mulsd  xmm0,QWORD PTR [rip+0xe23]        ; 2008 <_fini+0xab8>
    11e4:	00
    11e5:	f2 0f 58 c1          	addsd  xmm0,xmm1
    11e9:	76 04                	jbe    11ef <sinq_intrin_cpp+0x4f>
    11eb:	66 0f 57 c2          	xorpd  xmm0,xmm2
    11ef:	c3                   	ret

00000000000011f0 <cosq_intrin_cpp>:
    11f0:	66 0f 28 c8          	movapd xmm1,xmm0
    11f4:	f2 0f 58 0d 14 0e 00 	addsd  xmm1,QWORD PTR [rip+0xe14]        ; 2010 <_fini+0xac0>
    11fb:	00
    11fc:	66 0f 57 db          	xorpd  xmm3,xmm3
    1200:	66 0f 2e d9          	ucomisd xmm3,xmm1
    1204:	66 0f 28 15 44 0e 00 	movapd xmm2,XMMWORD PTR [rip+0xe44]        ; 2050 <_fini+0xb00>
    120b:	00
    120c:	66 0f 28 e1          	movapd xmm4,xmm1
    1210:	66 0f 57 e2          	xorpd  xmm4,xmm2
    1214:	66 0f 28 c1          	movapd xmm0,xmm1
    1218:	f2 0f c2 c3 01       	cmpltsd xmm0,xmm3
    121d:	66 0f 54 e0          	andpd  xmm4,xmm0
    1221:	66 0f 55 c1          	andnpd xmm0,xmm1
    1225:	66 0f 56 c4          	orpd   xmm0,xmm4
    1229:	66 0f 28 c8          	movapd xmm1,xmm0
    122d:	f2 0f 59 c8          	mulsd  xmm1,xmm0
    1231:	f2 0f 59 0d c7 0d 00 	mulsd  xmm1,QWORD PTR [rip+0xdc7]        ; 2000 <_fini+0xab0>
    1238:	00
    1239:	f2 0f 59 05 c7 0d 00 	mulsd  xmm0,QWORD PTR [rip+0xdc7]        ; 2008 <_fini+0xab8>
    1240:	00
    1241:	f2 0f 58 c1          	addsd  xmm0,xmm1
    1245:	76 04                	jbe    124b <cosq_intrin_cpp+0x5b>
    1247:	66 0f 57 c2          	xorpd  xmm0,xmm2
    124b:	c3                   	ret
    124c:	0f 1f 40 00          	nop    DWORD PTR [rax+0x0]

0000000000001250 <asin_intrin1_cpp>:
    1250:	66 0f 28 c8          	movapd xmm1,xmm0
    1254:	f2 0f 59 c8          	mulsd  xmm1,xmm0
    1258:	f2 0f 59 c8          	mulsd  xmm1,xmm0
    125c:	f2 0f 59 0d b4 0d 00 	mulsd  xmm1,QWORD PTR [rip+0xdb4]        ; 2018 <_fini+0xac8>
    1263:	00
    1264:	f2 0f 58 c1          	addsd  xmm0,xmm1
    1268:	c3                   	ret
    1269:	0f 1f 80 00 00 00 00 	nop    DWORD PTR [rax+0x0]

0000000000001270 <asin_intrin2_cpp>:
    1270:	f2 0f 10 15 a8 0d 00 	movsd  xmm2,QWORD PTR [rip+0xda8]        ; 2020 <_fini+0xad0>
    1277:	00
    1278:	f2 0f 5e d0          	divsd  xmm2,xmm0
    127c:	f2 0f 59 c0          	mulsd  xmm0,xmm0
    1280:	f2 0f 10 0d a0 0d 00 	movsd  xmm1,QWORD PTR [rip+0xda0]        ; 2028 <_fini+0xad8>
    1287:	00
    1288:	66 0f 28 d9          	movapd xmm3,xmm1
    128c:	f2 0f 5c d8          	subsd  xmm3,xmm0
    1290:	0f 57 c0             	xorps  xmm0,xmm0
    1293:	f2 0f 51 c3          	sqrtsd xmm0,xmm3
    1297:	f2 0f 5c c8          	subsd  xmm1,xmm0
    129b:	f2 0f 59 ca          	mulsd  xmm1,xmm2
    129f:	66 0f 28 c1          	movapd xmm0,xmm1
    12a3:	c3                   	ret
    12a4:	66 2e 0f 1f 84 00 00 	cs nop WORD PTR [rax+rax*1+0x0]
    12ab:	00 00 00
    12ae:	66 90                	xchg   ax,ax

00000000000012b0 <asin_intrin3_cpp>:
    12b0:	f2 0f 10 0d 70 0d 00 	movsd  xmm1,QWORD PTR [rip+0xd70]        ; 2028 <_fini+0xad8>
    12b7:	00
    12b8:	66 0f 28 d1          	movapd xmm2,xmm1
    12bc:	f2 0f 5e d0          	divsd  xmm2,xmm0
    12c0:	66 0f 28 d8          	movapd xmm3,xmm0
    12c4:	f2 0f 59 d8          	mulsd  xmm3,xmm0
    12c8:	66 0f 28 e1          	movapd xmm4,xmm1
    12cc:	f2 0f 5c e3          	subsd  xmm4,xmm3
    12d0:	0f 57 db             	xorps  xmm3,xmm3
    12d3:	f2 0f 51 dc          	sqrtsd xmm3,xmm4
    12d7:	f2 0f 5c cb          	subsd  xmm1,xmm3
    12db:	f2 0f 59 05 4d 0d 00 	mulsd  xmm0,QWORD PTR [rip+0xd4d]        ; 2030 <_fini+0xae0>
    12e2:	00
    12e3:	f2 0f 59 ca          	mulsd  xmm1,xmm2
    12e7:	f2 0f 58 c1          	addsd  xmm0,xmm1
    12eb:	f2 0f 59 05 1d 0d 00 	mulsd  xmm0,QWORD PTR [rip+0xd1d]        ; 2010 <_fini+0xac0>
    12f2:	00
    12f3:	c3                   	ret
    12f4:	66 2e 0f 1f 84 00 00 	cs nop WORD PTR [rax+rax*1+0x0]
    12fb:	00 00 00
    12fe:	66 90                	xchg   ax,ax

0000000000001300 <reference_haversine_cpp>:
    1300:	48 83 ec 28          	sub    rsp,0x28
    1304:	f2 0f 11 44 24 20    	movsd  QWORD PTR [rsp+0x20],xmm0
    130a:	f2 0f 10 4c 24 48    	movsd  xmm1,QWORD PTR [rsp+0x48]
    1310:	f2 0f 10 64 24 38    	movsd  xmm4,QWORD PTR [rsp+0x38]
    1316:	f2 0f 10 54 24 40    	movsd  xmm2,QWORD PTR [rsp+0x40]
    131c:	66 0f 28 c1          	movapd xmm0,xmm1
    1320:	66 0f 28 d9          	movapd xmm3,xmm1
    1324:	f2 0f 5c c4          	subsd  xmm0,xmm4
    1328:	f2 0f 10 0d 08 0d 00 	movsd  xmm1,QWORD PTR [rip+0xd08]        ; 2038 <_fini+0xae8>
    132f:	00
    1330:	f2 0f 59 c1          	mulsd  xmm0,xmm1
    1334:	f2 0f 5c 54 24 30    	subsd  xmm2,QWORD PTR [rsp+0x30]
    133a:	f2 0f 59 d1          	mulsd  xmm2,xmm1
    133e:	f2 0f 11 54 24 18    	movsd  QWORD PTR [rsp+0x18],xmm2
    1344:	f2 0f 59 e1          	mulsd  xmm4,xmm1
    1348:	f2 0f 11 24 24       	movsd  QWORD PTR [rsp],xmm4
    134d:	f2 0f 59 d9          	mulsd  xmm3,xmm1
    1351:	f2 0f 11 5c 24 08    	movsd  QWORD PTR [rsp+0x8],xmm3
    1357:	f2 0f 59 05 e1 0c 00 	mulsd  xmm0,QWORD PTR [rip+0xce1]        ; 2040 <_fini+0xaf0>
    135e:	00
    135f:	e8 cc fc ff ff       	call   1030 <sin@plt>
    1364:	f2 0f 59 c0          	mulsd  xmm0,xmm0
    1368:	f2 0f 11 44 24 10    	movsd  QWORD PTR [rsp+0x10],xmm0
    136e:	f2 0f 10 04 24       	movsd  xmm0,QWORD PTR [rsp]
    1373:	e8 e8 fc ff ff       	call   1060 <cos@plt>
    1378:	f2 0f 11 04 24       	movsd  QWORD PTR [rsp],xmm0
    137d:	f2 0f 10 44 24 08    	movsd  xmm0,QWORD PTR [rsp+0x8]
    1383:	e8 d8 fc ff ff       	call   1060 <cos@plt>
    1388:	f2 0f 59 04 24       	mulsd  xmm0,QWORD PTR [rsp]
    138d:	f2 0f 11 44 24 08    	movsd  QWORD PTR [rsp+0x8],xmm0
    1393:	f2 0f 10 44 24 18    	movsd  xmm0,QWORD PTR [rsp+0x18]
    1399:	f2 0f 59 05 9f 0c 00 	mulsd  xmm0,QWORD PTR [rip+0xc9f]        ; 2040 <_fini+0xaf0>
    13a0:	00
    13a1:	e8 8a fc ff ff       	call   1030 <sin@plt>
    13a6:	f2 0f 59 c0          	mulsd  xmm0,xmm0
    13aa:	f2 0f 59 44 24 08    	mulsd  xmm0,QWORD PTR [rsp+0x8]
    13b0:	f2 0f 58 44 24 10    	addsd  xmm0,QWORD PTR [rsp+0x10]
    13b6:	66 0f 57 c9          	xorpd  xmm1,xmm1
    13ba:	66 0f 2e c1          	ucomisd xmm0,xmm1
    13be:	72 06                	jb     13c6 <reference_haversine_cpp+0xc6>
    13c0:	f2 0f 51 c0          	sqrtsd xmm0,xmm0
    13c4:	eb 05                	jmp    13cb <reference_haversine_cpp+0xcb>
    13c6:	e8 75 fc ff ff       	call   1040 <sqrt@plt>
    13cb:	e8 80 fc ff ff       	call   1050 <asin@plt>
    13d0:	f2 0f 58 c0          	addsd  xmm0,xmm0
    13d4:	f2 0f 59 44 24 20    	mulsd  xmm0,QWORD PTR [rsp+0x20]
    13da:	48 83 c4 28          	add    rsp,0x28
    13de:	c3                   	ret
    13df:	90                   	nop

00000000000013e0 <reference_haversine_approx_cpp>:
    13e0:	66 0f 28 4c 24 08    	movapd xmm1,XMMWORD PTR [rsp+0x8]
    13e6:	66 0f 28 54 24 18    	movapd xmm2,XMMWORD PTR [rsp+0x18]
    13ec:	66 0f 28 e2          	movapd xmm4,xmm2
    13f0:	66 0f 5c e1          	subpd  xmm4,xmm1
    13f4:	66 0f 28 2d 64 0c 00 	movapd xmm5,XMMWORD PTR [rip+0xc64]        ; 2060 <_fini+0xb10>
    13fb:	00
    13fc:	66 0f 59 e5          	mulpd  xmm4,xmm5
    1400:	66 0f 15 ca          	unpckhpd xmm1,xmm2
    1404:	66 0f 59 25 64 0c 00 	mulpd  xmm4,XMMWORD PTR [rip+0xc64]        ; 2070 <_fini+0xb20>
    140b:	00
    140c:	66 0f 28 dc          	movapd xmm3,xmm4
    1410:	66 0f 15 dc          	unpckhpd xmm3,xmm4
    1414:	66 44 0f 28 05 33 0c 	movapd xmm8,XMMWORD PTR [rip+0xc33]        ; 2050 <_fini+0xb00>
    141b:	00 00
    141d:	66 0f 57 ff          	xorpd  xmm7,xmm7
    1421:	66 0f 28 f4          	movapd xmm6,xmm4
    1425:	66 0f c2 f7 01       	cmpltpd xmm6,xmm7
    142a:	66 0f 50 c6          	movmskpd eax,xmm6
    142e:	a8 02                	test   al,0x2
    1430:	74 05                	je     1437 <reference_haversine_approx_cpp+0x57>
    1432:	66 41 0f 57 d8       	xorpd  xmm3,xmm8
    1437:	66 0f 59 cd          	mulpd  xmm1,xmm5
    143b:	66 0f 28 d3          	movapd xmm2,xmm3
    143f:	f2 0f 59 d3          	mulsd  xmm2,xmm3
    1443:	f2 0f 10 35 b5 0b 00 	movsd  xmm6,QWORD PTR [rip+0xbb5]        ; 2000 <_fini+0xab0>
    144a:	00
    144b:	f2 0f 59 d6          	mulsd  xmm2,xmm6
    144f:	f2 0f 10 2d b1 0b 00 	movsd  xmm5,QWORD PTR [rip+0xbb1]        ; 2008 <_fini+0xab8>
    1456:	00
    1457:	f2 0f 59 dd          	mulsd  xmm3,xmm5
    145b:	f2 0f 58 da          	addsd  xmm3,xmm2
    145f:	74 05                	je     1466 <reference_haversine_approx_cpp+0x86>
    1461:	66 41 0f 57 d8       	xorpd  xmm3,xmm8
    1466:	66 0f 58 0d 12 0c 00 	addpd  xmm1,XMMWORD PTR [rip+0xc12]        ; 2080 <_fini+0xb30>
    146d:	00
    146e:	66 0f 28 d1          	movapd xmm2,xmm1
    1472:	66 0f c2 d7 01       	cmpltpd xmm2,xmm7
    1477:	66 0f 28 fa          	movapd xmm7,xmm2
    147b:	66 0f 55 f9          	andnpd xmm7,xmm1
    147f:	66 41 0f 57 c8       	xorpd  xmm1,xmm8
    1484:	66 0f 54 ca          	andpd  xmm1,xmm2
    1488:	66 0f 56 cf          	orpd   xmm1,xmm7
    148c:	66 0f 28 f9          	movapd xmm7,xmm1
    1490:	66 0f 59 f9          	mulpd  xmm7,xmm1
    1494:	66 0f 59 3d f4 0b 00 	mulpd  xmm7,XMMWORD PTR [rip+0xbf4]        ; 2090 <_fini+0xb40>
    149b:	00
    149c:	66 0f 59 0d fc 0b 00 	mulpd  xmm1,XMMWORD PTR [rip+0xbfc]        ; 20a0 <_fini+0xb50>
    14a3:	00
    14a4:	66 0f 58 cf          	addpd  xmm1,xmm7
    14a8:	66 0f 28 fa          	movapd xmm7,xmm2
    14ac:	66 0f 55 f9          	andnpd xmm7,xmm1
    14b0:	66 41 0f 57 c8       	xorpd  xmm1,xmm8
    14b5:	66 0f 54 ca          	andpd  xmm1,xmm2
    14b9:	66 0f 56 cf          	orpd   xmm1,xmm7
    14bd:	66 0f 70 f9 ee       	pshufd xmm7,xmm1,0xee
    14c2:	a8 01                	test   al,0x1
    14c4:	74 05                	je     14cb <reference_haversine_approx_cpp+0xeb>
    14c6:	66 41 0f 57 e0       	xorpd  xmm4,xmm8
    14cb:	f2 0f 59 db          	mulsd  xmm3,xmm3
    14cf:	f2 0f 59 cf          	mulsd  xmm1,xmm7
    14d3:	66 0f 28 d4          	movapd xmm2,xmm4
    14d7:	f2 0f 59 d4          	mulsd  xmm2,xmm4
    14db:	f2 0f 59 d6          	mulsd  xmm2,xmm6
    14df:	f2 0f 59 ec          	mulsd  xmm5,xmm4
    14e3:	f2 0f 58 ea          	addsd  xmm5,xmm2
    14e7:	74 05                	je     14ee <reference_haversine_approx_cpp+0x10e>
    14e9:	66 41 0f 57 e8       	xorpd  xmm5,xmm8
    14ee:	f2 0f 59 ed          	mulsd  xmm5,xmm5
    14f2:	f2 0f 59 cd          	mulsd  xmm1,xmm5
    14f6:	f2 0f 58 cb          	addsd  xmm1,xmm3
    14fa:	f2 0f 51 c9          	sqrtsd xmm1,xmm1
    14fe:	f2 0f 10 15 22 0b 00 	movsd  xmm2,QWORD PTR [rip+0xb22]        ; 2028 <_fini+0xad8>
    1505:	00
    1506:	66 0f 28 da          	movapd xmm3,xmm2
    150a:	f2 0f 5e d9          	divsd  xmm3,xmm1
    150e:	66 0f 28 e1          	movapd xmm4,xmm1
    1512:	f2 0f 59 e1          	mulsd  xmm4,xmm1
    1516:	66 0f 28 ea          	movapd xmm5,xmm2
    151a:	f2 0f 5c ec          	subsd  xmm5,xmm4
    151e:	0f 57 e4             	xorps  xmm4,xmm4
    1521:	f2 0f 51 e5          	sqrtsd xmm4,xmm5
    1525:	f2 0f 5c d4          	subsd  xmm2,xmm4
    1529:	f2 0f 59 d3          	mulsd  xmm2,xmm3
    152d:	f2 0f 59 0d fb 0a 00 	mulsd  xmm1,QWORD PTR [rip+0xafb]        ; 2030 <_fini+0xae0>
    1534:	00
    1535:	f2 0f 58 ca          	addsd  xmm1,xmm2
    1539:	f2 0f 59 0d cf 0a 00 	mulsd  xmm1,QWORD PTR [rip+0xacf]        ; 2010 <_fini+0xac0>
    1540:	00
    1541:	f2 0f 58 c9          	addsd  xmm1,xmm1
    1545:	f2 0f 59 c8          	mulsd  xmm1,xmm0
    1549:	66 0f 28 c1          	movapd xmm0,xmm1
    154d:	c3                   	ret

Disassembly of section .fini:

0000000000001550 <_fini>:
    1550:	f3 0f 1e fa          	endbr64
    1554:	48 83 ec 08          	sub    rsp,0x8
    1558:	48 83 c4 08          	add    rsp,0x8
    155c:	c3                   	ret
