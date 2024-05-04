#import "Basic";

#import,dir "../modules/profiler";
#import,dir "../modules/memory_utils";

libasm :: #library,no_dll "unaligned_loads";
read_32x4 :: (src: *u8, count: u64, offset_mask: u64) #c_call #foreign libasm;


Result :: struct {
    name: string;
    region_size: u64;
    offset: u64;
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
    print("offset  throughput (gb/s)  meter                           test name\n");
    print("------  -----------------  ------------------------------  -----------------------------------------------\n");
    for results {
        using it;
        print("    %             %  ",
            formatInt(offset, minimum_digits=2),
            formatFloat(gigabytes_per_second, trailing_width=2)
        );

        print_metered_bar(gigabytes_per_second, max_value, 30);
        print("  %\n", name);
    }
}
print_csv :: (results: []Result) {
    print("RESULTS (CSV):\n");
    print("--------------\n");
    print("region_size,alignment,gigabytes_per_second\n");
    for results {
        using it;
        print("%,%,%\n", region_size, offset, gigabytes_per_second);
    }
}

is_power_of_two :: (a: u64) -> bool { return !(a & (a-1)); }
main :: () {
    buf_size := cast(u64) Gigabyte(1);
    buf := alloc_pages(buf_size / PAGE_SIZE);
    // pre-fault all memory_pages and keep resident in physical mem
    lock_memory_range(buf, buf_size);

    region_sizes := s64.[ Kilobyte(32), Kilobyte(256), Megabyte(8), Gigabyte(1), ];

    results: [..]Result;
    for region_sizes {
        region_size := cast(u64)it;
        assert(is_power_of_two(region_size));
        offset_mask := region_size - 1;
        for 0..64 {
            addr_offset := cast(u64)it;
            actual_read_size := buf_size - addr_offset;

            name := sprint("unaligned_loads (region=%, offset=%)", region_size, addr_offset);
            tester := repetition_test_init(name, improve_threshold=250, max_iters=1000);
            while repetition_test_is_running(*tester) {
                repetition_test_start(*tester);
                read_32x4(buf + addr_offset, actual_read_size, offset_mask);
                repetition_test_stop(*tester, actual_read_size);
            }
            reset_temporary_storage();

            best := repetition_test_get_best(*tester);
            entry := Result.{name, region_size, addr_offset, cast(float)gigabytes_per_second(best)};
            array_add(*results, entry);
        }
    }

    print_results_table(results);
    print("\n");
    print_csv(results);
}

build :: () {
    #import,file "build_utils.jai";
    if !build_asm("unaligned_loads.asm")  exit(1);
}
#run build();
