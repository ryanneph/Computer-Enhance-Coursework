#import "Basic";

PAGE_SIZE: u64 : 4096;
PAGE_SIZE_2MB: u64 : #run (2 * 1024 * 1024);
PAGE_SIZE_1GB: u64 : #run (1 * 1024 * 1024 * 1024);

#if OS == .LINUX {
    #import "POSIX";

    MAP_HUGETLB :: 0x4000;
    MAP_HUGE_SHIFT :: 26;
    MAP_HUGE_2MB :: (21 << MAP_HUGE_SHIFT);
    MAP_HUGE_1GB :: (30 << MAP_HUGE_SHIFT);

    alloc_pages :: (page_count: u64) -> *void {
        addr := mmap(null, page_count * PAGE_SIZE, PROT_READ | PROT_WRITE,
            MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        assert(addr != MAP_FAILED);
        return addr;
    }

    alloc_huge_pages_2mb :: (page_count: u64) -> *void {
        addr := mmap(null, page_count * PAGE_SIZE_2MB, PROT_READ | PROT_WRITE,
            MAP_PRIVATE | MAP_ANONYMOUS | MAP_HUGETLB | MAP_HUGE_2MB, -1, 0);
        assert(addr != MAP_FAILED);
        return addr;
    }

    alloc_huge_pages_1gb :: (page_count: u64) -> *void {
        addr := mmap(null, page_count * PAGE_SIZE_1GB, PROT_READ | PROT_WRITE,
            MAP_PRIVATE | MAP_ANONYMOUS | MAP_HUGETLB | MAP_HUGE_1GB, -1, 0);
        assert(addr != MAP_FAILED);
        return addr;
    }

    free_pages :: (addr: *void, page_count: u64) {
        ret := munmap(addr, page_count * PAGE_SIZE);
    }

    lock_memory_range :: (addr: *void, count: u64) {
        mlock(addr, count);
    }

    unlock_memory_range :: (addr: *void, count: u64) {
        munlock(addr, count);
    }

    #scope_file
    mlock :: (addr: *void, len: size_t) -> s32 #foreign libc;
    munlock :: (addr: *void, len: size_t) -> s32 #foreign libc;
    libc :: #system_library "libc";
    #scope_export
} else {
    #assert("platform not supported");
}

#if CPU == .X64 {
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
} else {
    get_max_cpuid_leaves :: () -> (max_basic_leaf: u32, max_extended_leaf: u32) {
        0, 0;
    }
    get_cpuid_leaf :: (basic_leaf: u32, sub_leaf: u32 = 0)
    -> (eax: u32, ebx: u32, ecx: u32, edx: u32) {
        return 0, 0, 0, 0;
    }
    get_cpuid_manufacturer_id_string :: () -> string {
        return "";
    }
    get_cacheline_size :: () -> u64 {
        return 0;
    }
}


Pointer_Decomposition :: struct {
    pml4e_index: u16; // page-map-level-4 (bits 39-47)
    pdpte_index: u16; // page-directory-pointer-table (bits 30-38)
    pde_index:   u16; // page-directory (bits 21-29)
    pte_index:   u16; // page-table (bits 12-20)
    offset:      u32; // offset from page base address (bits 0-11)
}

decompose_pointer_4k_page :: (pointer: *void) -> Pointer_Decomposition {
    raw := cast(u64) pointer;
    decomp: Pointer_Decomposition;
    decomp.pml4e_index = cast(u16) (raw >> 39) & 0x1FF;
    decomp.pdpte_index = cast(u16) (raw >> 30) & 0x1FF;
    decomp.pde_index   = cast(u16) (raw >> 21) & 0x1FF;
    decomp.pte_index   = cast(u16) (raw >> 12) & 0x1FF;
    decomp.offset      = cast(u32)  raw        & 0xFFF;

    return decomp;
}

decompose_pointer_2mb_page :: (pointer: *void) -> Pointer_Decomposition {
    raw := cast(u64) pointer;
    decomp: Pointer_Decomposition;
    decomp.pml4e_index = cast(u16) (raw >> 39) & 0x1FF;
    decomp.pdpte_index = cast(u16) (raw >> 30) & 0x1FF;
    decomp.pde_index   = cast(u16) (raw >> 21) & 0x1FF;
    decomp.offset      = cast(u32)  raw        & 0x1FFFFF;

    return decomp;
}

decompose_pointer_1gb_page :: (pointer: *void) -> Pointer_Decomposition {
    raw := cast(u64) pointer;
    decomp: Pointer_Decomposition;
    decomp.pml4e_index = cast(u16) (raw >> 39) & 0x1FF;
    decomp.pdpte_index = cast(u16) (raw >> 30) & 0x1FF;
    decomp.offset      = cast(u32)  raw        & 0x3FFFFFFF;

    return decomp;
}
