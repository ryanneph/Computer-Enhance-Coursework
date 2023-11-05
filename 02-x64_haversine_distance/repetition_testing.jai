#import "Basic";
#import "File";

#import,dir "./profiler";

Mode :: enum {
    ALLOCATE_ON_READ :: 0;
    PREALLOCATE_UNPRIMED;
    PREALLOCATE_PRIMED;
}

get_file_length :: (filename: string) -> s64 {
    file, success := file_open(filename);
    assert(success);
    defer file_close(*file);

    return file_length(file);
}

run_test :: (tester: *Repetition_Test, mode: Mode, max_iters_this_run: u64) {
    success: bool;
    filename := "./haversine_input.json";

    count := get_file_length(filename);
    assert(count > 0);

    data: *u8;
    if mode == .PREALLOCATE_UNPRIMED || mode == .PREALLOCATE_PRIMED {
        data = alloc(count);
        if mode == .PREALLOCATE_PRIMED {
            // prime memory pages for early mapping
            memset(data, 0, count);
        }
    }

    iter: u64 = 0;
    while repetition_test_is_running(tester) && iter < max_iters_this_run {
        iter += 1;

        file:, success = file_open(filename);
        if mode == .ALLOCATE_ON_READ
            data = alloc(count);

        repetition_test_start(tester);
        {
            success, read_count: = file_read(file, data, count);
            assert(read_count == count);
        }
        repetition_test_stop(tester, cast(u64)count);

        file_close(*file);
        if mode == .ALLOCATE_ON_READ
            free(data);
    }
}

Test :: struct {
    name: string;
    mode: Mode;
    tester: Repetition_Test;
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

        run_test(*test.tester, test.mode, ITERS_PER_BATCH);
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
