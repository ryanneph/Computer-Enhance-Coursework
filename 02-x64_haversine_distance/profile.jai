#load "timing.jai";

#scope_file
Profiler :: struct {
    start_tsc: u64;
}
Profile_Entry :: struct {
    tsc_elapsed: u64;
    hit_count: u64;
    label: string;

    started: bool;
    start_tsc: u64;
}
global_profiler: Profiler;

entries: [1024]Profile_Entry;
#no_reset entry_count: u64 = 0;
profile_get_unique_index :: () -> u64 {
    // called at compile-time to retrieve the same entry for each call from a particular location
    // so that looping calls can aggregate into the same entry.
    assert(#compile_time);
    assert(entry_count < entries.count);

    index := entry_count;
    entry_count += 1;

    return index;
}


#scope_export
Profile_Segment :: *void;
profile_segment_init :: (label: string, loc := #caller_location) -> (profile_entry_handle: Profile_Segment) #expand {
    index: u64 : #run profile_get_unique_index();
    entry := *entries[index];
    entry.label = label;

    return cast(Profile_Segment)entry;
}

profile_segment_start :: (profile_segment: Profile_Segment) {
    entry := cast(*Profile_Entry) profile_segment;

    assert(!entry.started);
    entry.started = true;

    entry.start_tsc = read_cpu_timer();
}

profile_segment_stop :: (profile_segment: Profile_Segment) {
    entry := cast(*Profile_Entry) profile_segment;

    assert(entry.started);
    entry.started = false;

    duration := read_cpu_timer() - entry.start_tsc;
    entry.tsc_elapsed += duration;
    entry.hit_count += 1;
}

profile_block :: (label: string, loc := #caller_location) #expand {
    segment := profile_segment_init(label, loc);
    profile_segment_start(segment);
    `defer profile_segment_stop(segment);
}

profile_function :: (loc := #caller_location) #expand {
    profile_block(#procedure_name(), loc);
}

profiler_begin :: () {
    using global_profiler;
    start_tsc = read_cpu_timer();
}

profiler_end_and_summarize :: () {
    assert(entry_count > 0);

    using global_profiler;
    total_elapsed := read_cpu_timer() - start_tsc;
    unmeasured := total_elapsed;

    print("Profiler Summary (total: % ticks; %s):\n", total_elapsed,
        cast(float64)total_elapsed / cast(float64)get_cpu_timer_freq());
    for index : 0..entry_count-1 {
        entry := *entries[index];
        if entry.tsc_elapsed == 0  continue;

        assert(unmeasured >= entry.tsc_elapsed);
        unmeasured -= entry.tsc_elapsed;

        percentage := 100.0 * cast(float64) entry.tsc_elapsed / cast(float64) total_elapsed;
        print("  - %: % ticks (%0%% of measured) (% hits)\n", entry.label, entry.tsc_elapsed, percentage, entry.hit_count);
    }

    if (unmeasured > 0) {
        percentage := 100.0 * cast(float64) unmeasured / cast(float64) total_elapsed;
        print("  - (unmeasured): % ticks (%0%% of measured)\n", unmeasured, percentage);
    }
}

Timer :: struct {
    start: u64;
    elapsed: u64;
}
timer_start :: (timer: *Timer) #expand {
    timer.start = read_cpu_timer();
}
timer_stop :: (timer: *Timer) #expand {
    timer_stop := read_cpu_timer();
    timer.elapsed += timer_stop - timer.start;
}
