#load "timing.jai";

#scope_file
Profiler :: struct {
    start_tsc: u64;
}
Profile_Entry :: struct {
    tsc_elapsed_inclusive: u64;
    tsc_elapsed_exclusive: u64;
    hit_count: u64;
    label: string;
}
global_profiler: Profiler;
latest_parent_index: s64 = -1;

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


// locally scoped instance of a globally stored Profile_Entry
Profile_Block :: struct {
    entry_index: u64;
    label: string;

    started: bool;
    start_tsc: u64;
    old_tsc_elapsed_inclusive: u64; // remember at block open for recursive handling

    // handle nested blocks
    parent_entry_index: s64;
}

#scope_export
profile_block_init :: (label: string, loc := #caller_location) -> Profile_Block #expand {
    index: u64 : #run profile_get_unique_index();

    block: Profile_Block;
    block.entry_index = index;
    block.label = label;

    return block;
}

profile_block_start :: (block: *Profile_Block) {
    assert(!block.started);
    block.started = true;

    entry := *entries[block.entry_index];
    block.old_tsc_elapsed_inclusive = entry.tsc_elapsed_inclusive;

    block.start_tsc = read_cpu_timer();
    block.parent_entry_index = latest_parent_index;
    latest_parent_index = cast(s64) block.entry_index;
}

profile_block_stop :: (block: *Profile_Block) {
    assert(block.entry_index < entry_count);
    entry := *entries[block.entry_index];

    assert(block.started);
    block.started = false;

    duration := read_cpu_timer() - block.start_tsc;
    entry.tsc_elapsed_exclusive += duration;
    entry.tsc_elapsed_inclusive = block.old_tsc_elapsed_inclusive + duration;
    entry.hit_count += 1;
    entry.label = block.label;

    // TODO(ryan): reserve block 0 to avoid the branch and always have a valid parent
    if block.parent_entry_index >= 0 {
        parent_entry := *entries[block.parent_entry_index];
        parent_entry.tsc_elapsed_exclusive -= duration;
    }

    latest_parent_index = block.parent_entry_index;
}

profile_block :: (label: string, loc := #caller_location) #expand {
    block := profile_block_init(label, loc);
    profile_block_start(*block);
    `defer profile_block_stop(*block);
}

profile_function :: (loc := #caller_location) #expand {
    block := profile_block_init(#procedure_name(), loc);
    profile_block_start(*block);
    `defer profile_block_stop(*block);
}

profiler_begin :: () {
    using global_profiler;
    start_tsc = read_cpu_timer();
}

profiler_end_and_summarize :: () {
    using global_profiler;
    total_elapsed := read_cpu_timer() - start_tsc;
    unmeasured := total_elapsed;

    print("Profiler Summary (total: % ticks; %s):\n", total_elapsed,
        cast(float64)total_elapsed / cast(float64)get_cpu_timer_freq());
    if entry_count for index : 0..entry_count-1 {
        entry := *entries[index];
        if entry.tsc_elapsed_exclusive == 0  continue;

        duration := entry.tsc_elapsed_exclusive;

        assert(unmeasured >= duration);
        unmeasured -= duration;

        percentage := 100.0 * cast(float64) duration / cast(float64) total_elapsed;
        print("  - %: % ticks (%0%% of measured; % hits)", entry.label, duration, percentage, entry.hit_count);
        if entry.tsc_elapsed_inclusive != duration {
            percentage := 100.0 * cast(float64) entry.tsc_elapsed_inclusive / cast(float64) total_elapsed;
            print(", w/ children: % ticks (%0%% of measured)", entry.tsc_elapsed_inclusive, percentage);
        }
        print("\n");
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
