#import "Basic";
#import "Process";

#load "file.jai";
#load "test.jai";

DEBUG := true;

Register :: string;
Memory_Mode :: enum {
    MEM_NO_DISP :: 0b00;
    MEM_DISP_8  :: 0b01;
    MEM_DISP_16 :: 0b10;
    REGISTER    :: 0b11;
    MEM_DIRECT;
}
Memory :: union {
    struct {
        base1: Register;
        base2: Register;
        disp: u16;
    };
    direct: u16;
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
Operand_Size :: enum {
    IMPLICIT;
    BYTE;
    WORD;
}
Operand :: struct {
    type: Operand_Type;
    size: Operand_Size;
    union {
        reg: Register;
        mem: Memory;
        imm: Immediate;
        inc: Increment;
    };
}

// TODO(ryan): Hook the compilation-loop and populate the matched-index table automatically
Instruction_Type :: enum u32 {
    INVALID :: 0;
    ADC;          // @mnemonic:adc
    ADD;          // @mnemonic:add
    CMP;          // @mnemonic:cmp
    JO;           // @mnemonic:jo
    JNO;          // @mnemonic:jno
    JB_JNAE_JC;   // @mnemonic:jb
    JNB_JAE_JNC;  // @mnemonic:jnb
    JE_JZ;        // @mnemonic:je
    JNE_JNZ;      // @mnemonic:jne
    JBE_JNA;      // @mnemonic:jbe
    JNBE_JA;      // @mnemonic:ja
    JS;           // @mnemonic:js
    JNS;          // @mnemonic:jns
    JP_JPE;       // @mnemonic:jp
    JNP_JPO;      // @mnemonic:jnp
    JL_JNGE;      // @mnemonic:jl
    JNL_JGE;      // @mnemonic:jge
    JLE_JNG;      // @mnemonic:jle
    JNLE_JG;      // @mnemonic:jg
    LOOP;         // @mnemonic:loop
    LOOPZ;        // @mnemonic:loopz
    LOOPNZ;       // @mnemonic:loopnz
    JCXZ;         // @mnemonic:jcxz
    SUB;          // @mnemonic:sub
    MOV;          // @mnemonic:mov
    PUSH;         // @mnemonic:push
    POP;          // @mnemonic:pop
    _ENUM_COUNT;
}
Mnemonic_Table :: struct {
    strings: [Instruction_Type._ENUM_COUNT]string;
    strings[Instruction_Type.ADD]         = "add";
    strings[Instruction_Type.ADC]         = "adc";
    strings[Instruction_Type.CMP]         = "cmp";
    strings[Instruction_Type.JO]          = "jo";
    strings[Instruction_Type.JNO]         = "jno";
    strings[Instruction_Type.JB_JNAE_JC]  = "jb";
    strings[Instruction_Type.JNB_JAE_JNC] = "jnb";
    strings[Instruction_Type.JE_JZ]       = "je";
    strings[Instruction_Type.JNE_JNZ]     = "jne";
    strings[Instruction_Type.JBE_JNA]     = "jbe";
    strings[Instruction_Type.JNBE_JA]     = "ja";
    strings[Instruction_Type.JS]          = "js";
    strings[Instruction_Type.JNS]         = "jns";
    strings[Instruction_Type.JP_JPE]      = "jp";
    strings[Instruction_Type.JNP_JPO]     = "jnp";
    strings[Instruction_Type.JL_JNGE]     = "jl";
    strings[Instruction_Type.JNL_JGE]     = "jge";
    strings[Instruction_Type.JLE_JNG]     = "jle";
    strings[Instruction_Type.JNLE_JG]     = "jg";
    strings[Instruction_Type.LOOP]        = "loop";
    strings[Instruction_Type.LOOPZ]       = "loopz";
    strings[Instruction_Type.LOOPNZ]      = "loopnz";
    strings[Instruction_Type.JCXZ]        = "jcxz";
    strings[Instruction_Type.SUB]         = "sub";
    strings[Instruction_Type.MOV]         = "mov";
    strings[Instruction_Type.PUSH]        = "push";
    strings[Instruction_Type.POP]         = "pop";
}
mnemonic_table: Mnemonic_Table;
mnemonic_string :: inline (type: Instruction_Type) -> string {
    assert(type != .INVALID);
    assert(cast(s64)type < mnemonic_table.strings.count);
    mnemonic :=  mnemonic_table.strings[type];
    assert(mnemonic.count > 0, "mnemonic string not defined for Instruction_Type.%\n", type);
    return mnemonic;
}

Operand_Count :: enum {
    UNARY   :: 1;
    BINARY  :: 2;
}

Instruction :: struct {
    type: Instruction_Type;
    operand_count := Operand_Count.BINARY;
    mode: Memory_Mode;

    // TODO(ryan): maybe store *Opcode_Info for indirection instead?
    desc: string;

    // For single operand instructions, only dst is used
    dst: Operand;
    src: Operand;
}

Decode_Proc :: #type (op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32);
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
    #insert #run assign_op_info_range(0x00, 0x03, ".{ decode_arith_reg_with_rm,  .ADD,         }");
    #insert #run assign_op_info_range(0x04, 0x05, ".{ decode_arith_imm_to_accum, .ADD,         }");
    #insert #run assign_op_info_range(0x06, 0x06, ".{ decode_push_pop_seg,       .PUSH,        }");
    #insert #run assign_op_info_range(0x07, 0x07, ".{ decode_push_pop_seg,       .POP,         }");
    #insert #run assign_op_info_range(0x0E, 0x0E, ".{ decode_push_pop_seg,       .PUSH,        }");
    #insert #run assign_op_info_range(0x10, 0x13, ".{ decode_arith_reg_with_rm,  .ADC,         }");
    #insert #run assign_op_info_range(0x14, 0x15, ".{ decode_arith_imm_to_accum, .ADC,         }");
    #insert #run assign_op_info_range(0x16, 0x16, ".{ decode_push_pop_seg,       .PUSH,        }");
    #insert #run assign_op_info_range(0x17, 0x17, ".{ decode_push_pop_seg,       .POP,         }");
    #insert #run assign_op_info_range(0x1E, 0x1E, ".{ decode_push_pop_seg,       .PUSH,        }");
    #insert #run assign_op_info_range(0x1F, 0x1F, ".{ decode_push_pop_seg,       .POP,         }");
    #insert #run assign_op_info_range(0x28, 0x2B, ".{ decode_arith_reg_with_rm,  .SUB,         }");
    #insert #run assign_op_info_range(0x2C, 0x2D, ".{ decode_arith_imm_to_accum, .SUB,         }");
    #insert #run assign_op_info_range(0x38, 0x3B, ".{ decode_arith_reg_with_rm,  .CMP,         }");
    #insert #run assign_op_info_range(0x3C, 0x3D, ".{ decode_arith_imm_to_accum, .CMP,         }");
    #insert #run assign_op_info_range(0x70, 0x70, ".{ decode_jump_cond_inc8,     .JO,          }");
    #insert #run assign_op_info_range(0x71, 0x71, ".{ decode_jump_cond_inc8,     .JNO,         }");
    #insert #run assign_op_info_range(0x72, 0x72, ".{ decode_jump_cond_inc8,     .JB_JNAE_JC,  }");
    #insert #run assign_op_info_range(0x73, 0x73, ".{ decode_jump_cond_inc8,     .JNB_JAE_JNC, }");
    #insert #run assign_op_info_range(0x74, 0x74, ".{ decode_jump_cond_inc8,     .JE_JZ,       }");
    #insert #run assign_op_info_range(0x75, 0x75, ".{ decode_jump_cond_inc8,     .JNE_JNZ,     }");
    #insert #run assign_op_info_range(0x76, 0x76, ".{ decode_jump_cond_inc8,     .JBE_JNA,     }");
    #insert #run assign_op_info_range(0x77, 0x77, ".{ decode_jump_cond_inc8,     .JNBE_JA,     }");
    #insert #run assign_op_info_range(0x78, 0x78, ".{ decode_jump_cond_inc8,     .JS,          }");
    #insert #run assign_op_info_range(0x79, 0x79, ".{ decode_jump_cond_inc8,     .JNS,         }");
    #insert #run assign_op_info_range(0x7A, 0x7A, ".{ decode_jump_cond_inc8,     .JP_JPE,      }");
    #insert #run assign_op_info_range(0x7B, 0x7B, ".{ decode_jump_cond_inc8,     .JNP_JPO,     }");
    #insert #run assign_op_info_range(0x7C, 0x7C, ".{ decode_jump_cond_inc8,     .JL_JNGE,     }");
    #insert #run assign_op_info_range(0x7D, 0x7D, ".{ decode_jump_cond_inc8,     .JNL_JGE,     }");
    #insert #run assign_op_info_range(0x7E, 0x7E, ".{ decode_jump_cond_inc8,     .JLE_JNG,     }");
    #insert #run assign_op_info_range(0x7F, 0x7F, ".{ decode_jump_cond_inc8,     .JNLE_JG,     }");
    #insert #run assign_op_info_range(0xE0, 0xE0, ".{ decode_jump_cond_inc8,     .LOOPNZ,      }");
    #insert #run assign_op_info_range(0xE1, 0xE1, ".{ decode_jump_cond_inc8,     .LOOPZ,       }");
    #insert #run assign_op_info_range(0xE2, 0xE2, ".{ decode_jump_cond_inc8,     .LOOP,        }");
    #insert #run assign_op_info_range(0xE3, 0xE3, ".{ decode_jump_cond_inc8,     .JCXZ,        }");
    #insert #run assign_op_info_range(0x80, 0x83, ".{ decode_arith_imm_to_rm,    .INVALID,     }");
    #insert #run assign_op_info_range(0x88, 0x8c, ".{ decode_mov,                .MOV,         }");
    #insert #run assign_op_info_range(0xFF, 0xFF, ".{ decode_push_pop_rm,        .PUSH,        }");
    #insert #run assign_op_info_range(0x50, 0x57, ".{ decode_push_pop_reg,       .PUSH,        }");
    #insert #run assign_op_info_range(0x8F, 0x8F, ".{ decode_push_pop_rm,        .POP,         }");
    #insert #run assign_op_info_range(0x58, 0x5F, ".{ decode_push_pop_reg,       .POP,         }");
    #insert #run assign_op_info_range(0xa0, 0xa3, ".{ decode_mov_accumulator,    .MOV,         }");
    #insert #run assign_op_info_range(0xb0, 0xbf, ".{ decode_mov_imm_to_reg,     .MOV,         }");
    #insert #run assign_op_info_range(0xc6, 0xc7, ".{ decode_mov_imm_to_rm,      .MOV,         }");
}
opcode_table: Opcode_Table;
#run (){
    vacant_count := 0;
    for opcode_table.ops {
        if !it.decode  vacant_count += 1;
    }
    print("There are % of % unimplemented instructions\n\n", vacant_count, opcode_table.ops.count);
}();

formatHex :: #bake_arguments formatInt(base=16);

memory_mode :: inline (mod: u8) -> Memory_Mode {
    assert(!(mod & ~0x03));
    return cast(Memory_Mode)mod;
}

// NOTE(ryan): directly indexed by "(reg << 1) | field_w".
register_name_table :: string.[
                //   reg  : register encoding
                //      w : width (0: byte, 1: word)
    "al", "ax", // 0b000w
    "cl", "cx", // 0b001w
    "dl", "dx", // 0b010w
    "bl", "bx", // 0b011w
    "ah", "sp", // 0b100w
    "ch", "bp", // 0b101w
    "dh", "si", // 0b110w
    "bh", "di", // 0b111w
];
// NOTE(ryan): directly indexed by 2-bit "seg".
segment_name_table :: string.[
          //   reg  : register encoding
          //      w : width (0: byte, 1: word)
    "es", // 0b00
    "cs", // 0b01
    "ss", // 0b10
    "ds", // 0b11
];
effective_address_table :: Memory.[
    .{ base1 = "bx", base2 = "si", },
    .{ base1 = "bx", base2 = "di", },
    .{ base1 = "bp", base2 = "si", },
    .{ base1 = "bp", base2 = "di", },
    .{ base1 = "si", },
    .{ base1 = "di", },
    .{ base1 = "bp", },
    .{ base1 = "bx", },
];
register :: (reg: u8, word: u8) -> Register {
    assert(word <= 1);
    index := (reg << 1) | word;
    assert(index < register_name_table.count);

    return register_name_table[index];
}
segment :: inline (seg: u8) -> Register {
    assert(seg < 4);
    return segment_name_table[seg];
}
operand_register :: inline (reg: u8, word: u8) -> Operand {
    return Operand.{ type = .REGISTER, reg = register(reg, word) };
}
operand_register :: inline (name: string) -> Operand {
    return Operand.{ type = .REGISTER, reg = name };
}
operand_segment :: inline (seg: u8) -> Operand {
    return Operand.{ type = .REGISTER, reg = segment(seg) };
}
operand_memory :: inline (mem: Memory) -> Operand {
    return Operand.{ type = .MEMORY, mem = mem };
}
operand_memory :: inline (field_rm: u8, disp: u16) -> Operand {
    assert(field_rm < effective_address_table.count);
    operand: Operand;
    operand.type = .MEMORY;
    operand.mem = effective_address_table[field_rm];
    operand.mem.disp = disp;
    return operand;
}
operand_memory_direct :: inline (addr: u16) -> Operand {
    return Operand.{ type = .MEMORY, mem = Memory.{ direct = addr } };
}
immediate :: inline (low: u8, high: u8 = 0) -> u16 {
    return ((cast(u16)high) << 8) | cast(u16)low;
}
operand_immediate :: inline (low: u8, high: u8 = 0, size: Operand_Size = .IMPLICIT) -> Operand {
    return Operand.{ type = .IMMEDIATE, size = size, imm = Immediate.{ val = immediate(low, high) }};
}
operand_increment :: inline (low: u8) -> Operand {
    return Operand.{ type = .INCREMENT, inc = Increment.{ val = cast(s16)(cast,no_check(s8)low) } };
}
operand_increment :: inline (low: u8, high: u8) -> Operand {
    return Operand.{ type = .INCREMENT, inc = Increment.{ val = ((cast,no_check(s16)high) << 8) | cast,no_check(s16)low } };
}

operand_to_string :: (inst: Instruction, operand: Operand) -> string {
    assert(operand.type != .INVALID);

    if #complete operand.type == {
        case .REGISTER;
            return operand.reg;
        case .INCREMENT;
            builder: String_Builder;
            builder.allocator = temporary_allocator;

            // HACK(ryan): relying on size of JNZ instruction is 2 bytes (so offset is relative to
            // "after decoding JNZ instruction"). We could emit labels instead with a slightly more
            // sophisticated disassembly loop.
            // TODO(ryan): consider storing instruction size on Increment for flexibility here;
            append(*builder, "$+2");
            inc := inst.dst.inc.val;
            if (inc) {
                if inc > 0  print_to_builder(*builder, " + %", inc);
                else        print_to_builder(*builder, " - %", -inc);
            }
            return builder_to_string(*builder);
        case .IMMEDIATE;
            explicit_size := "";
            if operand.size      == .BYTE  explicit_size = "byte ";
            else if operand.size == .WORD  explicit_size = "word ";
            return tprint("%0%0", explicit_size, operand.imm.val);
        case .MEMORY; {
            mem := *operand.mem;

            builder: String_Builder;
            builder.allocator = temporary_allocator;

            // push/pop require it
            if operand.size == .BYTE
                print_to_builder(*builder, "byte ");
            else if operand.size == .WORD
                print_to_builder(*builder, "word ");

            if (inst.mode == .MEM_DIRECT) {
                print_to_builder(*builder, "[%]", mem.direct);
            } else {
                print_to_builder(*builder, "[%", mem.base1);
                if mem.base2.count
                    print_to_builder(*builder, " + %", mem.base2);
                if mem.disp {
                    disp := ifx inst.mode == .MEM_DISP_8 then
                        cast,no_check(s8)mem.disp else
                        cast,no_check(s16)mem.disp;
                    if disp > 0  print_to_builder(*builder, " + %", disp);
                    else         print_to_builder(*builder, " - %", -disp);
                }
                append(*builder, "]");
            }
            return builder_to_string(*builder);
        }
        case .INVALID; assert(false, "Operand type has not been set");
    }
};

_decode_immediate :: (head_imm: *u8, field_s: u8, field_w: u8, implicit_size: bool = false) -> (Operand, bytes_read: s32) {
    advance_count: s32;
    imm: Operand;

    if (!field_w || field_s) {
        field_low := <<(head_imm);
        imm = operand_immediate(field_low, 0, ifx field_s then Operand_Size.WORD else .BYTE);
        advance_count = 1;
    } else {
        field_low  := <<(head_imm);
        field_high := <<(head_imm + 1);
        imm = operand_immediate(field_low, field_high, .WORD);
        advance_count = 2;
    }

    imm.size = ifx implicit_size then .IMPLICIT else imm.size;

    return imm, advance_count;
}

_decode_rm :: (head_disp: *u8, in_mode: *Memory_Mode, field_rm: u8, field_w: u8) -> (Operand, bytes_read: s32) {
    advance_count: s32;
    rm: Operand;
    mode := <<in_mode;

    if (mode == .REGISTER) {
        rm = operand_register(field_rm, field_w);
        advance_count = 0;
    } else {
        rm = operand_memory(field_rm, 0);

        if (mode != .MEM_NO_DISP) {
            field_low  := <<(head_disp);
            field_high := ifx mode == .MEM_DISP_16 then <<(head_disp + 1) else 0;
            rm.mem.disp = immediate(field_low, field_high);
        }

        if (field_rm == 0b110 && mode == .MEM_NO_DISP) {
            // DIRECT ADDRESSING
            field_low  := <<(head_disp);
            field_high := <<(head_disp + 1);
            <<in_mode = .MEM_DIRECT;
            rm = operand_memory_direct(immediate(field_low, field_high));
            advance_count = 2;
        } else {
            assert(mode < 3);
            advance_count = cast(s32)mode;
        }
    }

    return rm, advance_count;
}

decode_arith_reg_with_rm :: (op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32) {
    field_inst := (<<head       & 0b0001_0000) >> 4;
    field_d    := (<<head       & 0b0000_0010) >> 1;
    field_w    := (<<head       & 0b0000_0001);
    field_mod  := (<<(head + 1) & 0b1100_0000) >> 6;
    field_reg  := (<<(head + 1) & 0b0011_1000) >> 3;
    field_rm   := (<<(head + 1) & 0b0000_0111);

    inst: Instruction;
    inst.mode = memory_mode(field_mod);
    inst.desc = "Reg/memory with register to either";

    reg := operand_register(field_reg, field_w);
    rm, extra_advance := _decode_rm(head + 2, *inst.mode, field_rm, field_w);

    inst.dst = ifx field_d then reg else rm;
    inst.src = ifx field_d then rm  else reg;

    if DEBUG {
        print("% %, %  ; {first_byte=0x%, d=% w=%, mod=% reg=% rm=%} (%)\n",
            mnemonic_string(op_info.type), operand_to_string(inst, inst.dst), operand_to_string(inst, inst.src),
            formatHex(<<head), field_d, field_w, field_mod, field_reg, field_rm, inst.desc);
    }

    return inst, 2 + extra_advance;
}

decode_arith_imm_to_rm :: (op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32) {
    field_s    := (<<head       & 0b0000_0010) >> 1;
    field_w    := (<<head       & 0b0000_0001);
    field_mod  := (<<(head + 1) & 0b1100_0000) >> 6;
    field_inst := (<<(head + 1) & 0b0011_1000) >> 3;
    field_rm   := (<<(head + 1) & 0b0000_0111);

    inst: Instruction;
    inst.desc = "immediate to register/memory";
    inst.mode = memory_mode(field_mod);

    // the instruction is not known from the first byte, so we must determine in this dispatch
    // handler.
    assert(op_info.type == .INVALID);
    if field_inst == {
        case 0;
            op_info.type = .ADD;
        case 0b010;
            op_info.type = .ADC;
        case 0b101;
            op_info.type = .SUB;
        case 0b111;
            op_info.type = .CMP;
        case; assert(false, "% NOT IMPLEMENTED", field_inst);
    }

    offset: s32 = 2;
    rm, extra_advance := _decode_rm(head + offset, *inst.mode, field_rm, field_w);
    offset += extra_advance;
    imm, extra_advance2 := _decode_immediate(head + offset, field_s, field_w, implicit_size=inst.mode == .REGISTER);
    offset += extra_advance2;

    inst.src = imm;
    inst.dst = rm;

    if DEBUG {
        print("% %, %  ; {first_byte=0x%, s=% w=%, mod=% inst=% rm=%} (%)\n",
            mnemonic_string(op_info.type), operand_to_string(inst, inst.dst), operand_to_string(inst, inst.src),
            formatHex(<<head), field_s, field_w, field_mod, field_inst, field_rm, inst.desc);
    }

    return inst, offset;
}

decode_arith_imm_to_accum :: (op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32) {
    field_inst := (<<head & 0b1111_1110) >> 1;
    field_w    := (<<head & 0b0000_0001);
    field_low  := <<(head + 1);
    field_high := ifx field_w then <<(head + 2) else 0;

    inst: Instruction;
    inst.desc = "immediate to accumulator";

    inst.dst = operand_register(ifx field_w then "ax" else "al");
    inst.src = operand_immediate(field_low, field_high);

    if DEBUG {
        print("% %, %  ; {first_byte=0x%, inst=% w=%} (%)\n",
            mnemonic_string(op_info.type), operand_to_string(inst, inst.dst), operand_to_string(inst, inst.src),
            formatHex(<<head), field_inst, field_w, inst.desc);
    }

    return inst, 2 + field_w;
}

decode_jump_cond_inc8 :: (op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32) {
    inst: Instruction;
    inst.operand_count = .UNARY;
    inst.desc = "jump short (8-bit) if condition is met";
    inst.dst = operand_increment(<<(head +1));

    if DEBUG {
        print("% %  ; {first_byte=0x%, increment=%} (%)\n",
            mnemonic_string(op_info.type), operand_to_string(inst, inst.dst), formatHex(<<head),
            inst.dst.inc.val, inst.desc);
    }

    return inst, 2;
}

decode_mov :: (op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32) {
    field_d   := (<< head      & 0b0000_0010) >> 1;
    field_w   := (<< head      & 0b0000_0001);
    field_mod := (<<(head + 1) & 0b1100_0000) >> 6;
    field_reg := (<<(head + 1) & 0b0011_1000) >> 3;
    field_rm  := (<<(head + 1) & 0b0000_0111);

    inst: Instruction;
    inst.desc = "register/memory to/from register";
    inst.mode = memory_mode(field_mod);

    reg := operand_register(field_reg, field_w);
    rm, extra_advance := _decode_rm(head + 2, *inst.mode, field_rm, field_w);

    inst.src  = ifx field_d then rm  else reg;
    inst.dst  = ifx field_d then reg else rm;

    if DEBUG {
        print("% %, %  ; {first_byte=0x%, d=% w=%, mod=% reg=% rm=%} (%)\n",
            mnemonic_string(op_info.type), operand_to_string(inst, inst.dst), operand_to_string(inst, inst.src),
            formatHex(<<head), field_d, field_w, field_mod, field_reg, field_rm, inst.desc);
    }

    return inst, 2 + extra_advance;
}

decode_mov_imm_to_reg :: (op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32) {
    field_w    := (<< head       & 0b0000_1000) >> 3;
    field_reg  :=  << head       & 0b0000_0111;
    field_low  :=  <<(head + 1);
    field_high :=  ifx field_w then <<(head + 2) else 0;

    inst: Instruction;
    inst.desc = "immediate to register";

    inst.dst = operand_register(field_reg, field_w);
    inst.src = operand_immediate(field_low, field_high);
    advance_count := cast(s32)(ifx field_w then 3 else 2);

    if DEBUG {
        print("% %, %  ; {first_byte=0x%, w=% reg=%, low=%, high=%} (%)\n",
            mnemonic_string(op_info.type), operand_to_string(inst, inst.dst), operand_to_string(inst, inst.src),
            formatHex(<<head), field_w, field_reg, field_low, field_high, inst.desc);
    }

    return inst, advance_count;
}

decode_mov_imm_to_rm :: (op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32) {
    field_w := <<head & 0b0000_0001;
    field_mod := (<<(head + 1) & 0b1100_0000) >> 6;
    field_rm  := (<<(head + 1) & 0b0000_0111);

    inst: Instruction;
    inst.desc = "move immediate to register";
    inst.mode = memory_mode(field_mod);

    offset: s32 = 2;
    rm, extra_advance := _decode_rm(head + offset, *inst.mode, field_rm, field_w);
    inst.dst = rm;
    offset += extra_advance;

    imm, extra_advance2 := _decode_immediate(head + offset, 0, field_w, implicit_size=inst.mode == .REGISTER);
    inst.src = imm;
    offset += extra_advance2;

    if DEBUG {
        print("% %, %  ; {first_byte=0x%, w=%} (%)\n",
        mnemonic_string(op_info.type), operand_to_string(inst, inst.dst), operand_to_string(inst, inst.src),
        formatHex(<<head), field_w, inst.desc);
    }

    return inst, offset;
}

decode_mov_accumulator :: (op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32) {
    inst: Instruction;
    inst.desc = "memory to/from accumulator";
    inst.mode = .MEM_DIRECT;

    field_to_mem := (<<head & 0b10) >> 1;
    field_w      :=  <<head & 0b01;

    field_low  := <<(head + 1);
    field_high := <<(head + 2);

    reg := operand_register(ifx field_w then "ax" else "al");
    mem := operand_memory_direct(immediate(field_low, field_high));

    inst.dst = ifx field_to_mem then mem else reg;
    inst.src = ifx field_to_mem then reg else mem;

    if DEBUG {
        print("% %, %  ; {first_byte=0x%, to_mem=%, w=%} (%)\n",
            mnemonic_string(op_info.type), operand_to_string(inst, inst.dst), operand_to_string(inst, inst.src),
            formatHex(<<head), field_to_mem, field_w, inst.desc);
    }

    return inst, 3;
}

decode_push_pop_rm :: (op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32) {
    field_mod := (<<(head + 1) & 0b1100_0000) >> 6;
    field_rm  := (<<(head + 1) & 0b0000_0111);

    inst: Instruction;
    inst.desc = "register or memory to/from stack";
    inst.mode = memory_mode(field_mod);
    inst.operand_count = .UNARY;

    rm, advance_extra := _decode_rm(head + 2, *inst.mode, field_rm, 1);
    inst.dst = rm;
    inst.dst.size = .WORD;

    if DEBUG {
        print("% %  ; {first_byte=0x%, mod=% rm=%} (%)\n",
            mnemonic_string(op_info.type), operand_to_string(inst, inst.dst),
            formatHex(<<head), field_mod, field_rm, inst.desc);
    }

    return inst, 2 + advance_extra;
}

decode_push_pop_reg :: (op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32) {
    field_reg := (<<(head) & 0b0000_0111);

    inst: Instruction;
    inst.desc = "register to/from stack";
    inst.operand_count = .UNARY;

    inst.dst = operand_register(field_reg, 1);

    if DEBUG {
        print("% %  ; {first_byte=0x%, reg=%} (%)\n",
            mnemonic_string(op_info.type), operand_to_string(inst, inst.dst),
            formatHex(<<head), field_reg, inst.desc);
    }

    return inst, 1;
}

decode_push_pop_seg :: (op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32) {
    field_seg := (<<(head) & 0b0001_1000) >> 3;

    inst: Instruction;
    inst.desc = "segment register to/from stack";
    inst.operand_count = .UNARY;

    inst.dst = operand_segment(field_seg);

    if DEBUG {
        print("% %  ; {first_byte=0x%, seg=%} (%)\n",
            mnemonic_string(op_info.type), operand_to_string(inst, inst.dst),
            formatHex(<<head), field_seg, inst.desc);
    }

    return inst, 1;
}

decode_once :: (offset: s64, head: *u8) -> (Instruction, advance: s64) {
    opcode := (0b1111_1111 & (<<head));
    assert(opcode < opcode_table.ops.count);
    op_info := opcode_table.ops[opcode];

    if !op_info.decode
        assert(false, "Unknown opcode for first byte: 0x%", formatHex(<<head));

    inst, advance_count := op_info.decode(*op_info, head);
    inst.type = op_info.type;

    assert(inst.type != .INVALID, "Instruction dispatch handler must resolve instruction if not resolvable automatically from the first byte");
    assert(inst.desc.count > 0, "Instruction dispatch handler must provide a description");

    return inst, advance_count;
}

disassemble :: (bytes: []u8, output_asm_path: string="out.asm") {
    builder: String_Builder;

    offset := 0;
    while offset < bytes.count {
        head := bytes.data + offset;
        inst, advance := decode_once(offset, head);
        offset += advance;

        // TODO(ryan): add a ".UNARY" flag for these instead
        if (inst.operand_count == .UNARY) {
            print_to_builder(*builder, "% %\n", mnemonic_string(inst.type), operand_to_string(inst, inst.dst));
        } else {
            print_to_builder(*builder, "% %, %\n", mnemonic_string(inst.type), operand_to_string(inst, inst.dst), operand_to_string(inst, inst.src));
        }
    }

    file, success := file_open(output_asm_path, for_writing=true, keep_existing_content=false);
    if !success
        assert(false);

    file_write(*file, "; auto-generated 8086 disassembly\n");
    file_write(*file, "bits 16\n\n");
    file_write(*file, *builder);
    file_close(*file);
}

main :: () {
    // f := "../cmuratori-computer_enhance/perfaware/part1/listing_0037_single_register_mov";
    // f := "../cmuratori-computer_enhance/perfaware/part1/listing_0038_many_register_mov";
    // f := "../cmuratori-computer_enhance/perfaware/part1/listing_0039_more_movs";
    // f := "../cmuratori-computer_enhance/perfaware/part1/listing_0040_challenge_movs";
    // f := "../cmuratori-computer_enhance/perfaware/part1/listing_0041_add_sub_cmp_jnz";
    f := "../cmuratori-computer_enhance/perfaware/part1/listing_0042_completionist_decode";

    args := get_command_line_arguments();
    if args.count > 1 && equal(args[1], "test") {
        input_files := string.[
            "../cmuratori-computer_enhance/perfaware/part1/listing_0037_single_register_mov.asm",
            "../cmuratori-computer_enhance/perfaware/part1/listing_0038_many_register_mov.asm",
            "../cmuratori-computer_enhance/perfaware/part1/listing_0039_more_movs.asm",
            "../cmuratori-computer_enhance/perfaware/part1/listing_0040_challenge_movs.asm",
            "../cmuratori-computer_enhance/perfaware/part1/listing_0041_add_sub_cmp_jnz.asm",
            "../cmuratori-computer_enhance/perfaware/part1/listing_0042_completionist_decode.asm",
        ];
        run_tests(input_files);
    } else {
        bytes := file_read_all_as_bytes(f);
        disassemble(bytes);
    }
}
