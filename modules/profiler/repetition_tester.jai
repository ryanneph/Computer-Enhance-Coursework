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
    name: string;
    state: Test_State;
    iters: u64;

    // logging
    do_pre_print: bool;
    quiet: bool;

    // tracked for each test run, then moved to stats
    timer: Timer;
    initial_page_fault_count:u64;

    // stopping condition
    improve_threshold: u64;
    consecutive_without_improvement: u64;
    max_iters: u64;

    // stats
    min_record: Repetition_Test_Record;
    max_record: Repetition_Test_Record;
    avg_record: Repetition_Test_Record;

    cum_record: Repetition_Test_Record;
    cum_count: u64;
}

repetition_test_init :: (name: string, max_iters: u64 = 1000, improve_threshold: u64 = 200, quiet := false) -> Repetition_Test {
    assert(max_iters > 0);

    test: Repetition_Test;
    test.name = name;
    test.state = .STOPPED;
    test.do_pre_print = true;
    test.quiet = quiet;
    test.improve_threshold = improve_threshold;
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

    if !quiet && do_pre_print {
        pre_print(test);
        do_pre_print = false;
    }

    iters += 1;
    initial_page_fault_count = page_fault_counter();
    timer_reset(*timer);
    timer_start(*timer);
}

repetition_test_stop :: (using test: *Repetition_Test, count_for_bandwidth: u64) {
    timer_stop(*timer);
    assert(state == .STARTED);

    // early stopping criteria
    // reset counter on improved, otherwise increment
    not_improved := cast(u64) (min_record.cpu_timer <= timer.elapsed);
    not_improved_mask := ~(not_improved - 1); // 1s: not-improved, 0s: improved
    consecutive_without_improvement = (consecutive_without_improvement + not_improved) & not_improved_mask;

    // stats tracking
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

    update_avg_record(test);
    if !quiet  during_print(test);

    // update test state
    reached_max_iters := max_iters > 0 && iters >= max_iters;
    if (reached_max_iters || reached_progress_floor(test)) {
        state = .FINISHED;
        if !quiet  post_print(test);
    } else {
        state = .STOPPED;
    }

}

repetition_test_set_max_iters :: (using test: *Repetition_Test, new_max: u64) {
    if new_max > iters && state == .FINISHED {
        state = .STOPPED;
        do_pre_print = true;
    }
    max_iters = new_max;
}

repetition_test_report :: (using test: *Repetition_Test) {
    print_record(*min_record, "Min");
    print_record(*max_record, "Max");
    print_record(*avg_record, "Avg");
}

repetition_test_get_iters :: (using test: *Repetition_Test) -> u64 {
    return iters;
}

repetition_test_get_best :: (using test: *Repetition_Test) -> Repetition_Test_Record {
    return min_record;
}


#scope_file
U64_MIN :: 0;
U64_MAX :: 0xFFFFFFFF_FFFFFFFF;

Megabyte :: (count: $T) -> T #expand { return count * 1048576; }
Gigabyte :: (count: $T) -> T #expand { return count * 1073741824; }

reached_progress_floor :: (using test: *Repetition_Test) -> bool {
    return improve_threshold > 0 &&
        consecutive_without_improvement >= improve_threshold;
}

update_avg_record :: (using test: *Repetition_Test) {
    if cum_count > 0 {
        avg_record.cpu_timer        = cum_record.cpu_timer        / cum_count;
        avg_record.byte_count       = cum_record.byte_count       / cum_count;
        avg_record.page_fault_count = cum_record.page_fault_count / cum_count;
    }
}

pre_print :: (using test: *Repetition_Test) {
    print("Running test %\n", name);
    print("------------------------------------------------------------\n");
    repetition_test_report(test);
}

during_print :: (using test: *Repetition_Test) {
    clear_previous_lines(3);
    update_avg_record(test);
    repetition_test_report(test);
}

post_print :: (using test: *Repetition_Test) {
    print("------------------------------------------------------------\n");
    reason := ifx iters == max_iters then "max iters reached" else "no further improvement";
    print("(% after % iters)\n\n", reason, iters);
}

clear_previous_lines :: (count: s64) {
    print("\x1b[%F", count); // move up 3 lines and to beginning
}

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
        megabytes = cast(float64) byte_count / Megabyte(1);
        gigabytes = cast(float64) byte_count / Gigabyte(1);
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
