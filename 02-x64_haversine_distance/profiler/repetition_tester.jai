#import "Basic";
#import "File";

#scope_file
U64_MIN :: 0;
U64_MAX :: 0xFFFFFFFF_FFFFFFFF;

print_record :: (using record: *Repetition_Test_Record, label: string) {
    FMT :: (x: Any, precision: s64 = 3) -> FormatFloat #expand {
        return formatFloat(x, trailing_width=precision, zero_removal=.NO);
    }

    cpu_freq := get_cpu_timer_freq();
    seconds := cast(float64) elapsed / cpu_freq;

    megabytes: float64 = 0.0;
    gigabytes: float64 = 0.0;
    gigabytes_per_second: float64 = 0.0;
    if elapsed > 0 {
        megabytes = cast(float64) data_count / cast(float64) (1024 * 1024);
        gigabytes = megabytes / 1024.0;
        gigabytes_per_second = gigabytes / seconds;
    }

    print("%: % (% ms) (% mb; % gb/s)\n", label, elapsed,
        FMT(1000 * seconds), FMT(megabytes), FMT(gigabytes_per_second));
}


#scope_export
Repetition_Test_Record :: struct {
    elapsed: u64;
    data_count: u64;
}

Repetition_Test :: struct {
    iters: u64;
    max_iters: u64;
    timer: Timer;

    // stats
    min_record: Repetition_Test_Record;
    max_record: Repetition_Test_Record;
    cum_record: Repetition_Test_Record;
    cum_count: u64;
}

repetition_test_init :: (max_iters: u64 = 100) -> Repetition_Test {
    assert(max_iters > 0);

    test: Repetition_Test;
    test.max_iters = max_iters;
    test.min_record = .{ U64_MAX, 0 };
    test.max_record = .{ U64_MIN, 0 };

    return test;
}

// TODO(ryan): write for_expansion that gives current iteration number
repetition_test_is_running :: (using test: *Repetition_Test) -> bool {
    return !max_iters || iters < max_iters;
}

repetition_test_start :: (using test: *Repetition_Test) {
    iters += 1;
    timer_reset(*timer);
    timer_start(*timer);
}

repetition_test_stop :: (using test: *Repetition_Test, count_for_bandwidth: u64) {
    timer_stop(*timer);

    if timer.elapsed > max_record.elapsed {
        max_record.elapsed = timer.elapsed;
        max_record.data_count = count_for_bandwidth;
    }
    if timer.elapsed < min_record.elapsed {
        min_record.elapsed = timer.elapsed;
        min_record.data_count = count_for_bandwidth;
    }

    cum_record.elapsed += timer.elapsed;
    cum_record.data_count += count_for_bandwidth;
    cum_count += 1;
}

repetition_test_report :: (using test: *Repetition_Test) {
    cpu_freq := get_cpu_timer_freq(); // this may take some time, so do it on cold path


    avg_record: Repetition_Test_Record;
    if cum_count > 0 {
        avg_record.elapsed    = cum_record.elapsed    / cum_count;
        avg_record.data_count = cum_record.data_count / cum_count;
    }

    print_record(*min_record, "Min");
    print_record(*max_record, "Max");
    print_record(*avg_record, "Avg");
}
