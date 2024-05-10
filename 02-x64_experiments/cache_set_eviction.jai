#import "Basic";

#import,dir "../modules/platform";
#import,dir "../modules/profiler";
#import,dir "../modules/memory_utils";

libasm :: #library,no_dll "cache_set_eviction";
read_cacheline_strided :: (src: *void, repeat_count: u64, line_count: u64, stride: u64) -> s64 #foreign libasm;

L1_SIZE :: #run cast(u64)Kilobyte(32);
CACHELINE_SIZE :: 64;

Result :: struct {
    name: string;
    stride_cachelines: u64;
    gigabytes_per_second: float;
};

print_metered_bar :: (value: $T, max_value: T, width: s64, fill_char: u8 = #char "x",
        empty_char: u8 = #char " ")
{
    inner_width := width-2;
    filled := cast(float)value / cast(float)max_value;
    count := cast(s64)(filled * cast(float)inner_width);
    print_character(#char "[");
    for 0..count-1  print_character(fill_char);
    for 0..inner_width-count-1  print_character(empty_char);
    print_character(#char "]");
}
print_results_table :: (results: []Result) {
    max_value := 0.0;
    for results  max_value = max(max_value, it.gigabytes_per_second);

    print("RESULTS:\n");
    print("stride  throughput (gb/s)  meter                           test name\n");
    print("------  -----------------  ------------------------------  -----------------------------------------------\n");
    for results {
        using it;
        print("   %             %  ",
            formatInt(stride_cachelines, minimum_digits=3),
            formatFloat(gigabytes_per_second, width=3, trailing_width=2)
        );

        print_metered_bar(gigabytes_per_second, max_value, 30);
        print("  %\n", name);
    }
}
print_csv :: (results: []Result) {
    print("RESULTS (CSV):\n");
    print("--------------\n");
    print("stride_cachelines,gigabytes_per_second\n");
    for results {
        using it;
        print("%,%\n", stride_cachelines, gigabytes_per_second);
    }
}


main :: () {
    // Our goal is to experimentally determine the following:
    //   * configuration of cache set "index" bits (count, range)
    //   * configuration of cache set "tag" bits (count, range)
    //   * size of a cache set (in an "N-way associative cache", determine "N")
    //   * the cache bandwidth for pathological cases that only use a single cache set

    // Just allocate 1 GB of virtual address space and call it a day.
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
    read_size :: L1_SIZE / 2;
    read_line_count :: read_size / CACHELINE_SIZE;

    repeat_count := buf_size / read_size;
    actual_read_size := repeat_count * read_size;

    results: [..]Result;
    for stride_cachelines: 1..128 {
        stride_bytes := cast(u64) stride_cachelines * CACHELINE_SIZE;
        name := sprint("read % from % cachelines with stride=% cachelines (%)",
            pretty_print_byte_size(read_size), read_line_count, stride_cachelines,
            pretty_print_byte_size(stride_bytes));
        tester := repetition_test_init(name, max_iters=500);
        while repetition_test_is_running(*tester) {
            repetition_test_start(*tester);
            read_cacheline_strided(buf, repeat_count, read_line_count, stride_bytes);
            repetition_test_stop(*tester, actual_read_size);
        }
        reset_temporary_storage();

        best := repetition_test_get_best(*tester);
        entry := Result.{name, cast(u64) stride_cachelines, cast(float) gigabytes_per_second(best)};
        array_add(*results, entry);
    }

    print_results_table(results);
    print("\n");
    print_csv(results);
}

build :: () {
    #import,file "build_utils.jai";
    if !build_asm("cache_set_eviction.asm")  exit(1);
}
#run build();
