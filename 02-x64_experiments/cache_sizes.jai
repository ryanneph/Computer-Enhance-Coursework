#import "Basic";

#import,dir "../modules/profiler";
#import,dir "../modules/memory_utils";

libasm :: #library,no_dll "cache_sizes";
read_wrapping_pow2_32x8 :: (dest: *u8, count: u64, offset_mask: u64) #c_call #foreign libasm;


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

main :: () {
    buf_size := cast(u64) Gigabyte(1);
    buf := alloc_pages(buf_size / PAGE_SIZE);
    // pre-fault all memory_pages and keep resident in physical mem
    lock_memory_range(buf, buf_size);

    results: [..]Result;
    for mask_shift: 10..30 {
        touch_size := cast(u64) (1 << mask_shift);
        mask := touch_size - 1;

        print("Running test 2^% (% b, % kb, % mb, % gb)\n", mask_shift,
                touch_size, xx touch_size / Kilobyte(1), xx touch_size / Megabyte(1),
                xx touch_size / Gigabyte(1));
        print("------------------------------------------------------------\n");
        tester := repetition_test_init(max_iters=1000);
        while repetition_test_is_running(*tester) {
            repetition_test_start(*tester);
            read_wrapping_pow2_32x8(buf, buf_size, mask);
            repetition_test_stop(*tester, buf_size);
        }
        print("------------------------------------------------------------\n\n");

        best := repetition_test_get_best(*tester);
        res := Result.{ touch_size, best };
        array_add(*results, res);
    }

    print_results_table(results,, allocator=temp);
}

build :: () {
    #import,file "build_utils.jai";
    if !build_asm("cache_sizes.asm")  exit(1);
}
#run build();
