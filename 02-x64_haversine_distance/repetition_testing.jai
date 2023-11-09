#import "Basic";
#import "File";

#import,dir "./profiler";

Allocate_Mode :: enum {
    EVERY_ITER :: 0;
    PREALLOCATE_UNPRIMED;
    PREALLOCATE_PRIMED;
}

Test_Proc_Type :: #type (test: *Test, max_iters_this_run: u64);

Test :: struct {
    name: string;
    tester: Repetition_Test;

    allocate_mode: Allocate_Mode;
    proc: Test_Proc_Type;
    data: *u8;
}

get_file_length :: (filename: string) -> s64 {
    file, success := file_open(filename);
    assert(success);
    defer file_close(*file);

    return file_length(file);
}

handle_preallocation :: (test: *Test, count: s64) {
    if !test.data && test.allocate_mode == .PREALLOCATE_UNPRIMED || test.allocate_mode == .PREALLOCATE_PRIMED {
        test.data = alloc(count);
        if test.allocate_mode == .PREALLOCATE_PRIMED {
            // prime memory pages for early mapping
            memset(test.data, 0, count);
        }
    }
}

handle_allocation :: (test: *Test, count: s64) {
    if test.allocate_mode == .EVERY_ITER {
        assert(test.data == null);
        test.data = alloc(count);
    }
}

handle_free :: (test: *Test) {
    if test.allocate_mode == .EVERY_ITER {
        assert(test.data != null);
        free(test.data);
        test.data = null;
    }
}

run_file_read_test :: (test: *Test, max_iters_this_run: u64) {
    success: bool;
    filename := "./haversine_input.json";

    count := get_file_length(filename);
    assert(count > 0);

    handle_preallocation(test, count);

    iter: u64 = 0;
    while repetition_test_is_running(*test.tester) && iter < max_iters_this_run {
        iter += 1;

        file:, success = file_open(filename);
        handle_allocation(test, count);

        repetition_test_start(*test.tester);
        {
            success, read_count: = file_read(file, test.data, count);
            assert(read_count == count);
        }
        repetition_test_stop(*test.tester, cast(u64) count);

        file_close(*file);
        handle_free(test);
    }
}

run_buffer_write_test :: (test: *Test, max_iters_this_run: u64) {
    filename := "./haversine_input.json";
    count := get_file_length(filename);

    handle_preallocation(test, count);

    iter: u64 = 0;
    while repetition_test_is_running(*test.tester) && iter < max_iters_this_run {
        iter += 1;
        handle_allocation(test, count);

        repetition_test_start(*test.tester);
        {
            for i: 0..count-1 {
                test.data[i] = cast,no_check(u8)i;
            }
        }
        repetition_test_stop(*test.tester, cast(u64) count);

        handle_free(test);
    }
}

run_buffer_write_test_reverse :: (test: *Test, max_iters_this_run: u64) {
    filename := "./haversine_input.json";
    count := get_file_length(filename);

    handle_preallocation(test, count);

    iter: u64 = 0;
    while repetition_test_is_running(*test.tester) && iter < max_iters_this_run {
        iter += 1;
        handle_allocation(test, count);

        repetition_test_start(*test.tester);
        {
            for i: 0..count-1 {
                test.data[count - 1 - i] = cast,no_check(u8)i;
            }
        }
        repetition_test_stop(*test.tester, cast(u64) count);

        handle_free(test);
    }
}

#import "Reflection"; // for enum_value_to_name()
main :: () {
    ITERS_PER_BATCH      :: 10;
    TOTAL_ITERS_PER_TEST :: 100;

    tests: [5]Test = .[
        .{ name = "file_read",            allocate_mode = .EVERY_ITER,           proc = run_file_read_test },
        .{ name = "file_read",            allocate_mode = .PREALLOCATE_UNPRIMED, proc = run_file_read_test },
        .{ name = "file_read",            allocate_mode = .PREALLOCATE_PRIMED,   proc = run_file_read_test },
        .{ name = "buffer_write",         allocate_mode = .EVERY_ITER,           proc = run_buffer_write_test },
        .{ name = "buffer_write_reverse", allocate_mode = .EVERY_ITER,           proc = run_buffer_write_test_reverse },
    ];
    for *test: tests {
        test.name = sprint("%::%", test.name, enum_value_to_name(test.allocate_mode));
        test.tester = repetition_test_init(TOTAL_ITERS_PER_TEST);
    }

    running := tests.count;
    test_index := 0;
    while running > 0 {
        test := *tests[test_index];
        if !repetition_test_is_running(*test.tester) {
            running -= 1;
            continue;
        }

        test.proc(test, ITERS_PER_BATCH);
        print("report for test '%' after % iters\n", test.name, test.tester.iters);
        repetition_test_report(*test.tester);
        print("\n");

        test_index = (test_index + 1) % tests.count;
    }

    for *test: tests {
        using test;
        print("------------------------------------------------------------------\n");
        print("Final report for test '%' after % iters\n", name, tester.iters);
        repetition_test_report(*test.tester);
        print("------------------------------------------------------------------\n");
    }
}
