#load "timing.jai";

Program_Timing_Segment :: struct {
    desc: string;
    timer_elapsed: u64;

    percentage: float64;
}
program_timing: [..] Program_Timing_Segment;
add_program_timing_segment_elapsed :: (desc: string, timer_elapsed: u64) {
    segment: Program_Timing_Segment;
    segment.desc = desc;
    segment.timer_elapsed = timer_elapsed;

    array_add(*program_timing, segment);
}

Timer :: struct {
    start: u64;
    elapsed: u64;
}
timer_start :: inline (timer: *Timer) {
    timer.start = read_cpu_timer();
}
timer_stop :: inline (timer: *Timer) {
    timer_stop := read_cpu_timer();
    timer.elapsed += timer_stop - timer.start;
}

summarize_program_timing :: () {
    assert(program_timing.count > 0);

    total_elapsed: u64 = 0;
    for *program_timing
        total_elapsed += it.timer_elapsed;
    for *program_timing
        it.percentage = 100.0 * cast(float64) it.timer_elapsed / cast(float64) total_elapsed;

    print("Program Timing:\n");
    for program_timing {
        print("  - %: % ticks (%0%% of measured)\n", it.desc, it.timer_elapsed, it.percentage);
    }
}

time_block :: (desc: string) #expand {
    timer: Timer;
    timer_start(*timer);
    defer {
        timer_stop(*timer);
        add_program_timing_segment_elapsed(desc, timer.elapsed);
    }
}

time_function :: () #expand {
    time_block(#procedure_name());
}
