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

    print("  - %: % (% ms) (% mb; % gb/s)\n", label, elapsed,
        FMT(1000 * seconds), FMT(megabytes), FMT(gigabytes_per_second));
}

Repetition_Test_Record :: struct {
    elapsed: u64;
    data_count: u64;
}

Repetition_Test :: struct {
    iterations: s64;
    timer: Timer;

    // stats
    min_record: Repetition_Test_Record;
    max_record: Repetition_Test_Record;
    avg_record: Repetition_Test_Record;
    avg_count: u64;
}


#scope_export
repetition_test_init :: (iterations: s64) -> Repetition_Test {
    assert(iterations > 0);

    test: Repetition_Test;
    test.iterations = iterations;
    test.min_record = .{ U64_MAX, 0 };
    test.max_record = .{ U64_MIN, 0 };

    return test;
}

// TODO(ryan): write for_expansion that gives current iteration number
repetition_test_is_running :: (using test: *Repetition_Test) -> bool {
    iter := iterations;
    iterations -= 1;
    return iter > 0;
}

repetition_test_start :: (using test: *Repetition_Test) {
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

    avg_record.elapsed += timer.elapsed;
    avg_record.data_count += count_for_bandwidth;
    avg_count += 1;
}

repetition_test_report :: (using test: *Repetition_Test) {
    cpu_freq := get_cpu_timer_freq(); // this may take some time, so do it on cold path

    if avg_count > 0 {
        avg_record.elapsed    = avg_record.elapsed    / avg_count;
        avg_record.data_count = avg_record.data_count / avg_count;
    }

    print("Bandwidth Stats:\n");
    print_record(*min_record, "Min");
    print_record(*max_record, "Max");
    print_record(*avg_record, "Avg");
}
