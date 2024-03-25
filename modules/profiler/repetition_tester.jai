#import "Basic";
#import "File";

Repetition_Test_Record :: struct {
    cpu_timer: u64; // determines which records are min/max among those sampled
    byte_count: u64;
    page_fault_count: u64;
}

Test_State :: enum {
    STOPPED :: 0;
    STARTED :: 1;
    FINISHED :: 2;
}

Repetition_Test :: struct {
    state: Test_State;
    iters: u64;
    max_iters: u64;

    // tracked for each test run, then moved to stats
    timer: Timer;
    initial_page_fault_count:u64;

    // stats
    min_record: Repetition_Test_Record;
    max_record: Repetition_Test_Record;
    cum_record: Repetition_Test_Record;
    cum_count: u64;
}

repetition_test_init :: (max_iters: u64 = 100) -> Repetition_Test {
    assert(max_iters > 0);

    test: Repetition_Test;
    test.state = .STOPPED;
    test.max_iters = max_iters;
    test.min_record = .{ U64_MAX, 0, 0 };
    test.max_record = .{ U64_MIN, 0, 0 };

    return test;
}

// TODO(ryan): write for_expansion that gives current iteration number
repetition_test_is_running :: (using test: *Repetition_Test) -> bool {
    assert(state == .STOPPED || state == .FINISHED);
    return state != .FINISHED;
}

repetition_test_start :: (using test: *Repetition_Test) {
    assert(state == .STOPPED);
    state = .STARTED;

    iters += 1;
    timer_reset(*timer);
    timer_start(*timer);
    initial_page_fault_count = page_fault_counter();
}

repetition_test_stop :: (using test: *Repetition_Test, count_for_bandwidth: u64) {
    timer_stop(*timer);

    assert(state == .STARTED);
    if (max_iters > 0 && iters >= max_iters) {
        state = .FINISHED;
    } else {
        state = .STOPPED;
    }

    record: Repetition_Test_Record;
    record.cpu_timer = timer.elapsed;
    record.byte_count = count_for_bandwidth;
    record.page_fault_count = page_fault_counter() - initial_page_fault_count;

    if timer.elapsed > max_record.cpu_timer
        max_record = record;
    if timer.elapsed < min_record.cpu_timer
        min_record = record;

    cum_record.cpu_timer        += record.cpu_timer;
    cum_record.byte_count       += record.byte_count;
    cum_record.page_fault_count += record.page_fault_count;
    cum_count += 1;
}

repetition_test_report :: (using test: *Repetition_Test) {
    avg_record: Repetition_Test_Record;
    if cum_count > 0 {
        avg_record.cpu_timer        = cum_record.cpu_timer        / cum_count;
        avg_record.byte_count       = cum_record.byte_count       / cum_count;
        avg_record.page_fault_count = cum_record.page_fault_count / cum_count;
    }

    print_record(*min_record, "Min");
    print_record(*max_record, "Max");
    print_record(*avg_record, "Avg");
}


#scope_file
U64_MIN :: 0;
U64_MAX :: 0xFFFFFFFF_FFFFFFFF;

print_record :: (using record: *Repetition_Test_Record, label: string) {
    FMT :: (x: Any, precision: s64 = 3) -> FormatFloat #expand {
        return formatFloat(x, trailing_width=precision, zero_removal=.NO);
    }

    cpu_freq := get_cpu_timer_freq();
    seconds := cast(float64) cpu_timer / cpu_freq;

    megabytes: float64 = 0.0;
    gigabytes: float64 = 0.0;
    gigabytes_per_second: float64 = 0.0;
    page_faults_per_second: float64 = 0.0;
    if cpu_timer > 0 {
        megabytes = cast(float64) byte_count / (1024.0 * 1024.0);
        gigabytes = megabytes / 1024.0;
        gigabytes_per_second = gigabytes / seconds;
        page_faults_per_second = cast(float64) page_fault_count / seconds;
    }

    print("%: % (% ms)", label, cpu_timer, FMT(1000 * seconds));
    if byte_count {
        print(" (% mb; % gb/s)", FMT(megabytes), FMT(gigabytes_per_second));
    }
    if page_fault_count > 0 {
        kb_per_fault := cast(float64) byte_count / (1024.0 * page_fault_count);
        print(" (% faults; % kb/fault)", page_fault_count, FMT(kb_per_fault));
    }
    print("\n");
}
