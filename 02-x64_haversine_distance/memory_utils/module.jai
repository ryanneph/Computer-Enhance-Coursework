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
