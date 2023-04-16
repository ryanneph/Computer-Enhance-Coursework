#import "Basic";
#import "Process";

#load "file.jai";
#load "test.jai";

DEBUG_DECODE := true;
DEBUG_EXEC   := true;
DEBUG_TEST   := false;
formatHex :: #bake_arguments formatInt(base=16);

Memory_Region :: []u8;

Processor_State :: struct {
    register_memory: [26]u8;
    memory: [1024 * 1024]u8;
    ip: s64;
    flags: Flag;
}

Flag :: enum_flags {
    CARRY;
    PARITY;
    AUX_CARRY;
    ZERO;
    SIGN;
    OVERFLOW;
    INT_ENABLE;
    DIRECTION;
    TRAP;
}
Register :: enum {
    INVALID :: 0;

    FIRST_REGISTER :: 1;
    AL :: FIRST_REGISTER; AX; CL; CX; DL; DX; BL; BX; AH; SP; CH; BP; DH; SI; BH; DI;

    FIRST_SEGMENT;
    ES :: FIRST_SEGMENT; CS; SS; DS; // 16-bit segment registers

    FLAG; // 16-bit flag register (LSB 9-bits used)
}
Register_Definition :: struct {
    name: string;
    offset: u8;
    size:   u8;
}
Registers :: struct {
    // addressed by field_reg(3-bit) | field_w(1-bit)
    defs: [21]Register_Definition;

    defs[Register.AL   - Register.FIRST_REGISTER] = .{"al",     0, 1};
    defs[Register.AX   - Register.FIRST_REGISTER] = .{"ax",     0, 2};
    defs[Register.CL   - Register.FIRST_REGISTER] = .{"cl",     4, 1};
    defs[Register.CX   - Register.FIRST_REGISTER] = .{"cx",     4, 2};
    defs[Register.DL   - Register.FIRST_REGISTER] = .{"dl",     6, 1};
    defs[Register.DX   - Register.FIRST_REGISTER] = .{"dx",     6, 2};
    defs[Register.BL   - Register.FIRST_REGISTER] = .{"bl",     2, 1};
    defs[Register.BX   - Register.FIRST_REGISTER] = .{"bx",     2, 2};
    defs[Register.AH   - Register.FIRST_REGISTER] = .{"ah",     1, 1};
    defs[Register.SP   - Register.FIRST_REGISTER] = .{"sp",     8, 2};
    defs[Register.CH   - Register.FIRST_REGISTER] = .{"ch",     5, 1};
    defs[Register.BP   - Register.FIRST_REGISTER] = .{"bp",    10, 2};
    defs[Register.DH   - Register.FIRST_REGISTER] = .{"dh",     7, 1};
    defs[Register.SI   - Register.FIRST_REGISTER] = .{"si",    12, 2};
    defs[Register.BH   - Register.FIRST_REGISTER] = .{"bh",     3, 1};
    defs[Register.DI   - Register.FIRST_REGISTER] = .{"di",    14, 2};

    defs[Register.ES   - Register.FIRST_REGISTER] = .{"es",    16, 2};
    defs[Register.CS   - Register.FIRST_REGISTER] = .{"cs",    18, 2};
    defs[Register.SS   - Register.FIRST_REGISTER] = .{"ss",    20, 2};
    defs[Register.DS   - Register.FIRST_REGISTER] = .{"ds",    22, 2};

    defs[Register.FLAG - Register.FIRST_REGISTER] = .{"flags", 24, 2};
}
registers: Registers;

register :: (field_reg: u8, field_word: u8) -> Register {
    assert(field_word <= 1);
    index := (field_reg << 1) | field_word;
    assert(index < registers.defs.count);

    return cast(Register)(cast(s32)Register.FIRST_REGISTER + index);
}
register_def :: (reg: Register) -> Register_Definition {
    assert(reg != .INVALID);
    register_index := cast(s32)reg - cast(s32)Register.FIRST_REGISTER;
    assert(register_index < registers.defs.count);
    return registers.defs[register_index];
}
segment :: inline (field_seg: u8) -> Register {
    assert(field_seg < 4);
    return cast(Register)(cast(s32)Register.FIRST_SEGMENT + field_seg);
}

Memory_Mode :: enum {
    INVALID :: 0;
    NO_DISP;
    DISP_U8;
    DISP_U16;
    DIRECT;
}

Memory :: struct  {
    mode: Memory_Mode;
    word: bool; // true: 16-bit, false: 8-bit
    union {
        struct {
            reg1: Register;
            reg2: Register;
            disp: u16;
        };
        direct: u16;
    };
}
Immediate :: struct {
    val: u16;
}
Increment :: struct {
    val: s16;
}
Operand_Type :: enum {
    INVALID;
    REGISTER;
    MEMORY;
    IMMEDIATE;
    INCREMENT;
}
Operand :: struct {
    type: Operand_Type;
    union {
        reg: Register;
        mem: Memory;
        imm: Immediate;
        inc: Increment;
    };

    // prepended to operand (such as immediate ip) if instruction has flags & .FAR_SEGMENT
    far_segment: u16;
}

// TODO(ryan): Hook the compilation-loop and populate the matched-index table automatically
Instruction_Type :: enum u32 {
    INVALID :: 0;
    AAA;          // @mnemonic:aaa
    AAD;          // @mnemonic:aad
    AAM;          // @mnemonic:aam
    AAS;          // @mnemonic:aas
    ADC;          // @mnemonic:adc
    ADD;          // @mnemonic:add
    AND;          // @mnemonic:and
    CALL;         // @mnemonic:call
    CALLF;        // @mnemonic:call far
    CBW;          // @mnemonic:cbw
    CLC;          // @mnemonic:clc
    CLD;          // @mnemonic:cld
    CLI;          // @mnemonic:cli
    CMC;          // @mnemonic:cmc
    CMP;          // @mnemonic:cmp
    CMPS;         // @mnemonic:cmps
    CWD;          // @mnemonic:cwd
    DAA;          // @mnemonic:daa
    DAS;          // @mnemonic:das
    DEC;          // @mnemonic:dec
    DIV;          // @mnemonic:div
    HLT;          // @mnemonic:hlt
    IDIV;         // @mnemonic:idiv
    IMUL;         // @mnemonic:imul
    IN;           // @mnemonic:in
    INC;          // @mnemonic:inc
    INT3;         // @mnemonic:int3
    INT;          // @mnemonic:int
    INTO;         // @mnemonic:into
    IRET;         // @mnemonic:iret
    JBE_JNA;      // @mnemonic:jbe
    JB_JNAE_JC;   // @mnemonic:jb
    JCXZ;         // @mnemonic:jcxz
    JE_JZ;        // @mnemonic:je
    JLE_JNG;      // @mnemonic:jle
    JL_JNGE;      // @mnemonic:jl
    JMP;          // @mnemonic:jmp
    JMPF;         // @mnemonic:jmp far
    JNBE_JA;      // @mnemonic:ja
    JNB_JAE_JNC;  // @mnemonic:jnb
    JNE_JNZ;      // @mnemonic:jne
    JNLE_JG;      // @mnemonic:jg
    JNL_JGE;      // @mnemonic:jge
    JNO;          // @mnemonic:jno
    JNP_JPO;      // @mnemonic:jnp
    JNS;          // @mnemonic:jns
    JO;           // @mnemonic:jo
    JP_JPE;       // @mnemonic:jp
    JS;           // @mnemonic:js
    LAHF;         // @mnemonic:lahf
    LDS;          // @mnemonic:lds
    LEA;          // @mnemonic:lea
    LES;          // @mnemonic:les
    LODS;         // @mnemonic:lods
    LOOP;         // @mnemonic:loop
    LOOPNZ;       // @mnemonic:loopnz
    LOOPZ;        // @mnemonic:loopz
    MOV;          // @mnemonic:mov
    MOVS;         // @mnemonic:movs
    MUL;          // @mnemonic:mul
    NEG;          // @mnemonic:neg
    NOT;          // @mnemonic:not
    OR;           // @mnemonic:or
    OUT;          // @mnemonic:out
    POP;          // @mnemonic:pop
    POPF;         // @mnemonic:popf
    PUSH;         // @mnemonic:push
    PUSHF;        // @mnemonic:pushf
    RCL;          // @mnemonic:rcl
    RCR;          // @mnemonic:rcr
    RET;          // @mnemonic:ret
    RETF;         // @mnemonic:retf
    ROL;          // @mnemonic:rol
    ROR;          // @mnemonic:ror
    SAHF;         // @mnemonic:sahf
    SAR;          // @mnemonic:sar
    SBB;          // @mnemonic:sbb
    SCAS;         // @mnemonic:scas
    SHL;          // @mnemonic:shl
    SHR;          // @mnemonic:shr
    STC;          // @mnemonic:stc
    STD;          // @mnemonic:std
    STI;          // @mnemonic:sti
    STOS;         // @mnemonic:stos
    SUB;          // @mnemonic:sub
    TEST;         // @mnemonic:test
    WAIT;         // @mnemonic:wait
    XCHG;         // @mnemonic:xchg
    XLAT;         // @mnemonic:xlat
    XOR;          // @mnemonic:xor
    _ENUM_COUNT;
}
Mnemonic_Table :: struct {
    strings: [Instruction_Type._ENUM_COUNT]string;
    strings[Instruction_Type.AAA]         = "aaa";
    strings[Instruction_Type.AAD]         = "aad";
    strings[Instruction_Type.AAM]         = "aam";
    strings[Instruction_Type.AAS]         = "aas";
    strings[Instruction_Type.ADC]         = "adc";
    strings[Instruction_Type.ADD]         = "add";
    strings[Instruction_Type.AND]         = "and";
    strings[Instruction_Type.CALL]        = "call";
    strings[Instruction_Type.CALLF]       = "call far";
    strings[Instruction_Type.CBW]         = "cbw";
    strings[Instruction_Type.CLC]         = "clc";
    strings[Instruction_Type.CLD]         = "cld";
    strings[Instruction_Type.CLI]         = "cli";
    strings[Instruction_Type.CMC]         = "cmc";
    strings[Instruction_Type.CMPS]        = "cmps";
    strings[Instruction_Type.CMP]         = "cmp";
    strings[Instruction_Type.CWD]         = "cwd";
    strings[Instruction_Type.DAA]         = "daa";
    strings[Instruction_Type.DAS]         = "das";
    strings[Instruction_Type.DEC]         = "dec";
    strings[Instruction_Type.DIV]         = "div";
    strings[Instruction_Type.HLT]         = "hlt";
    strings[Instruction_Type.IDIV]        = "idiv";
    strings[Instruction_Type.IMUL]        = "imul";
    strings[Instruction_Type.INC]         = "inc";
    strings[Instruction_Type.INT3]        = "int3";
    strings[Instruction_Type.INTO]        = "into";
    strings[Instruction_Type.INT]         = "int";
    strings[Instruction_Type.IN]          = "in";
    strings[Instruction_Type.IRET]        = "iret";
    strings[Instruction_Type.JBE_JNA]     = "jbe";
    strings[Instruction_Type.JB_JNAE_JC]  = "jb";
    strings[Instruction_Type.JCXZ]        = "jcxz";
    strings[Instruction_Type.JE_JZ]       = "je";
    strings[Instruction_Type.JLE_JNG]     = "jle";
    strings[Instruction_Type.JL_JNGE]     = "jl";
    strings[Instruction_Type.JMP]         = "jmp";
    strings[Instruction_Type.JMPF]        = "jmp far";
    strings[Instruction_Type.JNBE_JA]     = "ja";
    strings[Instruction_Type.JNB_JAE_JNC] = "jnb";
    strings[Instruction_Type.JNE_JNZ]     = "jne";
    strings[Instruction_Type.JNLE_JG]     = "jg";
    strings[Instruction_Type.JNL_JGE]     = "jge";
    strings[Instruction_Type.JNO]         = "jno";
    strings[Instruction_Type.JNP_JPO]     = "jnp";
    strings[Instruction_Type.JNS]         = "jns";
    strings[Instruction_Type.JO]          = "jo";
    strings[Instruction_Type.JP_JPE]      = "jp";
    strings[Instruction_Type.JS]          = "js";
    strings[Instruction_Type.LAHF]        = "lahf";
    strings[Instruction_Type.LDS]         = "lds";
    strings[Instruction_Type.LEA]         = "lea";
    strings[Instruction_Type.LES]         = "les";
    strings[Instruction_Type.LODS]        = "lods";
    strings[Instruction_Type.LOOPNZ]      = "loopnz";
    strings[Instruction_Type.LOOPZ]       = "loopz";
    strings[Instruction_Type.LOOP]        = "loop";
    strings[Instruction_Type.MOVS]        = "movs";
    strings[Instruction_Type.MOV]         = "mov";
    strings[Instruction_Type.MUL]         = "mul";
    strings[Instruction_Type.NEG]         = "neg";
    strings[Instruction_Type.NOT]         = "not";
    strings[Instruction_Type.OR]          = "or";
    strings[Instruction_Type.OUT]         = "out";
    strings[Instruction_Type.POPF]        = "popf";
    strings[Instruction_Type.POP]         = "pop";
    strings[Instruction_Type.PUSHF]       = "pushf";
    strings[Instruction_Type.PUSH]        = "push";
    strings[Instruction_Type.RCL]         = "rcl";
    strings[Instruction_Type.RCR]         = "rcr";
    strings[Instruction_Type.RET]         = "ret";
    strings[Instruction_Type.RETF]        = "retf";
    strings[Instruction_Type.ROL]         = "rol";
    strings[Instruction_Type.ROR]         = "ror";
    strings[Instruction_Type.SAHF]        = "sahf";
    strings[Instruction_Type.SAR]         = "sar";
    strings[Instruction_Type.SBB]         = "sbb";
    strings[Instruction_Type.SCAS]        = "scas";
    strings[Instruction_Type.SHL]         = "shl";
    strings[Instruction_Type.SHR]         = "shr";
    strings[Instruction_Type.STC]         = "stc";
    strings[Instruction_Type.STD]         = "std";
    strings[Instruction_Type.STI]         = "sti";
    strings[Instruction_Type.STOS]        = "stos";
    strings[Instruction_Type.SUB]         = "sub";
    strings[Instruction_Type.TEST]        = "test";
    strings[Instruction_Type.WAIT]        = "wait";
    strings[Instruction_Type.XCHG]        = "xchg";
    strings[Instruction_Type.XLAT]        = "xlat";
    strings[Instruction_Type.XOR]         = "xor";
}
mnemonic_table: Mnemonic_Table;
mnemonic_string :: inline (type: Instruction_Type) -> string {
    assert(type != .INVALID, "invalid instruction type");
    assert(cast(s64)type < mnemonic_table.strings.count);
    mnemonic :=  mnemonic_table.strings[type];
    assert(mnemonic.count > 0, "mnemonic string not defined for Instruction_Type.%\n", type);
    return mnemonic;
}

Operand_Count :: enum {
    ZERO    :: 0;
    UNARY   :: 1;
    BINARY  :: 2;
}

Instruction_Flags :: enum_flags u32 {
    REPEAT_ZERO;
    REPEAT_NOTZERO;

    STRING_BYTE;
    STRING_WORD;

    SEGMENT_OVERRIDE; // memory expression has segement register prefix (e.g. "cmp cx, [es:bp]")
    FAR_SEGMENT;      // immediate has segment address prefix (e.g. "call 123:456")
    LOCK;
}

Instruction :: struct {
    type: Instruction_Type;
    operand_count := Operand_Count.BINARY;
    mode: Memory_Mode;
    flags: Instruction_Flags;
    explicit_size: bool; // requires explicit operand size prefix ("byte"/"word")
    size: u32; // of encoded instruction

    segment_override: Register;

    desc: string;

    // For single operand instructions, only dst is used
    dst: Operand;
    src: Operand;
}

Decode_Proc :: #type (inst: *Instruction, head: *u8) -> (advance_count: s32);
Opcode_Info :: struct {
    decode: Decode_Proc;
    type:   Instruction_Type;
}

// NOTE(ryan): jai only supports indexed sparse initialization of arrays *inside structs* for now.
Opcode_Table :: struct {
    ops: [256]Opcode_Info;

    assign_op_info_range :: (first: u8, last: u8, op_info_string: string) -> string {
        builder: String_Builder;
        for opcode: first..last
            print_to_builder(*builder, "ops[%] = %;\n", opcode, op_info_string);
        return builder_to_string(*builder);
    }
    #insert #run assign_op_info_range(0x9A, 0x9A, ".{ decode_jump_direct_far,      .CALL,        }");
    #insert #run assign_op_info_range(0xEA, 0xEA, ".{ decode_jump_direct_far,      .JMP,         }");

    #insert #run assign_op_info_range(0x04, 0x05, ".{ decode_arith_imm_to_accum,   .ADD,         }");
    #insert #run assign_op_info_range(0x0C, 0x0D, ".{ decode_arith_imm_to_accum,   .OR,          }");
    #insert #run assign_op_info_range(0x34, 0x35, ".{ decode_arith_imm_to_accum,   .XOR,         }");
    #insert #run assign_op_info_range(0x14, 0x15, ".{ decode_arith_imm_to_accum,   .ADC,         }");
    #insert #run assign_op_info_range(0x1C, 0x1D, ".{ decode_arith_imm_to_accum,   .SBB,         }");
    #insert #run assign_op_info_range(0x24, 0x25, ".{ decode_arith_imm_to_accum,   .AND,         }");
    #insert #run assign_op_info_range(0x2C, 0x2D, ".{ decode_arith_imm_to_accum,   .SUB,         }");
    #insert #run assign_op_info_range(0x3C, 0x3D, ".{ decode_arith_imm_to_accum,   .CMP,         }");
    #insert #run assign_op_info_range(0xA8, 0xA9, ".{ decode_arith_imm_to_accum,   .TEST         }");
    #insert #run assign_op_info_range(0x80, 0x83, ".{ decode_arith_imm_to_rm,      .INVALID,     }");
    #insert #run assign_op_info_range(0x90, 0x97, ".{ decode_arith_reg_with_accum, .XCHG,        }");
    #insert #run assign_op_info_range(0xD0, 0xD3, ".{ decode_bit_ops,              .INVALID,     }");
    #insert #run assign_op_info_range(0xE8, 0xE8, ".{ decode_call_direct_in_seg,   .CALL,        }");
    #insert #run assign_op_info_range(0xE9, 0xE9, ".{ decode_call_direct_in_seg,   .JMP,         }");
    #insert #run assign_op_info_range(0xEB, 0xEB, ".{ decode_call_direct_in_seg,   .JMP,         }");
    #insert #run assign_op_info_range(0xE4, 0xE7, ".{ decode_in_out,               .INVALID,     }");
    #insert #run assign_op_info_range(0xEC, 0xEF, ".{ decode_in_out,               .INVALID,     }");
    #insert #run assign_op_info_range(0x70, 0x7F, ".{ decode_jump_cond_inc8,       .INVALID,     }");
    #insert #run assign_op_info_range(0xE0, 0xE3, ".{ decode_jump_cond_inc8,       .INVALID,     }");
    #insert #run assign_op_info_range(0x8D, 0x8D, ".{ decode_load_to_reg_seg,      .LEA,         }");
    #insert #run assign_op_info_range(0xC4, 0xC4, ".{ decode_load_to_reg_seg,      .LES,         }");
    #insert #run assign_op_info_range(0xC5, 0xC5, ".{ decode_load_to_reg_seg,      .LDS,         }");
    #insert #run assign_op_info_range(0xA0, 0xA3, ".{ decode_mov_accumulator,      .MOV,         }");
    #insert #run assign_op_info_range(0xB0, 0xBF, ".{ decode_mov_imm_to_reg,       .MOV,         }");
    #insert #run assign_op_info_range(0xC6, 0xC7, ".{ decode_mov_imm_to_rm,        .MOV,         }");
    #insert #run assign_op_info_range(0x27, 0x27, ".{ decode_no_operands,          .DAA,         }");
    #insert #run assign_op_info_range(0x2F, 0x2F, ".{ decode_no_operands,          .DAS,         }");
    #insert #run assign_op_info_range(0x37, 0x37, ".{ decode_no_operands,          .AAA,         }");
    #insert #run assign_op_info_range(0x3F, 0x3F, ".{ decode_no_operands,          .AAS,         }");
    #insert #run assign_op_info_range(0x98, 0x98, ".{ decode_no_operands,          .CBW,         }");
    #insert #run assign_op_info_range(0x99, 0x99, ".{ decode_no_operands,          .CWD,         }");
    #insert #run assign_op_info_range(0x9B, 0x9B, ".{ decode_no_operands,          .WAIT,        }");
    #insert #run assign_op_info_range(0x9C, 0x9C, ".{ decode_no_operands,          .PUSHF,       }");
    #insert #run assign_op_info_range(0x9D, 0x9D, ".{ decode_no_operands,          .POPF,        }");
    #insert #run assign_op_info_range(0x9E, 0x9E, ".{ decode_no_operands,          .SAHF,        }");
    #insert #run assign_op_info_range(0x9F, 0x9F, ".{ decode_no_operands,          .LAHF,        }");
    #insert #run assign_op_info_range(0xC3, 0xC3, ".{ decode_no_operands,          .RET,         }");
    #insert #run assign_op_info_range(0xCB, 0xCB, ".{ decode_no_operands,          .RET,         }");
    #insert #run assign_op_info_range(0xCC, 0xCC, ".{ decode_no_operands,          .INT3,        }");
    #insert #run assign_op_info_range(0xCE, 0xCE, ".{ decode_no_operands,          .INTO,        }");
    #insert #run assign_op_info_range(0xCF, 0xCF, ".{ decode_no_operands,          .IRET,        }");
    #insert #run assign_op_info_range(0xD4, 0xD4, ".{ decode_no_operands,          .AAM,         }");
    #insert #run assign_op_info_range(0xD5, 0xD5, ".{ decode_no_operands,          .AAD,         }");
    #insert #run assign_op_info_range(0xD7, 0xD7, ".{ decode_no_operands,          .XLAT,        }");
    #insert #run assign_op_info_range(0xF4, 0xF4, ".{ decode_no_operands,          .HLT,         }");
    #insert #run assign_op_info_range(0xF5, 0xF5, ".{ decode_no_operands,          .CMC,         }");
    #insert #run assign_op_info_range(0xF8, 0xF8, ".{ decode_no_operands,          .CLC,         }");
    #insert #run assign_op_info_range(0xF9, 0xF9, ".{ decode_no_operands,          .STC,         }");
    #insert #run assign_op_info_range(0xFA, 0xFA, ".{ decode_no_operands,          .CLI,         }");
    #insert #run assign_op_info_range(0xFB, 0xFB, ".{ decode_no_operands,          .STI,         }");
    #insert #run assign_op_info_range(0xFC, 0xFC, ".{ decode_no_operands,          .CLD,         }");
    #insert #run assign_op_info_range(0xFD, 0xFD, ".{ decode_no_operands,          .STD,         }");
    #insert #run assign_op_info_range(0x06, 0x06, ".{ decode_push_pop_seg,         .PUSH,        }");
    #insert #run assign_op_info_range(0x07, 0x07, ".{ decode_push_pop_seg,         .POP,         }");
    #insert #run assign_op_info_range(0x0E, 0x0E, ".{ decode_push_pop_seg,         .PUSH,        }");
    #insert #run assign_op_info_range(0x16, 0x16, ".{ decode_push_pop_seg,         .PUSH,        }");
    #insert #run assign_op_info_range(0x17, 0x17, ".{ decode_push_pop_seg,         .POP,         }");
    #insert #run assign_op_info_range(0x1E, 0x1E, ".{ decode_push_pop_seg,         .PUSH,        }");
    #insert #run assign_op_info_range(0x1F, 0x1F, ".{ decode_push_pop_seg,         .POP,         }");
    #insert #run assign_op_info_range(0x00, 0x03, ".{ decode_reg_with_rm,          .ADD,         }");
    #insert #run assign_op_info_range(0x08, 0x0B, ".{ decode_reg_with_rm,          .OR,          }");
    #insert #run assign_op_info_range(0x10, 0x13, ".{ decode_reg_with_rm,          .ADC,         }");
    #insert #run assign_op_info_range(0x18, 0x1B, ".{ decode_reg_with_rm,          .SBB,         }");
    #insert #run assign_op_info_range(0x84, 0x85, ".{ decode_reg_with_rm,          .TEST,        }");
    #insert #run assign_op_info_range(0x20, 0x23, ".{ decode_reg_with_rm,          .AND,         }");
    #insert #run assign_op_info_range(0x28, 0x2B, ".{ decode_reg_with_rm,          .SUB,         }");
    #insert #run assign_op_info_range(0x30, 0x33, ".{ decode_reg_with_rm,          .XOR,         }");
    #insert #run assign_op_info_range(0x38, 0x3B, ".{ decode_reg_with_rm,          .CMP,         }");
    #insert #run assign_op_info_range(0x86, 0x87, ".{ decode_reg_with_rm,          .XCHG,        }");
    #insert #run assign_op_info_range(0x88, 0x8C, ".{ decode_reg_with_rm,          .MOV,         }");
    #insert #run assign_op_info_range(0x8E, 0x8E, ".{ decode_reg_with_rm,          .MOV,         }");
    #insert #run assign_op_info_range(0xC2, 0xC2, ".{ decode_ret_pop_sp,           .RET,         }");
    #insert #run assign_op_info_range(0xCA, 0xCA, ".{ decode_ret_pop_sp,           .RET,         }");
    #insert #run assign_op_info_range(0xA4, 0xA7, ".{ decode_string_manipulation,  .INVALID,     }");
    #insert #run assign_op_info_range(0xAA, 0xAF, ".{ decode_string_manipulation,  .INVALID,     }");
    #insert #run assign_op_info_range(0xCD, 0xCD, ".{ decode_unary_imm8,           .INT,         }");
    #insert #run assign_op_info_range(0x40, 0x47, ".{ decode_unary_reg,            .INC,         }");
    #insert #run assign_op_info_range(0x48, 0x4F, ".{ decode_unary_reg,            .DEC,         }");
    #insert #run assign_op_info_range(0x50, 0x57, ".{ decode_unary_reg,            .PUSH,        }");
    #insert #run assign_op_info_range(0x58, 0x5F, ".{ decode_unary_reg,            .POP,         }");
    #insert #run assign_op_info_range(0x8F, 0x8F, ".{ decode_unary_rm,             .INVALID,     }");
    #insert #run assign_op_info_range(0xF6, 0xF7, ".{ decode_unary_rm,             .INVALID,     }");
    #insert #run assign_op_info_range(0xFE, 0xFF, ".{ decode_unary_rm,             .INVALID,     }");
}
opcode_table: Opcode_Table;
#run (){
    vacant_count := 0;
    for opcode_table.ops {
        if !it.decode  vacant_count += 1;
    }
    print("There are % of % unimplemented instructions\n\n", vacant_count, opcode_table.ops.count);
}();


operand_register :: inline (reg: u8, word: u8) -> Operand {
    return Operand.{ type = .REGISTER, reg = register(reg, word) };
}
operand_register :: inline (reg: Register) -> Operand {
    return Operand.{ type = .REGISTER, reg = reg };
}
operand_segment :: inline (seg: u8) -> Operand {
    return Operand.{ type = .REGISTER, reg = segment(seg) };
}
operand_memory_direct :: inline (addr: u16, word: bool) -> Operand {
    return Operand.{ type = .MEMORY, mem = Memory.{ mode = .DIRECT, word = word, direct = addr } };
}
immediate :: inline (low: u8, high: u8 = 0) -> u16 {
    return ((cast(u16)high) << 8) | cast(u16)low;
}
operand_immediate_u16 :: inline (value: u16) -> Operand {
    return Operand.{ type = .IMMEDIATE, imm = Immediate.{ val = value }};
}
operand_immediate :: inline (low: u8, high: u8 = 0) -> Operand {
    return Operand.{ type = .IMMEDIATE, imm = Immediate.{ val = immediate(low, high) }};
}
operand_increment :: inline (low: u8) -> Operand {
    return Operand.{ type = .INCREMENT, inc = Increment.{ val = cast(s16)(cast,no_check(s8)low) } };
}
operand_increment :: inline (low: u8, high: u8) -> Operand {
    return Operand.{ type = .INCREMENT, inc = Increment.{ val = ((cast,no_check(s16)high) << 8) | cast,no_check(s16)low } };
}

operand_to_string :: (inst: Instruction, operand: Operand) -> string {
    assert(operand.type != .INVALID, "cannot convert invalid operand to string");

    if #complete operand.type == {
        case .REGISTER;
            return register_def(operand.reg).name;
        case .INCREMENT;
            builder: String_Builder;
            builder.allocator = temporary_allocator;

            // TODO(ryan): We could emit labels instead with a slightly more sophisticated disassembly loop.
            print_to_builder(*builder, "$+%", inst.size);

            inc := operand.inc.val;
            if (inc) {
                if inc > 0  print_to_builder(*builder, " + %", inc);
                else        print_to_builder(*builder, " - %", -inc);
            }
            return builder_to_string(*builder);
        case .IMMEDIATE;
            if inst.flags & .FAR_SEGMENT
                return tprint("%:%", operand.far_segment, operand.imm.val);
            else
                return tprint("%", operand.imm.val);
        case .MEMORY; {
            mem := *operand.mem;

            builder: String_Builder;
            builder.allocator = temporary_allocator;

            if inst.explicit_size
                print_to_builder(*builder, ifx mem.word then "word " else "byte ");

            segment_prefix := "";
            if inst.flags & .SEGMENT_OVERRIDE
                segment_prefix = tprint("%:", register_def(inst.segment_override).name);

            if mem.mode == .DIRECT {
                print_to_builder(*builder, "[%0%]", segment_prefix, mem.direct);
            } else {
                print_to_builder(*builder, "[%0%", segment_prefix, register_def(mem.reg1).name);
                if mem.reg2 != .INVALID
                    print_to_builder(*builder, " + %", register_def(mem.reg2).name);
                if mem.disp {
                    disp := ifx mem.mode == .DISP_U8 then
                        cast,no_check(s8)mem.disp else
                        cast,no_check(s16)mem.disp;
                    if disp > 0  print_to_builder(*builder, " + %", disp);
                    else         print_to_builder(*builder, " - %", -disp);
                }
                append(*builder, "]");
            }
            return builder_to_string(*builder);
        }
        case .INVALID;
            assert(false, "Operand type has not been set");
            return "INVALID";
    }
};

sign_extend :: (value: u8) -> u16 {
    extended := cast(s16) (cast,no_check(s8) value);
    return cast,no_check(u16) extended;
}

_decode_immediate :: (head_imm: *u8, field_s: u8, field_w: u8) -> (Operand, bytes_read: s32) {
    advance_count: s32;
    imm: Operand;

    if (!field_w || field_s) {
        field_low := <<(head_imm);
        if !field_s
            imm = operand_immediate(field_low, 0);
        else {
            imm = operand_immediate_u16(sign_extend(field_low));
        }
        advance_count = 1;
    } else {
        field_low  := <<(head_imm);
        field_high := <<(head_imm + 1);
        imm = operand_immediate(field_low, field_high);
        advance_count = 2;
    }

    return imm, advance_count;
}

_decode_rm :: (head_disp: *u8, field_mod: u8, field_rm: u8, field_w: u8)
           -> (Operand, bytes_read: s32)
{
    rm: Operand;
    advance_count: s32;

    assert(field_mod <= 3, "Invalid register/memory mode '%'", field_mod);
    if field_mod == 0b11 {
        rm = operand_register(field_rm, field_w);
        advance_count = 0;
    } else {
        rm.type = .MEMORY;
        rm.mem = effective_address_table[field_rm];

        effective_address_table :: Memory.[
            .{ reg1 = .BX, reg2 = .SI,      },
            .{ reg1 = .BX, reg2 = .DI,      },
            .{ reg1 = .BP, reg2 = .SI,      },
            .{ reg1 = .BP, reg2 = .DI,      },
            .{ reg1 = .SI, reg2 = .INVALID, },
            .{ reg1 = .DI, reg2 = .INVALID, },
            .{ reg1 = .BP, reg2 = .INVALID, },
            .{ reg1 = .BX, reg2 = .INVALID, },
        ];
        assert(field_rm < effective_address_table.count);

        if field_mod == {
            case 0b00;
                rm.mem.mode = .NO_DISP;
                advance_count = 0;
            case 0b01;
                rm.mem.mode = .DISP_U8;
                advance_count = 1;
            case 0b10;
                rm.mem.mode = .DISP_U16;
                advance_count = 2;
            case;
                rm.mem.mode = .INVALID;
        }

        if rm.mem.mode != .NO_DISP {
            field_low  := <<(head_disp);
            field_high := ifx rm.mem.mode == .DISP_U16 then <<(head_disp + 1) else 0;
            rm.mem.disp = immediate(field_low, field_high);
        } else if field_rm == 0b110 {
            // DIRECT ADDRESSING
            field_low  := <<(head_disp);
            field_high := <<(head_disp + 1);
            rm = operand_memory_direct(immediate(field_low, field_high), cast(bool) field_w);
            advance_count = 2;
        }

        rm.mem.word = cast(bool) field_w;
    }

    return rm, advance_count;
}

//
// INSTRUCTION DECODING
//
decode_arith_imm_to_accum :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    field_inst := (<<head & 0b1111_1110) >> 1;
    field_w    := (<<head & 0b0000_0001);
    field_low  := <<(head + 1);
    field_high := ifx field_w then <<(head + 2) else 0;

    inst.desc = "immediate to accumulator";

    inst.dst = operand_register(ifx field_w then Register.AX else .AL);
    inst.src = operand_immediate(field_low, field_high);

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x%, inst=% w=%} (%)\n",
            instruction_to_string(inst), formatHex(<<head), field_inst, field_w, inst.desc);
    }

    return 2 + field_w;
}

decode_arith_imm_to_rm :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    field_s    := (<<head       & 0b0000_0010) >> 1;
    field_w    := (<<head       & 0b0000_0001);
    field_mod  := (<<(head + 1) & 0b1100_0000) >> 6;
    field_inst := (<<(head + 1) & 0b0011_1000) >> 3;
    field_rm   := (<<(head + 1) & 0b0000_0111);

    inst.desc = "immediate to register/memory";
    inst.explicit_size = true;

    // the instruction is not known from the first byte, so we must determine in this dispatch
    // handler.
    assert(inst.type == .INVALID);
    if field_inst == {
        case 0;
            inst.type = .ADD;
        case 0b001;
            inst.type = .OR;
        case 0b010;
            inst.type = .ADC;
        case 0b011;
            inst.type = .SBB;
        case 0b100;
            inst.type = .AND;
        case 0b101;
            inst.type = .SUB;
        case 0b110;
            inst.type = .XOR;
        case 0b111;
            inst.type = .CMP;
    }
    assert(inst.type != .INVALID, "Failed to match bit pattern %", field_inst);

    // HACK(ryan): TEST and ADD share a 3-bit pattern
    if (<<head & 0b1111_1110) == 0b1111_0110
        inst.type = .TEST;

    offset: s32 = 2;
    rm, extra_advance := _decode_rm(head + offset, field_mod, field_rm, field_w);
    offset += extra_advance;
    imm, extra_advance2 := _decode_immediate(head + offset, field_s, field_w);
    offset += extra_advance2;

    inst.src = imm;
    inst.dst = rm;

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x%, s=% w=%, mod=% inst=% rm=%} (%)\n",
            instruction_to_string(inst), formatHex(<<head), field_s, field_w, field_mod,
            field_inst, field_rm, inst.desc);
    }

    return offset;
}

decode_arith_reg_with_accum :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    field_reg := <<head & 0b0000_0111;

    inst.desc = "register with accumulator";
    inst.dst = operand_register(.AX);
    inst.src = operand_register(field_reg, 1);

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x%, reg=%} (%)\n",
            instruction_to_string(inst), formatHex(<<head), field_reg, inst.desc);
    }

    return 1;
}

decode_bit_ops :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    field_v    := (<< head      & 0b0000_0010) >> 1; // 0: src is 1, 1: src is "cl" register
    field_w    := (<< head      & 0b0000_0001);
    field_mod  := (<<(head + 1) & 0b1100_0000) >> 6;
    field_inst := (<<(head + 1) & 0b0011_1000) >> 3;
    field_rm   := (<<(head + 1) & 0b0000_0111);

    inst_table ::  Instruction_Type.[
        .ROL,
        .ROR,
        .RCL,
        .RCR,
        .SHL,
        .SHR,
        .INVALID,
        .SAR,
    ];

    assert(field_inst < inst_table.count);
    inst.type = inst_table[field_inst];
    assert(inst.type != .INVALID, "Failed to match bit pattern %", field_inst);

    rm, extra_advance := _decode_rm(head + 2, field_mod, field_rm, field_w);

    inst.desc = "bit manipulation of register/memory by 1 or value in cl register";
    inst.src = ifx !field_v then operand_immediate(1) else operand_register(.CL);
    inst.dst = rm;
    inst.explicit_size = true;

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x%, v=% w=%, mod=% inst=% rm=%} (%)\n",
            instruction_to_string(inst), formatHex(<<head), field_v, field_w, field_mod,
            field_inst, field_rm, inst.desc);
    }

    return 2 + extra_advance;
}

decode_call_direct_in_seg :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    field_short := (<<head & 0b0000_0010) >> 1;

    inst.desc = "direct within segment";
    inst.operand_count = .UNARY;
    inst.size = 2 + cast(u32) !field_short;

    inst.dst = operand_increment(<<(head + 1), ifx !field_short then <<(head + 2) else 0);

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x%, increment=%} (%)\n",
            instruction_to_string(inst), formatHex(<<head), inst.dst.inc.val, inst.desc);
    }

    return cast(s32)inst.size;
}

decode_call_indirect_in_seg :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    field_mod   := (<<(head + 1) & 0b1100_0000) >> 6;
    field_rm    := (<<(head + 1) & 0b0000_0111);

    inst.desc = "indirect within segment";
    inst.operand_count = .UNARY;

    rm, extra_advance := _decode_rm(head + 2, field_mod, field_rm, 1);
    inst.dst = rm;

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x% mod=% rm=%} (%)\n",
            instruction_to_string(inst), formatHex(<<head), field_mod, field_rm, inst.desc);
    }

    return 2 + extra_advance;
}

decode_unary_imm8 :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    inst.desc = "unary op with 8 bit immediate data";
    inst.operand_count = .UNARY;

    inst.dst = operand_immediate(<<(head + 1));

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x%} (%)\n",
            instruction_to_string(inst), formatHex(<<head), inst.desc);
    }

    return 2;
}

decode_in_out :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    field_fv   := (<<head & 0b0000_1000) >> 3; // fixed:0, variable:1
    field_inst := (<<head & 0b0000_0010) >> 1; // IN:0, OUT:1
    field_w    :=  <<head & 0b0000_0001;

    accum := operand_register(ifx field_w then Register.AX else .AL);

    inst.type = ifx field_inst then Instruction_Type.OUT else .IN;

    port: Operand;
    if field_fv {
        inst.desc = "accumulator with variable i/o port addressed by register";
        port = operand_register(.DX);
    } else {
        inst.desc = "accumulator with fixed i/o port";
        port = operand_immediate(<<(head + 1));
    }

    inst.dst = ifx field_inst then port  else accum;
    inst.src = ifx field_inst then accum else port;

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x%, field_inst=% field_w=%} (%)\n",
            instruction_to_string(inst), formatHex(<<head), field_inst, field_w, inst.desc);
    }

    advance_count : s32 = 1 + cast(s32) ifx !field_fv then 1 else 0;
    return advance_count;
}

decode_jump_cond_inc8 :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    field_inst1 := <<head & 0b1000_0000; // found a bit that is 0 for first 8, 1 for next 4
    field_inst2 := <<head & 0b0000_1111;

    // NOTE(ryan): it would more performant to encode the instruction type into the main opcode
    // table, since it is entirely determined by the first byte, and that is what addresses the
    // main opcode table. For now it is here to demonstrate the pattern, I guess.
    field_inst  := (field_inst1 >> 3) | field_inst2;
    jump_inst_table :: Instruction_Type.[
        // 0b0000_****
        .JO,
        .JNO,
        .JB_JNAE_JC,
        .JNB_JAE_JNC,
        .JE_JZ,
        .JNE_JNZ,
        .JBE_JNA,
        .JNBE_JA,
        .JS,
        .JNS,
        .JP_JPE,
        .JNP_JPO,
        .JL_JNGE,
        .JNL_JGE,
        .JLE_JNG,
        .JNLE_JG,

        // 0b0001_****
        .LOOPNZ,
        .LOOPZ,
        .LOOP,
        .JCXZ,
    ];

    assert(field_inst < jump_inst_table.count);
    inst.type = jump_inst_table[field_inst];
    assert(inst.type != .INVALID, "Failed to match bit pattern %", field_inst);

    inst.desc = "jump short (8-bit) if condition is met";
    inst.operand_count = .UNARY;
    inst.size = 2;

    inst.dst = operand_increment(<<(head +1));

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x%, increment=%} (%)\n",
            instruction_to_string(inst), formatHex(<<head), inst.dst.inc.val, inst.desc);
    }

    return cast(s32) inst.size;
}

decode_load_to_reg_seg :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    field_sr  := (<< head      & 0b0000_1000) >> 3; // 0:seg, 1:reg
    field_mod := (<<(head + 1) & 0b1100_0000) >> 6;
    field_reg := (<<(head + 1) & 0b0011_1000) >> 3;
    field_rm  := (<<(head + 1) & 0b0000_0111);

    descs :: string.[
        "load far pointer to segment+register",
        "load effective address to register",
    ];

    inst.desc = descs[field_sr];

    // LDS, LES (field_sr: 0)
    // loads 32-bit pointer from memory (at effective address) into segment register (seg selector: top 16-bits)
    // and destination register (seg offset: bottom 16-bits)

    // LEA (field_sr: 1)
    // computes effective address for source operand and store in register addressed by destination operand

    inst.dst = operand_register(field_reg, 1);
    rm, extra_advance := _decode_rm(head + 2, field_mod, field_rm, 1);
    inst.src = rm;

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x%} (%)\n",
            instruction_to_string(inst), formatHex(<<head), inst.desc);
     }

    return 2 + extra_advance;
}

decode_mov_accumulator :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    inst.desc = "memory to/from accumulator";

    field_to_mem := (<<head & 0b10) >> 1;
    field_w      :=  <<head & 0b01;

    field_low  := <<(head + 1);
    field_high := <<(head + 2);

    reg := operand_register(ifx field_w then Register.AX else Register.AL);
    mem := operand_memory_direct(immediate(field_low, field_high), word=cast(bool) field_w);

    inst.dst = ifx field_to_mem then mem else reg;
    inst.src = ifx field_to_mem then reg else mem;

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x%, to_mem=%, w=%} (%)\n",
            instruction_to_string(inst), formatHex(<<head), field_to_mem, field_w, inst.desc);
    }

    return 3;
}

decode_mov_imm_to_reg :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    field_w    := (<< head       & 0b0000_1000) >> 3;
    field_reg  :=  << head       & 0b0000_0111;
    field_low  :=  <<(head + 1);
    field_high :=  ifx field_w then <<(head + 2) else 0;

    inst.desc = "immediate to register";

    inst.dst = operand_register(field_reg, field_w);
    inst.src = operand_immediate(field_low, field_high);
    advance_count := cast(s32)(ifx field_w then 3 else 2);

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x%, w=% reg=%, low=%, high=%} (%)\n",
            instruction_to_string(inst), formatHex(<<head), field_w, field_reg,
            field_low, field_high, inst.desc);
    }

    return advance_count;
}

decode_mov_imm_to_rm :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    field_w := <<head & 0b0000_0001;
    field_mod := (<<(head + 1) & 0b1100_0000) >> 6;
    field_rm  := (<<(head + 1) & 0b0000_0111);

    inst.desc = "move immediate to register";

    offset: s32 = 2;
    rm, extra_advance := _decode_rm(head + offset, field_mod, field_rm, field_w);
    inst.dst = rm;
    inst.explicit_size = rm.type != .REGISTER;
    offset += extra_advance;

    imm, extra_advance2 := _decode_immediate(head + offset, 0, field_w);
    inst.src = imm;
    offset += extra_advance2;

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x%, w=%} (%)\n",
            instruction_to_string(inst), formatHex(<<head), field_w, inst.desc);
    }

    return offset;
}

decode_string_manipulation :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    field_inst := (<<head & 0b0000_1110) >> 1;
    field_w    :=  <<head & 0b0000_0001;

    inst_table ::  Instruction_Type.[
        .INVALID,
        .INVALID,
        .MOVS,
        .CMPS,
        .INVALID,
        .STOS,
        .LODS,
        .SCAS,
    ];

    assert(field_inst < inst_table.count);
    inst.type = inst_table[field_inst];
    assert(inst.type != .INVALID, "Failed to match bit pattern %", field_inst);

    inst.desc = "string manipulation";
    inst.operand_count = .ZERO;
    inst.flags |= ifx !field_w then Instruction_Flags.STRING_BYTE else .STRING_WORD;

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x%} (%)\n", instruction_to_string(inst), formatHex(<<head), inst.desc);
    }

    return 1;
}

decode_no_operands :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    inst.desc = "no operands";
    inst.operand_count = .ZERO;

    if <<head == 0xCB
        inst.type = .RETF;

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x%} (%)\n", instruction_to_string(inst), formatHex(<<head), inst.desc);
    }

    if (inst.type == .AAM || inst.type == .AAD)
        return 2;
    else
        return 1;
}

decode_push_pop_seg :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    field_seg := (<<(head) & 0b0001_1000) >> 3;

    inst.desc = "segment register to/from stack";
    inst.operand_count = .UNARY;

    inst.dst = operand_segment(field_seg);

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x%, seg=%} (%)\n",
            instruction_to_string(inst), formatHex(<<head), field_seg, inst.desc);
    }

    return 1;
}

decode_reg_with_rm :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    field_d    := (<<head       & 0b0000_0010) >> 1;
    field_w    := (<<head       & 0b0000_0001);
    field_mod  := (<<(head + 1) & 0b1100_0000) >> 6;
    field_reg  := (<<(head + 1) & 0b0011_1000) >> 3;
    field_rm   := (<<(head + 1) & 0b0000_0111);

    inst.desc = "Reg/memory with register to either";

    // Special case for move to/from segment register
    reg: Operand;
    if <<head == 0x8C || <<head == 0x8E {
        reg = operand_segment((<<(head + 1) & 0b0001_1000) >> 3);
        field_w = 1; // segment registers always use 16-bit moves
    } else
        reg = operand_register(field_reg, field_w);

    rm, extra_advance := _decode_rm(head + 2, field_mod, field_rm, field_w);

    inst.dst = ifx field_d then reg else rm;
    inst.src = ifx field_d then rm  else reg;

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x%, d=% w=%, mod=% reg=% rm=%} (%)\n",
            instruction_to_string(inst), formatHex(<<head), field_d, field_w,
            field_mod, field_reg, field_rm, inst.desc);
    }

    return 2 + extra_advance;
}

decode_ret_pop_sp :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    inst.desc = "return adding immed to stack pointer";
    inst.operand_count = .UNARY;

    if <<head == 0xCA
        inst.type = .RETF;

    inst.dst = operand_immediate(<<(head + 1), <<(head + 2));

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x%} (%)\n", instruction_to_string(inst), formatHex(<<head), inst.desc);
    }

    return 3;
}

decode_unary_reg ::    (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    field_reg := (<<(head) & 0b0000_0111);

    inst.desc = "register to/from stack";
    inst.operand_count = .UNARY;

    inst.dst = operand_register(field_reg, 1);

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x%, reg=%} (%)\n",
            instruction_to_string(inst), formatHex(<<head), field_reg, inst.desc);
    }

    return 1;
}

decode_unary_rm :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    field_w     :=  << head      & 0b0000_0001;
    field_mod   := (<<(head + 1) & 0b1100_0000) >> 6;
    field_inst1 : s32 = (<< head);
    field_inst2 : s32 = (<<(head + 1) & 0b0011_1000) >> 3;
    field_rm    := (<<(head + 1) & 0b0000_0111);

    field_inst := ((field_inst1 << 3) | field_inst2);

    // HACK(ryan): Weird special case where we must entirely redirect TEST instructions to another
    // handler
    if (field_inst & 0b1111_1110_111) == 0b1111_0110_000 {
        // TEST
        return decode_arith_imm_to_rm(inst, head);
    } else if field_inst == 0b1111_1111_010 {
        inst.type = .CALL;
        return decode_call_indirect_in_seg(inst, head);
    } else if field_inst == 0b1111_1111_100 {
        inst.type = .JMP;
        return decode_call_indirect_in_seg(inst, head);
    }

    inst.desc = "increment register/memory";
    inst.operand_count = .UNARY;

    explicit_size := true;
    if field_inst == {
        case 0b1000_1111_000;
            inst.type = .POP;

        case 0b1111_0110_011; #through;
        case 0b1111_0111_011;
            inst.type = .NEG;

        case 0b1111_0110_100; #through;
        case 0b1111_0111_100;
            inst.type = .MUL;
        case 0b1111_0110_101; #through;
        case 0b1111_0111_101;
            inst.type = .IMUL;

        case 0b1111_0110_110; #through;
        case 0b1111_0111_110;
            inst.type = .DIV;
        case 0b1111_0110_111; #through;
        case 0b1111_0111_111;
            inst.type = .IDIV;

        case 0b1111_0110_010; #through;
        case 0b1111_0111_010;
            inst.type = .NOT;

        case 0b1111_1110_000; #through;
        case 0b1111_1111_000;
            inst.type = .INC;
        case 0b1111_1110_001; #through;
        case 0b1111_1111_001;
            inst.type = .DEC;

        case 0b1111_1111_110;
            inst.type = .PUSH;

        case 0b1111_1111_011;
            inst.type = .CALLF;
            explicit_size = false;
        case 0b1111_1111_101;
            inst.type = .JMPF;
            explicit_size = false;
    }
    assert(inst.type != .INVALID, "Failed to match bit pattern %", field_inst);

    rm, extra_advance := _decode_rm(head + 2, field_mod, field_rm, field_w);
    inst.dst = rm;
    inst.explicit_size = explicit_size;

    if DEBUG_DECODE {
        print("%  ; {first_byte=0x%, w=% mod=% rm=%} (%)\n",
            instruction_to_string(inst), formatHex(<<head), field_w, field_mod, field_rm, inst.desc);
    }

    return 2 + extra_advance;
}

decode_jump_direct_far :: (inst: *Instruction, head: *u8) -> (advance_count: s32) {
    field_ip_lo := <<(head + 1);
    field_ip_hi := <<(head + 2);
    field_cs_lo := <<(head + 3);
    field_cs_hi := <<(head + 4);


    inst.desc = "call direct intersegment";
    inst.operand_count = .UNARY;
    inst.flags |= .FAR_SEGMENT;

    inst.dst = operand_immediate(field_ip_lo, field_ip_hi);
    inst.dst.far_segment = immediate(field_cs_lo, field_cs_hi);

    if DEBUG_DECODE {
        print("%  ; {first_byte=%} (%)\n",
            instruction_to_string(inst), formatHex(<<head), inst.desc);
    }
    return 5;
}

//
// ENTRYPOINTS
//
decode_all_prefix_bytes :: (head: *u8) -> (Instruction_Flags, segment_override: Register, advance_count: s32) {
    flags: Instruction_Flags;
    segment_override := Register.INVALID;
    advance_count: s32 = 0;
    while true {
        if <<head == {
            case 0b1111_0000;
                flags |= .LOCK;
            case 0b1111_0010;
                flags |= .REPEAT_NOTZERO;
            case 0b1111_0011;
                flags |= .REPEAT_ZERO;
            case 0b0010_1110;
                segment_override = .CS;
                flags |= .SEGMENT_OVERRIDE;
            case 0b0011_1110;
                segment_override = .DS;
                flags |= .SEGMENT_OVERRIDE;
            case 0b0010_0110;
                segment_override = .ES;
                flags |= .SEGMENT_OVERRIDE;
            case 0b0011_0110;
                segment_override = .SS;
                flags |= .SEGMENT_OVERRIDE;
            case; break;
        }
        advance_count += 1;
        head += 1;
    }
    return flags, segment_override, advance_count;
}

decode_once :: (head: *u8) -> (Instruction, advance: s32) {
    flags, segment_override, prefix_advance := decode_all_prefix_bytes(head);
    head += prefix_advance;

    opcode := <<head;
    assert(opcode < opcode_table.ops.count);
    op_info := opcode_table.ops[opcode];

    if !op_info.decode
        assert(false, "Unknown opcode for first byte: 0x%", formatHex(<<head));

    inst: Instruction;
    inst.type = op_info.type; // NOTE(ryan): will be modified by decode proc if initially .INVALID in decode table
    inst.flags = flags;
    inst.segment_override = segment_override; // ignored unless (flags & .SEGMENT_OVERRIDE)
    advance_count := op_info.decode(*inst, head);
    inst.size = cast(u32) advance_count;

    assert(inst.type != .INVALID, "Instruction dispatch handler must resolve instruction if not resolvable automatically from the first byte");
    assert(inst.desc.count > 0, "Instruction dispatch handler must provide a description");
    assert(inst.operand_count == .ZERO   || inst.dst.type != .INVALID, "dest operand must be valid if operand_count != .ZERO");
    assert(inst.operand_count != .BINARY || inst.src.type != .INVALID, "src operand must be valid if operand_count == .BINARY");

    return inst, prefix_advance + advance_count;
}

instruction_to_string :: (inst: Instruction) -> string {
    builder: String_Builder;
    builder.allocator = temporary_allocator;

    print_instruction(*builder, inst);
    return builder_to_string(*builder);
}

print_instruction :: (builder: *String_Builder, inst: Instruction) {
    if inst.flags & .REPEAT_NOTZERO
        append(builder, "repnz ");
    else if inst.flags & .REPEAT_ZERO
        append(builder, "rep ");
    else if inst.flags & .LOCK
        append(builder, "lock ");

    mnemonic := mnemonic_string(inst.type);
    if #complete inst.operand_count == {
        case .ZERO;
            append(builder, mnemonic);
            if inst.flags & .STRING_BYTE
                append(builder, "b");
            else if inst.flags & .STRING_WORD
                append(builder, "w");
        case .UNARY;
            print_to_builder(builder, "% %", mnemonic, operand_to_string(inst, inst.dst));
        case .BINARY;
            print_to_builder(builder, "% %, %", mnemonic, operand_to_string(inst, inst.dst), operand_to_string(inst, inst.src));
    }
}

disassemble_file :: (filename: string, output_asm_path: string="out.asm") {
    bytes: []u8 = file_read_all_as_bytes(filename);

    builder: String_Builder;

    offset := 0;
    while offset < bytes.count {
        head := bytes.data + offset;
        inst, advance := decode_once(head);
        offset += advance;

        print_instruction(*builder, inst);
        append(*builder, "\n");
    }

    file, success := file_open(output_asm_path, for_writing=true, keep_existing_content=false);
    if !success
        assert(false);

    file_write(*file, "; auto-generated 8086 disassembly\n");
    file_write(*file, "bits 16\n\n");
    file_write(*file, *builder);
    file_close(*file);
}

flags_to_string :: (state: Processor_State, allocator: Allocator = temporary_allocator) -> string {
    builder: String_Builder;
    builder.allocator = temporary_allocator;

    flags := cast(Flag) load_register(state, .FLAG);
    if flags & .TRAP        append(*builder, "T");
    if flags & .DIRECTION   append(*builder, "D");
    if flags & .INT_ENABLE  append(*builder, "I");
    if flags & .OVERFLOW    append(*builder, "O");
    if flags & .SIGN        append(*builder, "S");
    if flags & .ZERO        append(*builder, "Z");
    if flags & .AUX_CARRY   append(*builder, "A");
    if flags & .PARITY      append(*builder, "P");
    if flags & .CARRY       append(*builder, "C");

    return builder_to_string(*builder, allocator);
}
print_processor_state :: (state: Processor_State) {
    formatInt8  :: #bake_arguments formatInt(minimum_digits=3, padding=#char " ");
    formatInt16 :: #bake_arguments formatInt(minimum_digits=5, padding=#char " ");
    print_register_word :: (reg: Register, low: Register = .INVALID, high: Register = .INVALID) #expand {
        value: u16 = load_register(*state, reg);
        low_value  : u8 = cast,no_check(u8) value;
        high_value : u8 = cast(u8) (value >> 8);

        print("    %: 0x% (%) [low=%, high=%]\n", register_def(reg).name, formatHex(value, minimum_digits=4),
            formatInt16(value), formatInt8(low_value), formatInt8(high_value));
    }

    print("Processor State\n");
    print_register_word(.AX);
    print_register_word(.BX);
    print_register_word(.CX);
    print_register_word(.DX);

    print_register_word(.SP);
    print_register_word(.BP);
    print_register_word(.SI);
    print_register_word(.DI);

    print("    ip: 0x% (%)\n", formatHex(state.ip, minimum_digits=4), formatInt16(state.ip));
    print("    flags: %\n", flags_to_string(state));
}

effective_address :: (state: *Processor_State, mem: Memory) -> u16 {
    assert(mem.mode != .INVALID, "Invalid memory mode.");

    if mem.mode == .DIRECT
        return mem.direct;

    addr := load_register(state, mem.reg1);
    if mem.reg2 != .INVALID
        addr += load_register(state, mem.reg2);
    if mem.mode != .NO_DISP
        addr += mem.disp;

    return addr;
}

store_register :: (state: *Processor_State, register: Register, value: u16) {
    reg := register_def(register);
    state.register_memory[reg.offset] = cast(u8)(value & 0xFF);
    if reg.size >= 2
        state.register_memory[reg.offset + 1] = cast(u8)((value >> 8) & 0xFF);
}

store_flags :: inline (state: *Processor_State, flags: Flag) {
    store_register(state, .FLAG, cast(u16) flags);
}

store_operand :: (state: *Processor_State, operand: Operand, value: u16) {
    if operand.type == {
        case .REGISTER;
            store_register(state, operand.reg, value);
        case .MEMORY;
            addr := effective_address(state, operand.mem);
            if operand.mem.word then
                <<(cast(*u16)(*state.memory[addr])) = value;
            else
                state.memory[addr] = cast(u8) value;
    }
}

load_register :: (state: Processor_State, register: Register) -> u16 {
    assert(register != .INVALID, "Invalid register.");
    reg := register_def(register);
    value: u16 =  state.register_memory[reg.offset];
    if reg.size >= 2
        value |= (cast(u16)state.register_memory[reg.offset + 1]) << 8;
    return value;
}

load_flags :: inline (state: Processor_State) -> Flag {
    return cast(Flag) load_register(state, .FLAG);
}

load_operand :: (state: Processor_State, operand: Operand) -> u16 {
    if operand.type == {
        case .IMMEDIATE;
            return operand.imm.val;
        case .REGISTER;
            return load_register(state, operand.reg);
        case .MEMORY;
            addr := effective_address(*state, operand.mem);
            if operand.mem.word
                return <<(cast(*u16) (*state.memory[addr]));
            else
                return state.memory[addr];
        case;
            assert(false, "operand type % not implemented", operand.type);
    }
    return 1 << 16 - 1;
}

set_flag :: (flags: *u16, flag: Flag, value: bool) {
    if value  { (<<flags) |=   cast(u16) flag;  }
    else      { (<<flags) &= ~(cast(u16) flag); }
}

exec_mov :: (state: *Processor_State, inst: Instruction) {
    original: u16;
    if DEBUG_EXEC
        original = load_operand(state, inst.dst);

    value := load_operand(state, inst.src);
    store_operand(state, inst.dst, value);

    if DEBUG_EXEC {
        print("% ; %:0x%->0x%\n", instruction_to_string(inst), operand_to_string(inst, inst.dst),
        formatHex(original), formatHex(value));
    }
}
exec_arithmetic :: (state: *Processor_State, inst: Instruction) {
    original_flags: string;
    if DEBUG_EXEC
        original_flags = flags_to_string(state);

    dst: u32 = cast(u32) load_operand(state, inst.dst);
    src: u32 = cast(u32) load_operand(state, inst.src);

    // TODO(ryan): only supports 16-bit ops
    assert((inst.dst.type == .REGISTER && register_def(inst.dst.reg).size == 2) ||
        (inst.src.type == .REGISTER && register_def(inst.src.reg).size == 2));
    operand_mask := 0xFFFF;
    sign_mask    := 0x8000;

    if inst.type == .SUB || inst.type == .CMP
        src = ((~src) + 1) & 0xFFFF;

    value32: u32; // for detecting CARRY
    aux_carry: bool;
    carry: bool;
    if inst.type == {
        case .ADD;
            value32 = dst + src;
            carry     = cast(bool)  (value32 & (operand_mask + 1));
            aux_carry = cast(bool) ((value32 ^ dst ^ src) & 0x10);

        case .SUB; #through;
        case .CMP;
            value32 = dst + src; // with two's-complement src
            carry     = ! cast(bool)  (value32 & (operand_mask + 1));
            aux_carry = ! cast(bool) ((value32 ^ dst ^ src) & 0x10);
    }

    value: u16 = cast,no_check(u16) value32;
    if inst.type != .CMP
        store_operand(state, inst.dst, value);

    // load, overwrite some flags, and store
    flags: u16 = load_register(state, .FLAG);
    {
        set_flag(*flags, Flag.SIGN,      cast(bool) value & sign_mask);
        set_flag(*flags, Flag.ZERO,      value == 0);
        set_flag(*flags, Flag.CARRY,     carry);
        set_flag(*flags, Flag.AUX_CARRY, aux_carry);
        set_flag(*flags, Flag.OVERFLOW,  cast(bool) (~(src ^ dst) & sign_mask) & ((value ^ dst) & sign_mask));

        // parity (low-order 8-bits have even number of set bits)
        set_count := 0;
        for 0..7  set_count += cast(s64) cast(bool) (value & (1 << it));
        set_flag(*flags, Flag.PARITY, set_count % 2 == 0);
    }
    store_register(state, .FLAG, flags);

    if DEBUG_EXEC
        print("% ; %:0x%->0x% flags:%->%\n", instruction_to_string(inst), operand_to_string(inst, inst.dst),
            formatHex(dst), formatHex(value), original_flags, flags_to_string(state));
}
exec_conditional_jump :: (state: *Processor_State, inst: Instruction) {
    flags := load_flags(state);

    do_jump: bool;
    if inst.type == {
        case .JNE_JNZ;     do_jump = !  (flags & .ZERO);
        case .JE_JZ;       do_jump = xx (flags & .ZERO);
        case .JNB_JAE_JNC; do_jump = !  (flags & .CARRY);
        case .JB_JNAE_JC;  do_jump = xx (flags & .CARRY);
        case .JNP_JPO;     do_jump = !  (flags & .PARITY);
        case .JP_JPE;      do_jump = xx (flags & .PARITY);
        case .LOOPZ; #through;
        case .LOOPNZ;
            // TODO(ryanneph): This must set the zero (and other) flag as needed
            cx := load_register(state, .CX);
            cx -= 1;
            do_jump = ifx inst.type == .LOOPNZ then cx != 0 else cx == 0;
            store_register(state, .CX, cx);
        case; assert(false, "% is not yet a supported conditional jump type.", inst.type);
    }

    assert(inst.dst.type == .INCREMENT, "Expected relative offset (increment) operand");
    rel := inst.dst.inc.val;

    original_ip: s64;
    if DEBUG_EXEC
        original_ip = state.ip;

    if do_jump  state.ip += rel;

    if DEBUG_EXEC {
        print("% ; ip:0x%->0x%\n", instruction_to_string(inst), formatHex(original_ip), formatHex(state.ip));
    }
}
exec_instruction :: (state: *Processor_State, inst: Instruction) {
    if inst.type == {
        case .MOV; exec_mov(state, inst);

        case .ADD; #through;
        // case .ADC; #through;
        case .CMP; #through;
        case .SUB;
        // case .SBB; #through;
            exec_arithmetic(state, inst);

        case .JBE_JNA;     #through;
        case .JB_JNAE_JC;  #through;
        case .JCXZ;        #through;
        case .JE_JZ;       #through;
        case .JLE_JNG;     #through;
        case .JL_JNGE;     #through;
        case .JMP;         #through;
        case .JMPF;        #through;
        case .JNBE_JA;     #through;
        case .JNB_JAE_JNC; #through;
        case .JNE_JNZ;     #through;
        case .JNLE_JG;     #through;
        case .JNL_JGE;     #through;
        case .JNO;         #through;
        case .JNP_JPO;     #through;
        case .JNS;         #through;
        case .JO;          #through;
        case .JP_JPE;      #through;
        case .JS;          #through;
        case .LOOPNZ;      #through;
        case .LOOPZ;       #through;
        case .LOOP;
            exec_conditional_jump(state, inst);

        case;
            assert(false, "EXEC for instruction type '%' is not implemented.\n", inst.type);
    }
}

execute_from_ip :: (state: *Processor_State, inst_memory: Memory_Region) {
    while state.ip < inst_memory.count {
        head := inst_memory.data + state.ip;
        inst, advance := decode_once(head);

        new_ip := state.ip + advance;
        state.ip = new_ip;

        exec_instruction(state, inst);
    }
}

execute_file :: (filename: string) {
    inst_memory: Memory_Region = file_read_all_as_bytes(filename);

    DEBUG_DECODE = false;
    state: Processor_State;
    execute_from_ip(*state, inst_memory);

    print("\n");
    print_processor_state(state);
}

print_usage :: (args: []string) {
    print(#string ENDUSAGE
usage:  % <command> [options]
commands:
  decode  decode the file into 8086 assembly
          "decode <file>"
  exec    execute the 8086 assembled binary file
          "exec <file>"
  test    run all known tests
ENDUSAGE, args[0]);
}

arg_parsing_error :: (args: []string, message: string, exit_code: s32 = 1) {
    print_usage(args);
    print("\nArgument Error: %\n", message);
    exit(exit_code);
}

main :: () {
    args := get_command_line_arguments();
    if args.count <= 1
        arg_parsing_error(args, "not enough arguments provided");

    if args[1] == {
        case "decode";
            if (args.count < 3)
            arg_parsing_error(args, "not enough arguments provided");
            disassemble_file(args[2]);
        case "exec";
            if (args.count < 3)
            arg_parsing_error(args, "not enough arguments provided");
            execute_file(args[2]);
        case "test";
            run_tests();
        case;
            arg_parsing_error(args, tprint("unknown command '%'\n", args[1]));
    }
}

