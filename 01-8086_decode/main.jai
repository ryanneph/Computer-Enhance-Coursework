#import "Basic";

#load "file.jai";

DEBUG :: false;

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
    mnemonic: string; // asm identifier
    desc:     string; // XXX DEBUG only

    mode:     Memory_Mode;
    src:      Operand;
    dst:      Operand;
}

memory_mode :: inline (mod: u8) -> Memory_Mode {
    assert(!(mod & ~0x03));
    return cast(Memory_Mode)mod;
}

register :: inline (name: string) -> Operand {
    return Operand.{reg = name};
}

register_names :: string.[
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

decode :: (offset: s64, head: *u8) -> (Instruction, advance: s64) {
    opcode := (0b1111_1100 & (<<head)) >> 2;
    op_mnemonic: string;
    op_desc: string;
    if opcode == {
        case 0b100010;
            op_mnemonic = "mov";
            op_desc = "move register/memory to/from register";
        case;
            op_mnemonic = "unk";
            op_desc = "???";
    }

    d   := (<< head      & 0b0000_0010) >> 1; // 1 if "reg" is destination
    w   := (<< head      & 0b0000_0001);      // 0: byte, 1: word
    mod := (<<(head + 1) & 0b1100_0000) >> 6; // see Memory_Mode
    reg := (<<(head + 1) & 0b0011_1000) >> 3;
    rm  := (<<(head + 1) & 0b0000_0111);

    inst: Instruction;
    inst.type     = .MOV;
    inst.mnemonic = op_mnemonic;
    inst.desc     = op_desc;
    inst.mode     = memory_mode(mod);
    inst.src      = register(reg,  w);
    inst.dst      = register(rm, w);

    if DEBUG {
        print("%: % :: op=% d=% w=% mod=% reg=% rm=% :: % %, %",
        formatInt(offset, minimum_digits=2, padding=#char " "),
        <<head, opcode, d, w, mod, reg, rm, inst.mnemonic, inst.dst.reg, inst.src.reg);
        if op_desc.count
            print("  (%)", inst.desc);
        print("\n");
    }

    return inst, 2;
}

disassemble :: (bytes: []u8) {
    print("; auto-generated 8086 disassembly\n");
    print("bits 16\n\n");

    offset := 0;
    while offset < bytes.count {
        head := bytes.data + offset;
        inst, advance := decode(offset, head);

        assert(inst.type == .MOV);
        print("% %, %\n", inst.mnemonic, inst.dst.reg, inst.src.reg);

        offset += advance;
    }
}

main :: () {
    // f := "../cmuratori-computer_enhance/perfaware/part1/listing_0037_single_register_mov";
    f := "../cmuratori-computer_enhance/perfaware/part1/listing_0038_many_register_mov";
    bytes := file_read_all_as_bytes(f);
    disassemble(bytes);
}
