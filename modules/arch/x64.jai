#assert(CPU == .X64);

#import "Basic";

get_max_cpuid_leaves :: () -> (max_basic_leaf: u32, max_extended_leaf: u32) {
    max_basic_leaf: u32 = ---;
    max_extended_leaf: u32 = ---;

    #asm {
        eax: gpr === a;
        ebx: gpr === b;
        ecx: gpr === c;
        edx: gpr === d;

        // get basic info (# basic leaves and the vendor string)
        xor.d eax, eax;
        cpuid eax, ebx, ecx, edx;
        mov.d max_basic_leaf, eax;

        // get extended info (# extended leaves)
        mov.d eax, 0x80000000;
        cpuid eax, ebx, ecx, edx;
        mov.d max_extended_leaf, eax;
    }

    return max_basic_leaf, max_extended_leaf;
}

get_cpuid_leaf :: (basic_leaf: u32, sub_leaf: u32 = 0)
    -> (eax: u32, ebx: u32, ecx: u32, edx: u32)
{
    eax: u32 = basic_leaf;
    ebx: u32 = ---;
    ecx: u32 = sub_leaf;
    edx: u32 = ---;

    #asm {
        eax === a;
        ebx === b;
        ecx === c;
        edx === d;

        cpuid eax, ebx, ecx, edx;
    }

    return eax, ebx, ecx, edx;
}

cpu_manufacturer_id_data: [12]u8;
get_cpuid_manufacturer_id_string :: () -> string {
    // EAX=0: Highest Function Parameter and Manufacturer ID
    eax, ebx, ecx, edx := get_cpuid_leaf(0x0);
    (cast(*u32) *(cpu_manufacturer_id_data[0])).* = ebx;
    (cast(*u32) *(cpu_manufacturer_id_data[4])).* = edx;
    (cast(*u32) *(cpu_manufacturer_id_data[8])).* = ecx;

    return cast(string) cpu_manufacturer_id_data;
}

get_cpuid_processor_info :: () -> (family: u32, model: u32, stepping: u32) {
    eax, _, _, _ := get_cpuid_leaf(0x1);

    family_id   := (eax >> 8) & 0xf;
    model       := (eax >> 4) & 0xf;
    stepping_id := (eax     ) & 0xf;

    if family_id == 0x6 || family_id == 0xf {
        model = ((eax >> 12) & 0xf0) | model;
    }

    if (family_id == 0xf) {
        family_id = ((eax >> 16) & 0xff0) | family_id;
    }

    return family_id, model, stepping_id;
}

get_cacheline_size :: () -> u64 {
    max_basic_leaf := get_max_cpuid_leaves();
    if 0x1 > max_basic_leaf {
        print("error: cpuid with leaf 0x1 not supported (max_basic_leaf=%)\n", max_basic_leaf);
        return 0;
    }

    // EAX=1: Processor Info and Feature Bits
    eax, ebx, ecx, edx := get_cpuid_leaf(0x1);
    has_clflush := cast(bool) ecx & (1 << 19);
    cacheline_size: u64 = ifx has_clflush
        then cast(u64) ((ebx >> 5) & 0x7f8)
        else cast(u64) 0;

    return cacheline_size;
}

// This should be a bitmask for efficient storage (e.g. better
// cacheability), but is left as bools for "readability".
AVX512_Features :: struct {
    foundation:   bool;
    dq:           bool;
    ifma:         bool;
    pf:           bool;
    er:           bool;
    cd:           bool;
    bw:           bool;
    vl:           bool;
    vbmi:         bool;
    vbmi2:        bool;
    vnni:         bool;
    bitalg:       bool;
    vpopcntdq:    bool;
    _4vnniw:      bool;
    _4fmaps:      bool;
    vp2intersect: bool;
    fp16:         bool;
};

get_avx512_features :: () -> AVX512_Features {
    feats: AVX512_Features;

    eax, ebx, ecx, edx := get_cpuid_leaf(0x7);
    feats.foundation   = !!(ebx & (1 << 16));
    feats.dq           = !!(ebx & (1 << 17));
    feats.ifma         = !!(ebx & (1 << 21));
    feats.pf           = !!(ebx & (1 << 26));
    feats.er           = !!(ebx & (1 << 27));
    feats.cd           = !!(ebx & (1 << 28));
    feats.bw           = !!(ebx & (1 << 30));
    feats.vl           = !!(ebx & (1 << 31));
    feats.vbmi         = !!(ecx & (1 <<  1));
    feats.vbmi2        = !!(ecx & (1 <<  6));
    feats.vnni         = !!(ecx & (1 << 11));
    feats.bitalg       = !!(ecx & (1 << 12));
    feats.vpopcntdq    = !!(ecx & (1 << 14));
    feats._4vnniw      = !!(edx & (1 <<  2));
    feats._4fmaps      = !!(edx & (1 <<  3));
    feats.vp2intersect = !!(edx & (1 <<  8));
    feats.fp16         = !!(edx & (1 << 23));

    return feats;
}
