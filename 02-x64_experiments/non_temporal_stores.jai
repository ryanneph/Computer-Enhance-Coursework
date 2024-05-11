#import "Basic";

#import,dir "../modules/platform";
#import,dir "../modules/profiler";
#import,dir "../modules/memory_utils";

libasm :: #library,no_dll "non_temporal_stores";
mov_32x2    :: (dst: *void, dst_size: u64, src: *void, src_size: u64) #foreign libasm;
mov_32x2_nt :: (dst: *void, dst_size: u64, src: *void, src_size: u64) #foreign libasm;
test_proc_type :: #type (*void, u64, *void, u64) #c_call;

alloc_buffer :: (size_in_bytes: u64) -> *void {
    assert(size_in_bytes % PAGE_SIZE == 0);

    page_count := size_in_bytes / PAGE_SIZE;
    buf := alloc_pages(page_count);
    if !buf {
        print("Failed to allocate %\n", pretty_print_byte_size(size_in_bytes));
        exit(1);
    }
    lock_memory_range(buf, size_in_bytes);

    return buf;
}

main :: () {
    // Read from small cached buffer and store to a large uncached buffer
    // using wide move with non-temporal hint (vmovntdq).

    write_size := cast(u64) Gigabyte(1);
    write_buf  := alloc_buffer(write_size);

    read_size := cast(u64) Kilobyte(16);
    read_buf  := alloc_buffer(read_size);

    run_test :: (test_name: string, test_proc: test_proc_type) #expand {
        name := sprint("% (read % / write %)", test_name,
                pretty_print_byte_size(read_size), pretty_print_byte_size(write_size));
        tester := repetition_test_init(name);
        while repetition_test_is_running(*tester) {
            repetition_test_start(*tester);
            test_proc(write_buf, write_size, read_buf, read_size);
            repetition_test_stop(*tester, write_size);
        }
    }

    run_test("cached reads/writes", mov_32x2);
    run_test("cached reads / non-temporal writes", mov_32x2_nt);
}

build :: () {
    #import,file "build_utils.jai";
    if !build_asm("non_temporal_stores.asm")  exit(1);
}
#run build();
