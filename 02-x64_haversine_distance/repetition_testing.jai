#import "Basic";
#import "File";

#import,dir "./profiler";

Mode :: enum {
    ALLOCATE_ON_READ :: 0;
    PREALLOCATE_UNPRIMED;
    PREALLOCATE_PRIMED;
}

Test :: struct {
    name: string;
    tester: Repetition_Test;

    mode: Mode;
    data: *u8;
}

get_file_length :: (filename: string) -> s64 {
    file, success := file_open(filename);
    assert(success);
    defer file_close(*file);

    return file_length(file);
}

run_test :: (test: *Test, max_iters_this_run: u64) {
    success: bool;
    filename := "./haversine_input.json";

    count := get_file_length(filename);
    assert(count > 0);

    if !test.data && test.mode == .PREALLOCATE_UNPRIMED || test.mode == .PREALLOCATE_PRIMED {
        test.data = alloc(count);
        if test.mode == .PREALLOCATE_PRIMED {
            // prime memory pages for early mapping
            memset(test.data, 0, count);
        }
    }

    iter: u64 = 0;
    while repetition_test_is_running(*test.tester) && iter < max_iters_this_run {
        iter += 1;

        file:, success = file_open(filename);
        if test.mode == .ALLOCATE_ON_READ
            test.data = alloc(count);

        repetition_test_start(*test.tester);
        {
            success, read_count: = file_read(file, test.data, count);
            assert(read_count == count);
        }
        repetition_test_stop(*test.tester, cast(u64)count);

        file_close(*file);
        if test.mode == .ALLOCATE_ON_READ
            free(test.data);
    }
}

#import "Reflection";
main :: () {
    ITERS_PER_BATCH      :: 10;
    TOTAL_ITERS_PER_TEST :: 100;

    tests: [3]Test = .[
        .{ mode = Mode.ALLOCATE_ON_READ, },
        .{ mode = Mode.PREALLOCATE_UNPRIMED, },
        .{ mode = Mode.PREALLOCATE_PRIMED, },
    ];
    for *test: tests {
        test.name = enum_value_to_name(test.mode);
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

        run_test(test, ITERS_PER_BATCH);
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
