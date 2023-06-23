#import "Basic";
#import "Machine_X64";

report_timing_info :: () {
    cpu_info := get_cpu_info();
    has_rdtsc := check_feature(cpu_info.feature_leaves, .TSC);
    assert(has_rdtsc);

    print("CPU FEATURES:\n");
    print("CPU vendor: %\n", cpu_info.vendor);
    print("RDTSC available?  %\n\n", ifx has_rdtsc "yes" else "no");

    print("INSTANTANEOUS:\n");
    print("OS   freq: %\n", get_os_timer_freq());
    print("OS  timer: %\n", read_os_timer());
    print("CPU timer: %\n\n", read_cpu_timer());

    print("CALIBRATION:\n");
    calibrate_cpu_timer();
}

calibrate_cpu_timer :: () {
    os_freq := get_os_timer_freq();

    ost_start := read_os_timer();
    ost_end := ost_start;
    ost_elapsed: u64 = 0;
    cput_start := read_cpu_timer();
    while ost_elapsed < os_freq {
        ost_end = read_os_timer();
        ost_elapsed = ost_end - ost_start;
    }
    cput_end := read_cpu_timer();

    ost_elapsed_seconds := cast(float64)ost_elapsed / cast(float64)os_freq;
    print("OS   timer: % -> % = % elapsed\n", ost_start, ost_end, ost_elapsed);
    print("OS seconds: %\n", ost_elapsed_seconds);

    cpu_freq: u64 = 0;
    cput_elapsed := cput_end - cput_start;
    if ost_elapsed {
        cpu_freq = cput_elapsed * os_freq / ost_elapsed;
    }

    print("CPU  timer: % -> % = % elapsed\n", cput_start, cput_end, cput_elapsed);
    print("CPU   freq: % Gticks/sec (guessed)\n", cast(float64)cpu_freq / 1_000_000_000);
}

#if OS == .WINDOWS {
    // TODO(ryan): Windows implementation is UNTESTED!
    #import "Windows";

    get_os_timer_freq :: inline () -> u64 {
        freq: s64;
        success := ValueQueryPerformanceFrequency(*freq);
        assert(success);
        return cast(u64) freq;
    }
} else #if OS == .LINUX {
    #import "POSIX";

    get_os_timer_freq :: inline () -> u64 {
        // fixed nanosecond output precision, but not guaranteed to be the sampling precision
        return 1_000_000_000;
    }

    read_os_timer :: () -> u64 {
        ts: timespec;
        err: int = clock_gettime(CLOCK_MONOTONIC_RAW, *ts);
        assert(!err);

        now_ns: u64 = cast(u64)ts.tv_sec * 1_000_000_000 + cast(u64)ts.tv_nsec;
        return now_ns;
    }
}

read_cpu_timer :: inline () -> u64 {
    return rdtsc();
}
