#import "Basic";
#import "File_Utilities";
#import "Process";
#import "String";

#load "file.jai";

DEBUG := true;
USE_TABLE_DISPATCH :: true;

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

Instruction_Type :: enum {
    INVALID :: 0;
    MOV;
    ADD;
}
Instruction :: struct {
    type:     Instruction_Type;
    mode:     Memory_Mode;

    // TODO(ryan): maybe store *Opcode_Info for indirection instead?
    mnemonic: string;
    desc:     string;

    src:      Operand;
    dst:      Operand;
}

Decode_Proc :: #type (op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32);
Opcode_Info :: struct {
    decode:   Decode_Proc;
    mnemonic: string;
    desc:     string;
}

#if USE_TABLE_DISPATCH {
// NOTE(ryan): jai only supports indexed sparse initialization of arrays *inside structs* for now.
Opcode_Table :: struct {
    ops: [256]Opcode_Info;

    assign_op_info_range :: (first: u8, last: u8, op_info_string: string) -> string {
        builder: String_Builder;
        for opcode: first..last
            print_to_builder(*builder, "ops[%] = %;\n", opcode, op_info_string);
        return builder_to_string(*builder);
    }
    #insert #run assign_op_info_range(0x00, 0x03, ".{ decode_add,                \"add\", \"add\" }");
    #insert #run assign_op_info_range(0x88, 0x8c, ".{ decode_mov,                \"mov\", \"move register/memory to/from register\" }");
    #insert #run assign_op_info_range(0xa0, 0xa3, ".{ decode_mov_accumulator,    \"mov\", \"move memory to/from accumulator\"       }");
    #insert #run assign_op_info_range(0xb0, 0xbf, ".{ decode_mov_imm_to_reg,     \"mov\", \"move immediate to register\"            }");
    #insert #run assign_op_info_range(0xc6, 0xc7, ".{ decode_mov_imm_to_reg_mem, \"mov\", \"move memory to/from accumulator\"       }");
}

opcode_table: Opcode_Table;
}

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

decode_rm :: (head_disp: *u8, in_mode: *Memory_Mode, field_rm: u8, field_w: u8) -> (Operand, bytes_read: s32) {
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

decode_add :: (op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32) {
    inst: Instruction;
    inst.type = .ADD;

    field_w := (<<head & 0b0000_0001);

    advance_count: s32;
    if !(<<head & 0b1111_1100) {
        inst.desc = "Reg/memory with register to either";

        field_d := cast(bool)(<<head & 0b10);
        field_mod := (<<(head + 1) & 0b1100_0000) >> 6;
        field_reg := (<<(head + 1) & 0b0011_1000) >> 3;
        field_rm  := (<<(head + 1) & 0b0000_0111);

        inst.mode = memory_mode(field_mod);

        reg := operand_register(field_reg, field_w);
        rm, extra_advance := decode_rm(head + 2, *inst.mode, field_rm, field_w);

        inst.dst = ifx field_d then reg else rm;
        inst.src = ifx field_d then rm  else reg;

        advance_count = 2 + extra_advance;

        if DEBUG {
            print("% %, %  ; {first_byte=0x%, d=% w=%, mod=% reg=% rm=%} (%)\n",
                op_info.mnemonic, operand_to_string(inst, inst.dst), operand_to_string(inst, inst.src),
                formatHex(<<head), field_d, field_w, field_mod, field_reg, field_rm, op_info.desc);
        }
    } else if <<head & 0b1000_0000 {
        assert(false, "NOT IMPLEMENTED");
    } else {
        assert(cast(bool)(<<head & 0b0000_0100));
        assert(false, "NOT IMPLEMENTED");
    }

    return inst, advance_count;
}

decode_mov :: (op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32) {
    field_d   := (<< head      & 0b0000_0010) >> 1;
    field_w   := (<< head      & 0b0000_0001);
    field_mod := (<<(head + 1) & 0b1100_0000) >> 6;
    field_reg := (<<(head + 1) & 0b0011_1000) >> 3;
    field_rm  := (<<(head + 1) & 0b0000_0111);

    inst: Instruction;
    inst.type = .MOV;
    inst.mode = memory_mode(field_mod);

    reg := operand_register(field_reg, field_w);
    rm, extra_advance := decode_rm(head + 2, *inst.mode, field_rm, field_w);

    inst.src  = ifx field_d then rm  else reg;
    inst.dst  = ifx field_d then reg else rm;

    if DEBUG {
        print("% %, %  ; {first_byte=0x%, d=% w=%, mod=% reg=% rm=%} (%)\n",
            op_info.mnemonic, operand_to_string(inst, inst.dst), operand_to_string(inst, inst.src),
            formatHex(<<head), field_d, field_w, field_mod, field_reg, field_rm, op_info.desc);
    }

    return inst, 2 + extra_advance;
}

decode_mov_imm_to_reg :: (op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32) {
    field_w    := (<< head       & 0b0000_1000) >> 3;
    field_reg  :=  << head       & 0b0000_0111;
    field_low  :=  <<(head + 1);
    field_high :=  ifx field_w then <<(head + 2) else 0;

    inst: Instruction;
    inst.type = .MOV;

    inst.dst = operand_register(field_reg, field_w);
    inst.src = operand_immediate(field_low, field_high);
    advance_count := cast(s32)(ifx field_w then 3 else 2);

    if DEBUG {
        print("% %, %  ; {first_byte=0x%, w=% reg=%, low=%, high=%} (%)\n",
            op_info.mnemonic, operand_to_string(inst, inst.dst), operand_to_string(inst, inst.src),
            formatHex(<<head), field_w, field_reg, field_low, field_high, op_info.desc);
    }

    return inst, advance_count;
}

decode_mov_imm_to_reg_mem :: (op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32) {
    field_w := <<head & 0b0000_0001;
    field_mod := (<<(head + 1) & 0b1100_0000) >> 6;
    field_rm  := (<<(head + 1) & 0b0000_0111);

    inst: Instruction;
    inst.type = .MOV;
    inst.mode = memory_mode(field_mod);

    offset: s32 = 2;
    rm, extra_advance := decode_rm(head + offset, *inst.mode, field_rm, field_w);
    inst.dst = rm;
    offset += extra_advance;

    if (!field_w) {
        field_low := <<(head + offset);
        inst.src = operand_immediate(field_low, 0, .BYTE);
        offset += 1;
    } else {
        field_low  := <<(head + offset);
        field_high := <<(head + offset + 1);
        inst.src = operand_immediate(field_low, field_high, .WORD);
        offset += 2;
    }

    if DEBUG {
        print("% %, %  ; {first_byte=0x%, w=%} (%)\n",
        op_info.mnemonic, operand_to_string(inst, inst.dst), operand_to_string(inst, inst.src),
        formatHex(<<head), field_w, op_info.desc);
    }

    return inst, offset;
}

decode_mov_accumulator :: (op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32) {
    inst: Instruction;
    inst.type = .MOV;
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
        print("% %, %  ; {first_byte=0x%, to_mem=%, w=%}\n",
            op_info.mnemonic, operand_to_string(inst, inst.dst), operand_to_string(inst, inst.src),
            formatHex(<<head), field_to_mem, field_w);
    }

    return inst, 3;
}

decode_once :: (offset: s64, head: *u8) -> (Instruction, advance: s64) {
    opcode_equals :: inline (test: u8, mask: u8, opcode: u8) -> bool {
        assert(!(opcode & ~mask));
        return (test & mask) == opcode;
    }

    op_info: Opcode_Info;
    #if USE_TABLE_DISPATCH {
        opcode := (0b1111_1111 & (<<head));
        assert(opcode < opcode_table.ops.count);
        op_info = opcode_table.ops[opcode];
    } else {
        if opcode_equals(<<head, 0b1111_1100, 0b1000_1000) {
            op_info = .{decode_mov, "mov", "move register/memory to/from register"};
        } else if opcode_equals(<<head, 0b1111_0000, 0b1011_0000) {
            op_info = .{decode_mov_imm_to_reg, "mov", "move immediate to register"};
        } else if opcode_equals(<<head, 0b1111_1110, 0b1100_0110) {
            op_info = .{decode_mov_imm_to_reg_mem, "mov", "move immediate to register/memory"};
        } else if opcode_equals(<<head, 0b1111_1100, 0b1010_0000) {
            op_info = .{decode_mov_accumulator, "mov", "move memory to/from accumulator"};
        }
    }

    if !op_info.decode
        assert(false, "Unknown opcode for first byte: 0x%", formatHex(<<head));

    inst, advance_count := op_info.decode(*op_info, head);
    inst.mnemonic = op_info.mnemonic;
    inst.desc = op_info.desc;
    return inst, advance_count;
}

disassemble :: (bytes: []u8, output_asm_path: string="out.asm") {
    builder: String_Builder;

    offset := 0;
    while offset < bytes.count {
        head := bytes.data + offset;
        inst, advance := decode_once(offset, head);

        print_to_builder(*builder, "% %, %\n", inst.mnemonic, operand_to_string(inst, inst.dst), operand_to_string(inst, inst.src));
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

path_join :: #bake_arguments join(separator="/");

assemble :: (asm_path: string) -> bool {
    args: [..]string;
    array_add(*args, "nasm");
    array_add(*args, asm_path);
    result, output_string, error_string := run_command(..args, capture_and_return_output=true);
    if result.type != .EXITED {
        print("Process failed to execute with reason: %", result.type);
        return false;
    } else if (result.exit_code != 0) {
        print("Error in command '%':\n%", join(..args), error_string);
        return false;
    }

    return true;
}

run_test :: (actual_asm_path: string) -> bool {
    temp_dirname := "test_tmp";
    asm_filename := path_filename(actual_asm_path);

    temp_asm_path := path_join(temp_dirname, asm_filename);
    temp_encoded_path := path_strip_extension(temp_asm_path);

    temp_our_asm_path := join(temp_encoded_path, "_ours.asm");
    temp_our_encoded_path := join(temp_encoded_path, "_ours");

    // make temp dir
    make_directory_if_it_does_not_exist(temp_dirname);

    // copy ground truth (GT) asm
    copy_file(actual_asm_path, temp_asm_path);

    // assemble GT asm to machine code
    // TODO(ryan): give assemble() an explicit output path
    if DEBUG  print("Assembling input '%' to '%'\n", temp_asm_path, temp_encoded_path);
    if !assemble(temp_asm_path) {
        print("Error assembling '%'\n", temp_asm_path);
        return false;
    }

    // run our disassembler
    if DEBUG  print("Disassembling '%' to '%':\n", temp_encoded_path, temp_our_asm_path);
    bytes := file_read_all_as_bytes(temp_encoded_path);
    disassemble(bytes, output_asm_path=temp_our_asm_path);

    // assemble our disassembled asm to machine code
    // TODO(ryan): give assemble() an explicit output path
    if DEBUG  print("Assembling input '%' to '%'\n", temp_our_asm_path, temp_our_encoded_path);
    if !assemble(temp_our_asm_path) {
        print("Error assembling '%'\n", temp_our_asm_path);
        return false;
    }

    // binary compare assembled GT vs ours
    encoded_bytes := file_read_all_as_bytes(temp_encoded_path);
    our_encoded_bytes := file_read_all_as_bytes(temp_our_encoded_path);
    defer free(encoded_bytes.data);
    defer free(our_encoded_bytes.data);

    if encoded_bytes.count != our_encoded_bytes.count ||
        memcmp(encoded_bytes.data, our_encoded_bytes.data, encoded_bytes.count) {
        print("Encoded instructions do not match!\n");
        return false;
    }
    return true;
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
            "../cmuratori-computer_enhance/perfaware/part1/listing_0041_add_sub_cmp_jnz",
        ];

        DEBUG = false;
        print("RUNNING TESTS:\n");
        for input_files {
            print("Testing '%'\n", it);
            if !run_test(it) {
                print("  Test FAILED!\n");
            } else {
                print("  Test PASSED!\n");
            }
            print("\n");
        }
    } else {
        bytes := file_read_all_as_bytes(f);
        disassemble(bytes);
    }
}
