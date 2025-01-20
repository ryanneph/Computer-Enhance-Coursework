#import "Basic";
#import "Sort";

#import,dir "../modules/profiler";
#import,dir "../modules/memory_utils";

libasm :: #library,no_dll "cache_sizes";
read_wrapping_pow2_32x12 :: (src: *u8, count: u64, offset_mask: u64) -> u64 #c_call #foreign libasm;
read_wrapping_nonpow2_32x16 :: (src: *u8, repeat_count: u64, chunk_count: u64) -> u64 #c_call #foreign libasm;


Result :: struct {
    touch_size: u64;
    best: Repetition_Test_Record;
};

print_results_table :: (results: []Result) {
    cpu_freq := get_cpu_timer_freq();

    print("BEST RESULTS:\n");
    print("Touch Size        Bandwidth (gb/s)\n");
    print("----------------  ----------------\n");
    for results {
        using it.best;

        seconds := cast(float64) cpu_timer / cpu_freq;
        bandwidth: float64 = ifx cpu_timer
            then cast(float64) byte_count / (Gigabyte(1.0) * seconds)
            else 0.0;

        // right align "size" column
        fixed_width := 16;
        pretty_size := pretty_print_byte_size(it.touch_size);
        for 0..fixed_width-pretty_size.count-1 {
            print_character(#char " ");
        }
        print("%  %\n", pretty_print_byte_size(it.touch_size), bandwidth);
    }
}

run_power_of_two_test :: (buf: *u8, buf_size: u64, results: *[..]Result) {
    for mask_shift: 10..30 {
        touch_size := cast(u64) (1 << mask_shift);
        mask := touch_size - 1;

        name := sprint("2^% (region_size=%, total_size=%)", mask_shift,
            pretty_print_byte_size(touch_size), pretty_print_byte_size(buf_size));
        tester := repetition_test_init(name);
        while repetition_test_is_running(*tester) {
            repetition_test_start(*tester);
            read_wrapping_pow2_32x12(buf, buf_size, mask);
            repetition_test_stop(*tester, buf_size);
        }

        best := repetition_test_get_best(*tester);
        res := Result.{ touch_size, best };
        array_add(results, res);
        reset_temporary_storage();
    }
}

run_non_power_of_two_test :: (buf: *u8, buf_size: u64, results: *[..]Result) {
    sizes: [..]u64;
    // statically target cache sizes for Intel 13th gen Core processors
    // TODO(ryan): dynamic selection by bisection or other threshold detection
    for Kilobyte(45)..Kilobyte(55) { // L1$
        array_add(*sizes, cast(u64) it);
        it += cast(s64)Kilobyte(1) - 1;
    }
    for Megabyte(1)..cast(s64)Megabyte(4) { // L2$
        array_add(*sizes, cast(u64) it);
        it += cast(s64)Megabyte(0.25) - 1;
    }
    for Megabyte(16)..Megabyte(64) { // L3$
        array_add(*sizes, cast(u64) it);
        it += Megabyte(1) - 1;
    }

    for sizes {
        approx_region_size := it;

        CHUNK_SIZE :: 512;
        assert(approx_region_size >= CHUNK_SIZE);

        chunk_count := approx_region_size / CHUNK_SIZE;
        actual_region_size := chunk_count * CHUNK_SIZE;
        actual_read_size := buf_size / actual_region_size * actual_region_size;
        repeat_count := actual_read_size / actual_region_size;

        name := sprint("non-power-of-two (region_size=%, total_size=%)",
            pretty_print_byte_size(actual_region_size),
            pretty_print_byte_size(actual_read_size));
        tester := repetition_test_init(name, improve_threshold=500, max_iters=5000);
        while repetition_test_is_running(*tester) {
            repetition_test_start(*tester);
            read_wrapping_nonpow2_32x16(buf, repeat_count, chunk_count);
            repetition_test_stop(*tester, actual_read_size);
        }

        best := repetition_test_get_best(*tester);
        res := Result.{ actual_region_size, best };
        array_add(results, res);
        reset_temporary_storage();
    }
}

main :: () {
    buf_size := cast(u64) Gigabyte(1);
    buf := alloc_pages(buf_size / PAGE_SIZE);
    // pre-fault all memory_pages and keep resident in physical mem
    lock_memory_range(buf, buf_size);

    results: [..]Result;
    run_power_of_two_test(buf, buf_size, *results);
    run_non_power_of_two_test(buf, buf_size, *results);

    quick_sort(results, x => x.touch_size);
    print_results_table(results,, allocator=temp);
}

build :: () {
    #import,file "build_utils.jai";
    if !build_asm("cache_sizes.asm")  exit(1);
}
#run build();
