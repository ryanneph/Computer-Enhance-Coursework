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

main :: () {
    test := repetition_test_init(iterations = 30);

    success: bool;
    filename := "./haversine_input.json";
    mode :: Mode.ALLOCATE_ON_READ;

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

    iteration := 0;
    while repetition_test_is_running(*test) {
        iteration += 1;

        file:, success = file_open(filename);
        if mode == .ALLOCATE_ON_READ
            data = alloc(count);

        repetition_test_start(*test);
        {
            success, read_count: = file_read(file, data, count);
            assert(read_count == count);
        }
        repetition_test_stop(*test, cast(u64)count);

        file_close(*file);
        if mode == .ALLOCATE_ON_READ
            free(data);
    }
    repetition_test_report(*test);
}
