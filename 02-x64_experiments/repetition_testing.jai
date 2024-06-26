#import "Basic";
#import "File";

#import,dir "../modules/profiler";
#import,dir "../modules/memory_utils";

READ_FILENAME :: "../02-x64_haversine_distance/haversine_input.json";

Allocate_Mode :: enum {
    EVERY_ITER :: 0;
    PREALLOCATE_UNPRIMED;
    PREALLOCATE_PRIMED;
    LOCKED;
}

Test_Proc_Type :: #type (test: *Test);

Test :: struct {
    name: string;
    tester: Repetition_Test;

    allocate_mode: Allocate_Mode;
    proc: Test_Proc_Type;
    data: *u8;
    data_count: s64;
}

get_file_length :: (filename: string) -> s64 {
    file, success := file_open(filename);
    assert(success);
    defer file_close(*file);

    return file_length(file);
}

test_set_data :: (test: *Test, addr: *void, count: s64) {
    test.data = addr;
    test.data_count = count;
}

handle_preallocation :: (test: *Test, count: s64) {
    if !test.data && test.allocate_mode == .PREALLOCATE_UNPRIMED || test.allocate_mode == .PREALLOCATE_PRIMED {
        data := alloc(count);
        test_set_data(test, data, count);
        if test.allocate_mode == .PREALLOCATE_PRIMED {
            // prime memory pages for early mapping
            memset(test.data, 0, count);
        }
    }
}

handle_allocation :: (test: *Test, count: s64) {
    if test.allocate_mode == .EVERY_ITER {
        assert(test.data == null);
        data := alloc(count);
        test_set_data(test, data, count);
    } else if test.allocate_mode == .LOCKED {
        assert(test.data == null);
        page_count := ((cast(u64)count) + PAGE_SIZE-1) / PAGE_SIZE;
        alloc_count := page_count * PAGE_SIZE;
        data := alloc_pages(page_count);
        test_set_data(test, data, cast(s64)alloc_count);
        lock_memory_range(test.data, alloc_count);
    }
}

handle_free :: (test: *Test) {
    if test.allocate_mode == .EVERY_ITER {
        assert(test.data != null);
        free(test.data);
        test.data = null;
        test_set_data(test, null, 0);
    } else if test.allocate_mode == .LOCKED {
        assert(test.data != null);
        unlock_memory_range(test.data, cast(u64)test.data_count);
        free_pages(test.data, (cast(u64)test.data_count) / PAGE_SIZE);
        test_set_data(test, null, 0);
    }
}

run_file_read_test :: (test: *Test) {
    success: bool;
    filename := READ_FILENAME;

    count := get_file_length(filename);
    assert(count > 0);

    handle_preallocation(test, count);

    while repetition_test_is_running(*test.tester) {
        file:, success = file_open(filename);
        handle_allocation(test, count);

        repetition_test_start(*test.tester);
        success, read_count: = file_read(file, test.data, count);
        assert(read_count == count);
        repetition_test_stop(*test.tester, cast(u64) count);

        file_close(*file);
        handle_free(test);
    }
}

run_buffer_write_test :: (test: *Test) {
    filename := READ_FILENAME;
    count := get_file_length(filename);

    handle_preallocation(test, count);

    while repetition_test_is_running(*test.tester) {
        handle_allocation(test, count);

        repetition_test_start(*test.tester);
        for i: 0..count-1 {
            test.data[i] = cast,no_check(u8)i;
        }
        repetition_test_stop(*test.tester, cast(u64) count);

        handle_free(test);
    }
}

run_buffer_write_test_reverse :: (test: *Test) {
    filename := READ_FILENAME;
    count := get_file_length(filename);

    handle_preallocation(test, count);

    while repetition_test_is_running(*test.tester) {
        handle_allocation(test, count);

        repetition_test_start(*test.tester);
        for i: 0..count-1 {
            test.data[count - 1 - i] = cast,no_check(u8)i;
        }
        repetition_test_stop(*test.tester, cast(u64) count);

        handle_free(test);
    }
}

#import "Reflection"; // for enum_value_to_name()
main :: () {
    ITERS_PER_BATCH      :: 10;
    TOTAL_ITERS_PER_TEST :: 100;

    tests := Test.[
        .{ name = "file_read",            allocate_mode = .EVERY_ITER,           proc = run_file_read_test },
        .{ name = "file_read",            allocate_mode = .PREALLOCATE_UNPRIMED, proc = run_file_read_test },
        .{ name = "file_read",            allocate_mode = .PREALLOCATE_PRIMED,   proc = run_file_read_test },
        .{ name = "file_read",            allocate_mode = .LOCKED,               proc = run_file_read_test },
        .{ name = "buffer_write",         allocate_mode = .EVERY_ITER,           proc = run_buffer_write_test },
        .{ name = "buffer_write_reverse", allocate_mode = .EVERY_ITER,           proc = run_buffer_write_test_reverse },
    ];
    for *test: tests {
        test.name = sprint("%::%", test.name, enum_value_to_name(test.allocate_mode));
        test.tester = repetition_test_init(name=test.name, max_iters=ITERS_PER_BATCH, improve_threshold=0);
    }

    running := tests.count;
    test_index := 0;
    while running > 0 {
        test := *tests[test_index];
        if repetition_test_get_iters(*test.tester) >= TOTAL_ITERS_PER_TEST {
            running -= 1;
            continue;
        }

        test.proc(test);
        repetition_test_set_max_iters(*test.tester, repetition_test_get_iters(*test.tester) + ITERS_PER_BATCH);
        test_index = (test_index + 1) % tests.count;
    }

    for *test: tests {
        using test;
        print("------------------------------------------------------------------\n");
        print("Final report for test '%' after % iters\n", name, repetition_test_get_iters(*tester));
        repetition_test_report(*tester);
        print("------------------------------------------------------------------\n");
    }
}
