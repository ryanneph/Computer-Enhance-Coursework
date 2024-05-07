#import "Basic";
#import "System";

Kilobyte :: (count: $T) -> T #expand { return count * 1024; }
Megabyte :: (count: $T) -> T #expand { return count * 1048576; }
Gigabyte :: (count: $T) -> T #expand { return count * 1073741824; }

PAGE_SIZE: u64 : 4096;
PAGE_SIZE_2MB: u64 : #run (2 * 1024 * 1024);
PAGE_SIZE_1GB: u64 : #run (1 * 1024 * 1024 * 1024);

#if OS == .LINUX {
    #scope_file
    #import "POSIX";

    mlock :: (addr: *void, len: size_t) -> s32 #foreign libc;
    munlock :: (addr: *void, len: size_t) -> s32 #foreign libc;
    sbrk :: (incr: s64) -> *void #foreign libc;
    libc :: #system_library "libc";

    print_syscall_error :: (what: string) {
        err, errstr := get_error_value_and_string();
        print("error: % failed with err=%: %\n", what, err, errstr);
    }

    #scope_export
    MAP_HUGETLB :: 0x4000;
    MAP_HUGE_SHIFT :: 26;
    MAP_HUGE_2MB :: (21 << MAP_HUGE_SHIFT);
    MAP_HUGE_1GB :: (30 << MAP_HUGE_SHIFT);

    alloc_pages :: (page_count: u64, at_addr: *void = null) -> *void {
        prot: s32 = PROT_READ | PROT_WRITE;
        flags: s32 = MAP_PRIVATE | MAP_ANONYMOUS;
        if at_addr {
            if cast(u64)at_addr & (PAGE_SIZE-1) != 0 {
                print("error: at_addr must be PAGE_SIZE-aligned (% bytes)\n", PAGE_SIZE);
                exit(1);
            }
            flags |= MAP_FIXED;
        }

        addr := mmap(at_addr, page_count * PAGE_SIZE, prot, flags, -1, 0);
        if addr == MAP_FAILED {
            print_syscall_error("mmap");
            exit(1);
        }
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

    // move the "program break" up by `count` bytes
    //
    // On linux, the heap begins ~right after the program's .text, .data, and .bss segments and grows "up"
    // (toward higher addresses). The end of the heap is denoted by the "program break", which can be
    // affected directly by use of the brk(addr) and sbrk(increment) syscalls.
    // Note, however that the behavior of those syscall is unspecified if the program also uses
    // other memory functions (e.g. malloc/free, mmap).
    advance_heap_pointer :: (count: s64) -> prior_addr: *void {
        FAILURE :: cast(*void) -1;
        prior_addr := sbrk(count);
        if prior_addr == FAILURE {
            print_syscall_error("sbrk");
            return null;
        }
        return prior_addr;
    }

    // mlock tends to pre-fault all pages in a virtual address range, becuase it initially ensures that
    // the entire range is mapped to physical memory pages and guarantees that none of the range will
    // ever get evicted or paged to disk. Thus it is often incorrectly believed to it is guaranteed to
    // both pre-fault all pages mapped to the range and prevent later soft faults.
    //
    // The truth is that mlock'd pages are guaranteed NOT to "major fault" (triggering an IO mapping),
    // but are not guarateed NOT to "minor fault" (the normal system memory type of fault).
    // Even mlock'd pages may be "migrated" as a way for the kernel to "de-fragment" the memory space to
    // make room for contiguous physical pages in support of large or huge pages.
    // They may also be "migrated" as a part of the scheduler performing NUMA balancing.
    //
    // mlock both pre-faults and locks pages in memory (aside from the small gotchas above), but it also
    // disables the system's ability to effectively handle full-system OOM situations. Thus the amount of
    // "lockable" memory may be limited (i.e. `ulimit -l` or `getrlimit(RLIMIT_MEMLOCK)`). So it is not
    // always possible, or at the very least requires checking the limit and iteratively performing `mlock`
    // in smaller chunks.
    //
    // If all you want is prefaulting, just so a wide simd write-loop and move on...
    lock_memory_range :: (addr: *void, count: u64) {
        mlock(addr, count);
    }

    unlock_memory_range :: (addr: *void, count: u64) {
        munlock(addr, count);
    }
} else {
    #assert("platform not supported");
}

#scope_export
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

pretty_print_byte_size :: (size: u64) -> string {
    suffix :: string.["b", "kb", "mb", "gb", "tb"];

    current := cast(float64)size;
    next := cast(float64)size;
    i := 0;
    while i < suffix.count && next >= 1.0 {
        current = next;
        next = current / 1024.0;
        i += 1;
    }

    // allocate using context.allocator
    FMT :: #bake_arguments formatFloat(trailing_width=3, zero_removal=.NO);
    s := sprint("% %", FMT(current), suffix[i-1]);
    return s;
}

is_power_of_two :: (a: u64) -> bool { return !(a & (a-1)); }
