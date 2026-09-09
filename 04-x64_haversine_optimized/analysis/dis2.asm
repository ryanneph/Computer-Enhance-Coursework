
libhaversinecpp.so:     file format elf64-x86-64


Disassembly of section .init:

<_init>:
	endbr64
	sub    rsp,0x8
	mov    rax,QWORD PTR [rip+0x2fe1]        ; <__gmon_start__@Base>
	test   rax,rax
	je     <_init+0x16>
	call   rax
	add    rsp,0x8
	ret

Disassembly of section .plt:

<sin@plt-0x10>:
	push   QWORD PTR [rip+0x2fe2]        ; <_GLOBAL_OFFSET_TABLE_+0x8>
	jmp    QWORD PTR [rip+0x2fe4]        ; <_GLOBAL_OFFSET_TABLE_+0x10>
	nop    DWORD PTR [rax+0x0]

<sin@plt>:
	jmp    QWORD PTR [rip+0x2fe2]        ; <sin@GLIBC_2.2.5>
	push   0x0
	jmp    <_init+0x20>

<sqrt@plt>:
	jmp    QWORD PTR [rip+0x2fda]        ; <sqrt@GLIBC_2.2.5>
	push   0x1
	jmp    <_init+0x20>

<asin@plt>:
	jmp    QWORD PTR [rip+0x2fd2]        ; <asin@GLIBC_2.2.5>
	push   0x2
	jmp    <_init+0x20>

<cos@plt>:
	jmp    QWORD PTR [rip+0x2fca]        ; <cos@GLIBC_2.2.5>
	push   0x3
	jmp    <_init+0x20>

Disassembly of section .plt.got:

<__cxa_finalize@plt>:
	jmp    QWORD PTR [rip+0x2f6a]        ; <__cxa_finalize@GLIBC_2.2.5>
	xchg   ax,ax

Disassembly of section .text:

<deregister_tm_clones>:
	lea    rdi,[rip+0x2fb9]        ; <completed.0>
	lea    rax,[rip+0x2fb2]        ; <completed.0>
	cmp    rax,rdi
	je     <deregister_tm_clones+0x28>
	mov    rax,QWORD PTR [rip+0x2f4e]        ; <_ITM_deregisterTMCloneTable@Base>
	test   rax,rax
	je     <deregister_tm_clones+0x28>
	jmp    rax
	nop    DWORD PTR [rax+0x0]
	ret
	nop    DWORD PTR [rax+0x0]

<register_tm_clones>:
	lea    rdi,[rip+0x2f89]        ; <completed.0>
	lea    rsi,[rip+0x2f82]        ; <completed.0>
	sub    rsi,rdi
	mov    rax,rsi
	shr    rsi,0x3f
	sar    rax,0x3
	add    rsi,rax
	sar    rsi,1
	je     <register_tm_clones+0x38>
	mov    rax,QWORD PTR [rip+0x2f1d]        ; <_ITM_registerTMCloneTable@Base>
	test   rax,rax
	je     <register_tm_clones+0x38>
	jmp    rax
	nop    WORD PTR [rax+rax*1+0x0]
	ret
	nop    DWORD PTR [rax+0x0]

<__do_global_dtors_aux>:
	endbr64
	cmp    BYTE PTR [rip+0x2f45],0x0        ; <completed.0>
	jne    <__do_global_dtors_aux+0x38>
	push   rbp
	cmp    QWORD PTR [rip+0x2eda],0x0        ; <__cxa_finalize@GLIBC_2.2.5>
	mov    rbp,rsp
	je     <__do_global_dtors_aux+0x27>
	mov    rdi,QWORD PTR [rip+0x2f26]        ; <__dso_handle>
	call   <__cxa_finalize@plt>
	call   <deregister_tm_clones>
	mov    BYTE PTR [rip+0x2f1d],0x1        ; <completed.0>
	pop    rbp
	ret
	nop    DWORD PTR [rax]
	ret
	nop    DWORD PTR [rax+0x0]

<frame_dummy>:
	endbr64
	jmp    <register_tm_clones>
	nop    DWORD PTR [rax+0x0]

<sqrt_intrin_cpp>:
	sqrtsd xmm0,xmm0
	ret
	cs nop WORD PTR [rax+rax*1+0x0]
	nop

<sqrt_intrin_f32_cpp>:
	cvtsd2ss xmm0,xmm0
	sqrtss xmm0,xmm0
	cvtss2sd xmm0,xmm0
	ret
	nop    DWORD PTR [rax]

<sqrt_intrin_rcp_cpp>:
	cvtsd2ss xmm0,xmm0
	rsqrtss xmm0,xmm0
	rcpss  xmm0,xmm0
	cvtss2sd xmm0,xmm0
	ret
	cs nop WORD PTR [rax+rax*1+0x0]
	nop    DWORD PTR [rax+rax*1+0x0]

<sinq_zero_to_pi_cpp>:
	movapd xmm1,xmm0
	mulsd  xmm1,xmm0
	mulsd  xmm1,QWORD PTR [rip+0xe70]        ; <_fini+0xab0>
	mulsd  xmm0,QWORD PTR [rip+0xe70]        ; <_fini+0xab8>
	addsd  xmm0,xmm1
	ret
	nop    DWORD PTR [rax]

<sinq_intrin_cpp>:
	movapd xmm1,xmm0
	xorpd  xmm3,xmm3
	ucomisd xmm3,xmm0
	movapd xmm2,XMMWORD PTR [rip+0xe9c]        ; <_fini+0xb00>
	movapd xmm4,xmm0
	xorpd  xmm4,xmm2
	cmpltsd xmm0,xmm3
	andpd  xmm4,xmm0
	andnpd xmm0,xmm1
	orpd   xmm0,xmm4
	movapd xmm1,xmm0
	mulsd  xmm1,xmm0
	mulsd  xmm1,QWORD PTR [rip+0xe23]        ; <_fini+0xab0>
	mulsd  xmm0,QWORD PTR [rip+0xe23]        ; <_fini+0xab8>
	addsd  xmm0,xmm1
	jbe    <sinq_intrin_cpp+0x4f>
	xorpd  xmm0,xmm2
	ret

<cosq_intrin_cpp>:
	movapd xmm1,xmm0
	addsd  xmm1,QWORD PTR [rip+0xe14]        ; <_fini+0xac0>
	xorpd  xmm3,xmm3
	ucomisd xmm3,xmm1
	movapd xmm2,XMMWORD PTR [rip+0xe44]        ; <_fini+0xb00>
	movapd xmm4,xmm1
	xorpd  xmm4,xmm2
	movapd xmm0,xmm1
	cmpltsd xmm0,xmm3
	andpd  xmm4,xmm0
	andnpd xmm0,xmm1
	orpd   xmm0,xmm4
	movapd xmm1,xmm0
	mulsd  xmm1,xmm0
	mulsd  xmm1,QWORD PTR [rip+0xdc7]        ; <_fini+0xab0>
	mulsd  xmm0,QWORD PTR [rip+0xdc7]        ; <_fini+0xab8>
	addsd  xmm0,xmm1
	jbe    <cosq_intrin_cpp+0x5b>
	xorpd  xmm0,xmm2
	ret
	nop    DWORD PTR [rax+0x0]

<asin_intrin1_cpp>:
	movapd xmm1,xmm0
	mulsd  xmm1,xmm0
	mulsd  xmm1,xmm0
	mulsd  xmm1,QWORD PTR [rip+0xdb4]        ; <_fini+0xac8>
	addsd  xmm0,xmm1
	ret
	nop    DWORD PTR [rax+0x0]

<asin_intrin2_cpp>:
	movsd  xmm2,QWORD PTR [rip+0xda8]        ; <_fini+0xad0>
	divsd  xmm2,xmm0
	mulsd  xmm0,xmm0
	movsd  xmm1,QWORD PTR [rip+0xda0]        ; <_fini+0xad8>
	movapd xmm3,xmm1
	subsd  xmm3,xmm0
	xorps  xmm0,xmm0
	sqrtsd xmm0,xmm3
	subsd  xmm1,xmm0
	mulsd  xmm1,xmm2
	movapd xmm0,xmm1
	ret
	cs nop WORD PTR [rax+rax*1+0x0]
	xchg   ax,ax

<asin_intrin3_cpp>:
	movsd  xmm1,QWORD PTR [rip+0xd70]        ; <_fini+0xad8>
	movapd xmm2,xmm1
	divsd  xmm2,xmm0
	movapd xmm3,xmm0
	mulsd  xmm3,xmm0
	movapd xmm4,xmm1
	subsd  xmm4,xmm3
	xorps  xmm3,xmm3
	sqrtsd xmm3,xmm4
	subsd  xmm1,xmm3
	mulsd  xmm0,QWORD PTR [rip+0xd4d]        ; <_fini+0xae0>
	mulsd  xmm1,xmm2
	addsd  xmm0,xmm1
	mulsd  xmm0,QWORD PTR [rip+0xd1d]        ; <_fini+0xac0>
	ret
	cs nop WORD PTR [rax+rax*1+0x0]
	xchg   ax,ax

<reference_haversine_cpp>:
	sub    rsp,0x28
	movsd  QWORD PTR [rsp+0x20],xmm0
	movsd  xmm1,QWORD PTR [rsp+0x48]
	movsd  xmm4,QWORD PTR [rsp+0x38]
	movsd  xmm2,QWORD PTR [rsp+0x40]
	movapd xmm0,xmm1
	movapd xmm3,xmm1
	subsd  xmm0,xmm4
	movsd  xmm1,QWORD PTR [rip+0xd08]        ; <_fini+0xae8>
	mulsd  xmm0,xmm1
	subsd  xmm2,QWORD PTR [rsp+0x30]
	mulsd  xmm2,xmm1
	movsd  QWORD PTR [rsp+0x18],xmm2
	mulsd  xmm4,xmm1
	movsd  QWORD PTR [rsp],xmm4
	mulsd  xmm3,xmm1
	movsd  QWORD PTR [rsp+0x8],xmm3
	mulsd  xmm0,QWORD PTR [rip+0xce1]        ; <_fini+0xaf0>
	call   <sin@plt>
	mulsd  xmm0,xmm0
	movsd  QWORD PTR [rsp+0x10],xmm0
	movsd  xmm0,QWORD PTR [rsp]
	call   <cos@plt>
	movsd  QWORD PTR [rsp],xmm0
	movsd  xmm0,QWORD PTR [rsp+0x8]
	call   <cos@plt>
	mulsd  xmm0,QWORD PTR [rsp]
	movsd  QWORD PTR [rsp+0x8],xmm0
	movsd  xmm0,QWORD PTR [rsp+0x18]
	mulsd  xmm0,QWORD PTR [rip+0xc9f]        ; <_fini+0xaf0>
	call   <sin@plt>
	mulsd  xmm0,xmm0
	mulsd  xmm0,QWORD PTR [rsp+0x8]
	addsd  xmm0,QWORD PTR [rsp+0x10]
	xorpd  xmm1,xmm1
	ucomisd xmm0,xmm1
	jb     <reference_haversine_cpp+0xc6>
	sqrtsd xmm0,xmm0
	jmp    <reference_haversine_cpp+0xcb>
	call   <sqrt@plt>
	call   <asin@plt>
	addsd  xmm0,xmm0
	mulsd  xmm0,QWORD PTR [rsp+0x20]
	add    rsp,0x28
	ret
	nop

<reference_haversine_approx_cpp>:
	movapd xmm1,XMMWORD PTR [rsp+0x8]
	movapd xmm2,XMMWORD PTR [rsp+0x18]
	movapd xmm4,xmm2
	subpd  xmm4,xmm1
	movapd xmm5,XMMWORD PTR [rip+0xc64]        ; <_fini+0xb10>
	mulpd  xmm4,xmm5
	unpckhpd xmm1,xmm2
	mulpd  xmm4,XMMWORD PTR [rip+0xc64]        ; <_fini+0xb20>
	movapd xmm3,xmm4
	unpckhpd xmm3,xmm4
	movapd xmm8,XMMWORD PTR [rip+0xc33]        ; <_fini+0xb00>
	xorpd  xmm7,xmm7
	movapd xmm6,xmm4
	cmpltpd xmm6,xmm7
	movmskpd eax,xmm6
	test   al,0x2
	je     <reference_haversine_approx_cpp+0x57>
	xorpd  xmm3,xmm8
	mulpd  xmm1,xmm5
	movapd xmm2,xmm3
	mulsd  xmm2,xmm3
	movsd  xmm6,QWORD PTR [rip+0xbb5]        ; <_fini+0xab0>
	mulsd  xmm2,xmm6
	movsd  xmm5,QWORD PTR [rip+0xbb1]        ; <_fini+0xab8>
	mulsd  xmm3,xmm5
	addsd  xmm3,xmm2
	je     <reference_haversine_approx_cpp+0x86>
	xorpd  xmm3,xmm8
	addpd  xmm1,XMMWORD PTR [rip+0xc12]        ; <_fini+0xb30>
	movapd xmm2,xmm1
	cmpltpd xmm2,xmm7
	movapd xmm7,xmm2
	andnpd xmm7,xmm1
	xorpd  xmm1,xmm8
	andpd  xmm1,xmm2
	orpd   xmm1,xmm7
	movapd xmm7,xmm1
	mulpd  xmm7,xmm1
	mulpd  xmm7,XMMWORD PTR [rip+0xbf4]        ; <_fini+0xb40>
	mulpd  xmm1,XMMWORD PTR [rip+0xbfc]        ; <_fini+0xb50>
	addpd  xmm1,xmm7
	movapd xmm7,xmm2
	andnpd xmm7,xmm1
	xorpd  xmm1,xmm8
	andpd  xmm1,xmm2
	orpd   xmm1,xmm7
	pshufd xmm7,xmm1,0xee
	test   al,0x1
	je     <reference_haversine_approx_cpp+0xeb>
	xorpd  xmm4,xmm8
	mulsd  xmm3,xmm3
	mulsd  xmm1,xmm7
	movapd xmm2,xmm4
	mulsd  xmm2,xmm4
	mulsd  xmm2,xmm6
	mulsd  xmm5,xmm4
	addsd  xmm5,xmm2
	je     <reference_haversine_approx_cpp+0x10e>
	xorpd  xmm5,xmm8
	mulsd  xmm5,xmm5
	mulsd  xmm1,xmm5
	addsd  xmm1,xmm3
	sqrtsd xmm1,xmm1
	movsd  xmm2,QWORD PTR [rip+0xb22]        ; <_fini+0xad8>
	movapd xmm3,xmm2
	divsd  xmm3,xmm1
	movapd xmm4,xmm1
	mulsd  xmm4,xmm1
	movapd xmm5,xmm2
	subsd  xmm5,xmm4
	xorps  xmm4,xmm4
	sqrtsd xmm4,xmm5
	subsd  xmm2,xmm4
	mulsd  xmm2,xmm3
	mulsd  xmm1,QWORD PTR [rip+0xafb]        ; <_fini+0xae0>
	addsd  xmm1,xmm2
	mulsd  xmm1,QWORD PTR [rip+0xacf]        ; <_fini+0xac0>
	addsd  xmm1,xmm1
	mulsd  xmm1,xmm0
	movapd xmm0,xmm1
	ret

Disassembly of section .fini:

<_fini>:
	endbr64
	sub    rsp,0x8
	add    rsp,0x8
	ret
