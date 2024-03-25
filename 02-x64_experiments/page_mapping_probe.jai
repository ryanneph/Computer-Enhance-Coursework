#import "Basic";
#import,dir "../modules/profiler";
#import,dir "../modules/memory_utils";

PAGE_ALLOC_COUNT :: 4096;

main :: () {
    print("alloc_count,touch_count,fault_count,extra_fault_count\n");
    for touch_count: 0..PAGE_ALLOC_COUNT-1 {
        data := cast(*u8) alloc_pages(PAGE_ALLOC_COUNT);

        fault_count_start := page_fault_counter();

        touch_size := cast(u64) touch_count * PAGE_SIZE;
        for j: 0..cast(s64)(touch_size-1) {
            #if true { // forward
                data[j] = cast,no_check(u8) j;
            } else { // reverse
                data[cast(s64)(touch_size - 1) - j] = cast,no_check(u8) j;
            }
        }

        fault_count := page_fault_counter() - fault_count_start;
        print("%,%,%,%\n", PAGE_ALLOC_COUNT, touch_count, fault_count, cast(s64)fault_count - touch_count);

        free_pages(data, PAGE_ALLOC_COUNT);
    }
}
