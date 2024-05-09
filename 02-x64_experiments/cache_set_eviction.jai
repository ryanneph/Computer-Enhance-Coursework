#import "Basic";

#import,dir "../modules/platform";
#import,dir "../modules/profiler";
#import,dir "../modules/memory_utils";

libasm :: #library,no_dll "cache_set_eviction";
read_32x8 :: (src: *void, size: u64, read_line_count: u64, increment: u64) -> s64 #foreign libasm;

L1_SIZE :: #run cast(u64)Kilobyte(32);
CACHELINE_SIZE :: 64;

main :: () {
    // Our goal is to experimentally determine the following:
    //   * configuration of cache set "index" bits (count, range)
    //   * configuration of cache set "tag" bits (count, range)
    //   * size of a cache set (in an "N-way associative cache", determine "N")
    //   * the cache bandwidth for pathological cases that only use a single cache set

    // Requirements:
    // 1. only read from memory whose total size should fit within a cache

    // Assumptions:
    // 1. "index" bits are contiguous within a virtual memory address
    // 2. "index" bits and "tag" bits do not share any bits of the address
    // 3. a cache contains a number of cache-sets that is exactly some power of two
    //    e.g. a cache that uses 6-bits, has (2^6 = 64) cache-sets.

    // Virtual Address Description
    // [ 64..49 | 48........K+1 | K............6 | 5..............0 ]
    //   unused   cacheline tag   cacheset index   cacheline offset

    // Just allocate 1 GB of virtual address space and call it a day.
    // That affords 16384 unique cacheline tags for a 10-bit cache-set index
    // and 6-bit cacheline offset (see address bit-level layout above).
    read_base_addr := cast(*void) 0x0000_7000_0000_0000; @Arbitrary
    page_count := (cast(u64)Gigabyte(1) + PAGE_SIZE-1) / PAGE_SIZE;
    buf := alloc_pages(page_count, at_addr=read_base_addr);
    buf_size := page_count * PAGE_SIZE;
    if (buf != read_base_addr) {
        print("Failed to allocate at fixed addr=%\n", read_base_addr);
        exit(1);
    }
    lock_memory_range(buf, buf_size);
    print("buf=%, buf_size=%, page_count=%\n", buf, pretty_print_byte_size(buf_size), page_count);

    // read a region that we know fits in L1 cache (on i7-13700K, L1$ is 32K)
    read_size := L1_SIZE / 2;
    read_line_count := read_size / CACHELINE_SIZE;

    for index_bits: 1..10 {
        offset_bits :: 6;
        tag_bits := 58 - index_bits;
        tag_shift := index_bits + offset_bits;

        // just use index=0 and vary the tag bits until the performance gets really bad
        addr_increment := cast(u64)1 << tag_shift;
        print("reading % from % cachelines with spacing=% (% addr space)\n",
            pretty_print_byte_size(read_size), read_line_count, addr_increment,
            pretty_print_byte_size(xx addr_increment * read_line_count));

        name := sprint("find index bits (start=%, size=%)", 6, index_bits);
        tester := repetition_test_init(name);
        while repetition_test_is_running(*tester) {
            repetition_test_start(*tester);
            read_32x8(buf, buf_size, read_line_count, addr_increment);
            repetition_test_stop(*tester, buf_size);
        }
    }
}

build :: () {
    #import,file "build_utils.jai";
    if !build_asm("cache_set_eviction.asm")  exit(1);
}
#run build();
