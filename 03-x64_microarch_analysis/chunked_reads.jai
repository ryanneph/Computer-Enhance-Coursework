#import "Basic";
#import "File";

#import,dir "../modules/arch";
#import,dir "../modules/memory_utils";
#import,dir "../modules/profiler";

Test_Proc_Type :: #type (dest_size: u64, source_filename: string, source: *u8, source_size: u64) -> u64;

Test :: struct {
    name: string;
    proc: Test_Proc_Type;
}

calc_page_count :: inline (size: u64, page_size: u64 = PAGE_SIZE) -> (u64, u64) {
    page_count := (size + page_size-1) / page_size;
    actual_size := page_count * page_size;
    return page_count, actual_size;
}

touch_all_pages :: (data: *u8, page_count: u64, page_size: u64) {
    addr := data;
    for 1..page_count {
        addr.* = 0x0; // ensure OS actually provisions unique pages
        addr += page_size;
    }
}

write_all_cachelines :: (data: *u8, count: u64) {
    cacheline_size := get_cacheline_size();
    cacheline_mask := ~(cacheline_size-1);
    assert(cacheline_size && is_power_of_two(cacheline_size));

    addr := data & cacheline_mask;
    last := (addr + count - 1) & cacheline_mask;
    while addr <= last {
        addr.* = cast(u8) addr;
        addr += cacheline_size;
    }
}

allocate_and_touch :: (dest_size: u64, source_filename: string, source: *u8, source_size: u64) -> u64 {
    page_size :: PAGE_SIZE;
    page_count := calc_page_count(dest_size, page_size);
    dest := cast(*u8) alloc_pages(page_count);

    touch_all_pages(dest, page_count, page_size);
    free_pages(dest, page_count);
    return page_count * page_size;
}

allocate_and_copy :: (dest_size: u64, source_filename: string, source: *u8, source_size: u64) -> u64 {
    page_size :: PAGE_SIZE;
    page_count := calc_page_count(dest_size, page_size);
    dest := cast(*u8) alloc_pages(page_count);

    remaining := source_size;
    from := source;
    while remaining > 0 {
        copy_size := min(remaining, dest_size);
        memcpy(dest, from, cast(s64) copy_size);
        from += copy_size;
        remaining -= copy_size;
    }

    free_pages(dest, page_count);
    return source_size;
}

// read from a file in chunks with size equal to dest_size
allocate_and_read_os :: (dest_size: u64, source_filename: string, source: *u8, source_size: u64) -> u64 {
    file, ok := file_open(source_filename, for_writing=false);
    if !ok {
        print("error opening file '%' for reading\n", source_filename);
        exit(1);
    }

    page_size :: PAGE_SIZE;
    page_count := calc_page_count(dest_size, page_size);
    dest := cast(*u8) alloc_pages(page_count);

    remaining := source_size;
    while remaining > 0 {
        read_size := min(remaining, dest_size);
        ok, actually_read := file_read(file, dest, cast(s64) read_size);
        if !ok || actually_read != xx read_size {
            print("error reading % bytes from file\n", read_size);
            exit(1);
        }
        remaining -= read_size;
    }

    file_close(*file);
    free_pages(dest, page_count);
    return source_size;
}

generate_dummy_file :: (filename: string, size: u64) -> bool {
    file, ok := file_open(filename, for_writing=true);
    if !ok {
        print("error opening file '%' for writing\n", filename);
        exit(1);
    }

    page_count := calc_page_count(size, PAGE_SIZE);
    data := cast(*u8) alloc_pages(page_count);
    write_all_cachelines(data, size);

    ok = file_write(*file, data, xx size);
    file_close(*file);

    return ok;
}

print_csv :: (results: []Result) {
    print("RESULTS (CSV):\n");
    print("--------------\n");
    print("dest_buffer_size");
    for results[0].metrics  print(",%", it.name);
    print("\n");

    for results {
        using it;
        print("%", it.dest_buffer_size);
        for metric: it.metrics {
            print(",%", metric.best);
        }
        print("\n");
    }
}

Result :: struct {
    dest_buffer_size: u64;

    metrics: [3]struct {
        name: string;
        best: float;
    };
};

main :: () {
    // ensure all pages are provisioned by writing to each cacheline
    page_size :: PAGE_SIZE;
    source_page_count,  source_size := calc_page_count(xx Gigabyte(1), page_size);
    source := cast(*u8) alloc_pages(source_page_count);
    touch_all_pages(source, source_page_count, page_size);

    dummy_filename := "./dummy_file";
    print("generating dummy file '%' with size=%\n",
            dummy_filename, pretty_print_byte_size(source_size));
    if !generate_dummy_file(dummy_filename, source_size) {
        print("error generating dummy file '%'\n", dummy_filename);
        exit(1);
    }
    defer { file_delete(dummy_filename); }

    tests := Test.[
        .{"allocate_and_touch", allocate_and_touch},
        .{"allocate_and_copy",  allocate_and_copy},
        .{"allocate_and_read",  allocate_and_read_os},
    ];
    assert(Result.metrics.count >= tests.count);

    results: [..]Result;
    dest_size := cast(u64) Kilobyte(256);
    while dest_size <= source_size {
        result: Result;
        for *test: tests {
            name := tprint("% (dest_size=%)", test.name, pretty_print_byte_size(dest_size));
            tester := repetition_test_init(name, max_iters=200, improve_threshold=100);

            while repetition_test_is_running(*tester) {
                repetition_test_start(*tester);
                bytes_processed := test.proc(dest_size, dummy_filename, source, source_size);
                repetition_test_stop(*tester, bytes_processed);
            }

            result.dest_buffer_size = dest_size;
            result.metrics[it_index].name = test.name;
            result.metrics[it_index].best = cast(float) gigabytes_per_second(repetition_test_get_best(*tester));
        }
        array_add(*results, result);
        dest_size *= 2;
    }

    print_csv(results);
}
