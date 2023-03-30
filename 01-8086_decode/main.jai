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
Immediate_Type :: enum {
    IMPLICIT;
    BYTE;
    WORD;
}
Immediate :: struct {
    type: Immediate_Type;
    val: u16;
}
Operand_Type :: enum {
    REGISTER;
    MEMORY;
    IMMEDIATE;
}
Operand :: struct {
    type: Operand_Type;
    union {
        reg: Register;
        mem: Memory;
        imm: Immediate;
    };
}

// TODO(ryan): Hook the compilation-loop and populate the matched-index table automatically
Instruction_Type :: enum u32 {
    INVALID :: 0;
    ADC;          // @mnemonic:adc
    ADD;          // @mnemonic:add
    CMP;          // @mnemonic:cmp
    SUB;          // @mnemonic:sub
    MOV;          // @mnemonic:mov
    _ENUM_COUNT;
}
Mnemonic_Table :: struct {
    strings: [Instruction_Type._ENUM_COUNT]string;
    strings[Instruction_Type.ADD] = "add";
    strings[Instruction_Type.ADC] = "adc";
    strings[Instruction_Type.CMP] = "cmp";
    strings[Instruction_Type.SUB] = "sub";
    strings[Instruction_Type.MOV] = "mov";
}
mnemonic_table: Mnemonic_Table;
mnemonic_string :: inline (type: Instruction_Type) -> string {
    assert(type != .INVALID);
    assert(cast(s64)type < mnemonic_table.strings.count);
    return mnemonic_table.strings[type];
}

Instruction :: struct {
    type:     Instruction_Type;
    mode:     Memory_Mode;

    // TODO(ryan): maybe store *Opcode_Info for indirection instead?
    desc:     string;

    src:      Operand;
    dst:      Operand;
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
        for opcode: first..last {
            print_to_builder(*builder, "ops[%] = %;\n", opcode, op_info_string);
            // print("ops[%] = %\n", opcode, op_info_string);
        }
        return builder_to_string(*builder);
    }
    #insert #run assign_op_info_range(0x00, 0x03, ".{ decode_arith_reg_with_rm,  .ADD,     }");
    #insert #run assign_op_info_range(0x04, 0x05, ".{ decode_arith_imm_to_accum, .ADD,     }");
    #insert #run assign_op_info_range(0x10, 0x13, ".{ decode_arith_reg_with_rm,  .ADC,     }");
    #insert #run assign_op_info_range(0x14, 0x15, ".{ decode_arith_imm_to_accum, .ADC,     }");
    #insert #run assign_op_info_range(0x28, 0x2B, ".{ decode_arith_reg_with_rm,  .SUB,     }");
    #insert #run assign_op_info_range(0x2C, 0x2D, ".{ decode_arith_imm_to_accum, .SUB,     }");
    #insert #run assign_op_info_range(0x38, 0x3B, ".{ decode_arith_reg_with_rm,  .CMP,     }");
    #insert #run assign_op_info_range(0x3C, 0x3D, ".{ decode_arith_imm_to_accum, .CMP,     }");
    #insert #run assign_op_info_range(0x80, 0x83, ".{ decode_arith_imm_to_rm,    .INVALID, }");
    #insert #run assign_op_info_range(0x88, 0x8c, ".{ decode_mov,                .MOV,     }");
    #insert #run assign_op_info_range(0xa0, 0xa3, ".{ decode_mov_accumulator,    .MOV,     }");
    #insert #run assign_op_info_range(0xb0, 0xbf, ".{ decode_mov_imm_to_reg,     .MOV,     }");
    #insert #run assign_op_info_range(0xc6, 0xc7, ".{ decode_mov_imm_to_rm,      .MOV,     }");
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
operand_register :: inline (reg: u8, word: u8) -> Operand {
    return Operand.{ type = .REGISTER, reg = register(reg, word) };
}
operand_register :: inline (name: string) -> Operand {
    return Operand.{ type = .REGISTER, reg = name };
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
operand_immediate :: inline (low: u8, high: u8 = 0, type: Immediate_Type = .IMPLICIT) -> Operand {
    return Operand.{ type = .IMMEDIATE, imm = Immediate.{ type = type, val = immediate(low, high) }};
}

operand_to_string :: (inst: Instruction, operand: Operand) -> string {
    if #complete operand.type == {
        case .REGISTER;
            return operand.reg;
        case .IMMEDIATE;
            explicit_size := "";
            if operand.imm.type      == .BYTE  explicit_size = "byte ";
            else if operand.imm.type == .WORD  explicit_size = "word ";
            return tprint("%0%0", explicit_size, operand.imm.val);
        case .MEMORY; {
            mem := *operand.mem;

            if (inst.mode == .MEM_DIRECT) {
                return tprint("[%]", mem.direct);
            } else {
                builder: String_Builder;
                builder.allocator = temporary_allocator;

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

                return builder_to_string(*builder);
            }
        }
    }
};

_decode_immediate :: (head_imm: *u8, field_s: u8, field_w: u8, implicit_size: bool = false) -> (Operand, bytes_read: s32) {
    advance_count: s32;
    imm: Operand;

    if (!field_w || field_s) {
        field_low := <<(head_imm);
        imm = operand_immediate(field_low, 0, ifx field_s then Immediate_Type.WORD else .BYTE);
        advance_count = 1;
    } else {
        field_low  := <<(head_imm);
        field_high := <<(head_imm + 1);
        imm = operand_immediate(field_low, field_high, .WORD);
        advance_count = 2;
    }

    imm.imm.type = ifx implicit_size then .IMPLICIT else imm.imm.type;

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

decode_once :: (offset: s64, head: *u8) -> (Instruction, advance: s64) {
    opcode := (0b1111_1111 & (<<head));
    assert(opcode < opcode_table.ops.count);
    op_info := opcode_table.ops[opcode];

    if !op_info.decode
        assert(false, "Unknown opcode for first byte: 0x%", formatHex(<<head));

    inst, advance_count := op_info.decode(*op_info, head);
    inst.type = op_info.type;
    inst.desc = inst.desc;
    return inst, advance_count;
}

disassemble :: (bytes: []u8, output_asm_path: string="out.asm") {
    builder: String_Builder;

    offset := 0;
    while offset < bytes.count {
        head := bytes.data + offset;
        inst, advance := decode_once(offset, head);
        assert(inst.type != .INVALID);
        assert(inst.desc.count > 0);

        print_to_builder(*builder, "% %, %\n", mnemonic_string(inst.type), operand_to_string(inst, inst.dst), operand_to_string(inst, inst.src));
        offset += advance;
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
    f := "../cmuratori-computer_enhance/perfaware/part1/listing_0041_add_sub_cmp_jnz";

    args := get_command_line_arguments();
    if args.count > 1 && equal(args[1], "test") {
        input_files := string.[
            "../cmuratori-computer_enhance/perfaware/part1/listing_0037_single_register_mov.asm",
            "../cmuratori-computer_enhance/perfaware/part1/listing_0038_many_register_mov.asm",
            "../cmuratori-computer_enhance/perfaware/part1/listing_0039_more_movs.asm",
            "../cmuratori-computer_enhance/perfaware/part1/listing_0040_challenge_movs.asm",
            "../cmuratori-computer_enhance/perfaware/part1/listing_0041_add_sub_cmp_jnz.asm",
        ];
        run_tests(input_files);
    } else {
        bytes := file_read_all_as_bytes(f);
        disassemble(bytes);
    }
}
