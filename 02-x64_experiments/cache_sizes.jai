#import "Basic";

#import,dir "../modules/profiler";
#import,dir "../modules/memory_utils";

libasm :: #library,no_dll "cache_sizes";
read_wrapping_pow2 :: (dest: *u8, count: u64, offset_mask: u64) #c_call #foreign libasm;


main :: () {
    buf_size := cast(u64) Gigabyte(1);
    buf := alloc_pages(buf_size / PAGE_SIZE);
    // pre-fault all memory_pages and keep resident in physical mem
    lock_memory_range(buf, buf_size);


    for mask_shift: 10..30 {
        touch_size := cast(u64) (1 << mask_shift);
        mask := touch_size - 1;
        print("Running test 2^% (% b, % kb, % mb, % gb)\n", mask_shift,
                touch_size, xx touch_size / Kilobyte(1), xx touch_size / Megabyte(1),
                xx touch_size / Gigabyte(1));
        print("------------------------------------------------------------\n");
        tester := repetition_test_init(max_iters=500);
        while repetition_test_is_running(*tester) {
            repetition_test_start(*tester);
            read_wrapping_pow2(buf, buf_size, mask);
            repetition_test_stop(*tester, buf_size);
        }
        print("------------------------------------------------------------\n\n");
    }
}

build :: () {
    #import,file "build_utils.jai";
    if !build_asm("cache_sizes.asm")  exit(1);
}
#run build();
