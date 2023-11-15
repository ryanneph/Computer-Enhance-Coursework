#import "Basic";
#import,dir "./memory_utils";

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
} else {
    #assert("platform not supported");
}


print_pointer_decomposition :: (decomp: Pointer_Decomposition, prefix: string = "") {
    FMT3 :: #bake_arguments formatInt(minimum_digits=3, padding=#char " ");
    FMT10 :: #bake_arguments formatInt(minimum_digits=10, padding=#char " ");
    print("%|%|%|%|%|%|\n", prefix,
        FMT3(decomp.pml4e_index),
        FMT3(decomp.pdpte_index),
        FMT3(decomp.pde_index),
        FMT3(decomp.pte_index),
        FMT10(decomp.offset));

}

print_bits :: (value: u64, start_bit: u32, count: u32) {
    assert(count > 0);
    for i: 0..count-1 {
        bit := cast(u8) (value >> (count - 1 - i + start_bit)) & 0x1;
        print_character(#char "0" + bit);
    }
}

print_pointer_details :: (addr: *void) {
    raw := cast(u64) addr;

    print("pointer: %\n", addr);

    print("|");
    print_bits(raw, 48, 16);
    print("|");
    print_bits(raw, 39, 9);
    print("|");
    print_bits(raw, 30, 9);
    print("|");
    print_bits(raw, 21, 9);
    print("|");
    print_bits(raw, 12, 9);
    print("|");
    print_bits(raw, 0, 12);
    print("|");
    print("\n");

    print_pointer_decomposition(decompose_pointer_4k_page(addr),  prefix=" 4k paging: ");
    print_pointer_decomposition(decompose_pointer_2mb_page(addr), prefix="2mb paging: ");
    print_pointer_decomposition(decompose_pointer_1gb_page(addr), prefix="1gb paging: ");

    print("\n");
}

main :: () {
    print("4K pages\n");
    for i: 1..4 {
        addr := alloc_pages(2);
        print_pointer_details(addr);
    }

    print("2MB Pages\n");
    for i: 1..4 {
        addr := alloc_huge_pages_2mb(2);
        print_pointer_details(addr);
    }

    print("1GB Pages\n");
    for i: 1..4 {
        addr := alloc_huge_pages_1gb(2);
        print_pointer_details(addr);
    }
}
