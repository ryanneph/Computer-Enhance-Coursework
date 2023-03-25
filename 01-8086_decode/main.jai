#import "Basic";
#import "String";

#load "file.jai";

DEBUG :: true;

Memory_Mode :: enum {
    MEM_NO_DISP :: 0b00;
    MEM_DISP_8  :: 0b01;
    MEM_DISP_16 :: 0b10;
    REGISTER    :: 0b11;
}

Instruction_Type :: enum {
    INVALID :: 0;
    MOV     :: 1;
}

Register :: string;
Memory :: u64;
Operand :: union {
    reg: Register;
    mem: Memory;
    imm: u16;
}

Instruction :: struct {
    type:     Instruction_Type;

    // TODO(ryan): maybe store *Opcode_Info for indirection instead?
    mnemonic: string; // asm identifier
    desc:     string; // XXX DEBUG only

    mode:     Memory_Mode;
    src:      Operand;
    dst:      Operand;
}

Decode_Proc :: #type (opcode: u8, op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32);
Opcode_Info :: struct {
    decode:   Decode_Proc;
    mnemonic: string;
    desc:     string;
}
opcode_table: [1]Opcode_Info = .[
    .{ decode_mov, "mov", "move register/memory to/from register" },
];

memory_mode :: inline (mod: u8) -> Memory_Mode {
    assert(!(mod & ~0x03));
    return cast(Memory_Mode)mod;
}

register :: inline (name: string) -> Operand {
    return Operand.{reg = name};
}

// NOTE(ryan): directly indexed by "(reg << 1) | field_w".
register_names :: string.[
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
register :: (reg: u8, word: u8) -> Operand {
    assert(word <= 1);
    index := (reg << 1) | word;
    assert(index < register_names.count);

    name := register_names[index];
    return register(name);
}

decode_mov :: (opcode: u8, op_info: *Opcode_Info, head: *u8) -> (Instruction, advance_count: s32) {
    assert(opcode == 0b100010, "unsupported move opcode");

    field_d   := (<< head      & 0b0000_0010) >> 1; // 1 if "reg" is destination
    field_w   := (<< head      & 0b0000_0001);      // 0: byte, 1: word
    field_mod := (<<(head + 1) & 0b1100_0000) >> 6; // see Memory_Mode
    field_reg := (<<(head + 1) & 0b0011_1000) >> 3;
    field_rm  := (<<(head + 1) & 0b0000_0111);

    reg     := register(field_reg, field_w);
    reg_mem := register(field_rm, field_w);

    inst: Instruction;
    inst.type     = .MOV;
    inst.mnemonic = op_info.mnemonic;
    inst.desc     = op_info.desc;
    inst.mode     = memory_mode(field_mod);
    inst.src      = ifx field_d then reg_mem else reg;
    inst.dst      = ifx field_d then reg     else reg_mem;

    if DEBUG {
        print("% %, %  :: {d=% w=% mod=% reg=% rm=%}",
            op_info.mnemonic, inst.dst.reg, inst.src.reg,
            field_d, field_w, field_mod, field_reg, field_rm);
        if op_info.desc.count
            print("  (%)", op_info.desc);
        print("\n");
    }

    return inst, 2;
}

decode :: (offset: s64, head: *u8) -> (Instruction, advance: s64) {
    opcode := (0b1111_1100 & (<<head)) >> 2;

    // HACK(ryan): replace with direct indexing by opcode.
    op_info := *opcode_table[opcode - 0b100010];

    inst, advance_count := op_info.decode(opcode, op_info, head);
    return inst, advance_count;
}

disassemble :: (bytes: []u8) {
    builder: String_Builder;

    offset := 0;
    while offset < bytes.count {
        head := bytes.data + offset;
        inst, advance := decode(offset, head);

        print_to_builder(*builder, "% %, %\n", inst.mnemonic, inst.dst.reg, inst.src.reg);
        offset += advance;
    }

    file, success := file_open("out.asm", for_writing=true, keep_existing_content=false);
    if !success
        assert(false);

    file_write(*file, "; auto-generated 8086 disassembly\n");
    file_write(*file, "bits 16\n\n");
    file_write(*file, *builder);
    file_close(*file);
}

main :: () {
    // f := "../cmuratori-computer_enhance/perfaware/part1/listing_0037_single_register_mov";
    f := "../cmuratori-computer_enhance/perfaware/part1/listing_0038_many_register_mov";
    bytes := file_read_all_as_bytes(f);
    disassemble(bytes);
}
