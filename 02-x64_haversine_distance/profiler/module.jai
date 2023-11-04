// set DISABLED = true to make all calls no-ops, so instrumentation is disabled
// without modifying one's program
#module_parameters()(DISABLED := false);

#load "repetition_tester.jai";
#load "timing.jai";

#scope_file
#import "Compiler";
PROFILER_DEBUG :: #run -> bool {
    // NOTE(ryan): as of jai "beta 0.1.063, built on 12 May 2023", this is a robust test of `-release` during build,
    // but it may not stay that way!
    options := get_build_options();
    is_debug := options.array_bounds_check != .OFF;
    return is_debug;
};

Profiler :: struct {
    start_tsc: u64;
}
global_profiler: Profiler;

#if !DISABLED {
    #scope_file
    Profile_Entry :: struct {
        tsc_elapsed_inclusive: u64;
        tsc_elapsed_exclusive: u64;
        hit_count: u64;
        byte_count: u64;
        label: string;
    }

    // NOTE(ryan): entries[0] reserved to avoid branching for root-level profile blocks
    entries: [1024]Profile_Entry;
    latest_parent_index: s64;
    #no_reset profile_entry_count: u64 = 0;

    profile_get_unique_index :: (loc := #caller_location) -> u64 {
        // called at compile-time to retrieve the same entry for each call from a particular location
        // so that looping calls can aggregate into the same entry.
        assert(#compile_time);

        profile_entry_count += 1;
        index := profile_entry_count;
        assert(index < entries.count-1);

        return index;
    }

    #scope_export
    // locally scoped instance of a globally stored Profile_Entry
    Profile_Block :: struct {
        entry_index: u64;
        label: string;

        start_tsc: u64;
        old_tsc_elapsed_inclusive: u64; // remember at block open for recursive handling

        // handle nested blocks
        parent_entry_index: s64;

        #if PROFILER_DEBUG
        started: bool;
    }

    profile_block_init :: (label: string, byte_count: u64 = 0, loc := #caller_location) -> Profile_Block #expand {
        index: u64 : #run profile_get_unique_index(loc);

        block: Profile_Block;
        block.entry_index = index;
        block.label = label;

        entry := *entries[block.entry_index];
        entry.byte_count += byte_count;

        return block;
    }

    profile_block_start :: (block: *Profile_Block) {
        #if PROFILER_DEBUG {
            assert(!block.started);
            block.started = true;
        }

        entry := *entries[block.entry_index];
        block.old_tsc_elapsed_inclusive = entry.tsc_elapsed_inclusive;

        block.start_tsc = read_cpu_timer();
        block.parent_entry_index = latest_parent_index;
        latest_parent_index = cast(s64) block.entry_index;
    }

    profile_block_stop :: (block: *Profile_Block) {
        latest_parent_index = block.parent_entry_index;
        duration := read_cpu_timer() - block.start_tsc;

        parent_entry := *entries[block.parent_entry_index];
        entry        := *entries[block.entry_index];

        #if PROFILER_DEBUG {
            assert(block.started);
            block.started = false;
        }

        parent_entry.tsc_elapsed_exclusive -= duration;
        entry.tsc_elapsed_exclusive += duration;
        entry.tsc_elapsed_inclusive  = block.old_tsc_elapsed_inclusive + duration;
        entry.hit_count += 1;
        entry.label = block.label;
    }

    profile_block :: (label: string, loc := #caller_location) #expand {
        block := profile_block_init(label, 0, loc);
        profile_block_start(*block);
        `defer profile_block_stop(*block);
    }

    profile_function :: (loc := #caller_location) #expand {
        block := profile_block_init(#procedure_name(), 0, loc);
        profile_block_start(*block);
        `defer profile_block_stop(*block);
    }

    profile_block_bandwidth :: (label: string, byte_count: u64, loc := #caller_location) #expand {
        block := profile_block_init(label, byte_count, loc);
        profile_block_start(*block);
        `defer profile_block_stop(*block);
    }
} else {
    #scope_export
    Profile_Block :: *void;

    profile_block_init :: (label: string, byte_count: u64 = 0, loc := #caller_location) -> Profile_Block #expand {
        return null;
    }
    profile_block_start :: (block: *Profile_Block) {}
    profile_block_stop :: (block: *Profile_Block) {}
    profile_block :: (label: string, loc := #caller_location) #expand {}
    profile_function :: (loc := #caller_location) #expand {}
    profile_block_bandwidth :: (label: string, byte_count: u64, loc := #caller_location) #expand {}
}


#scope_export
profiler_begin :: () {
    using global_profiler;
    start_tsc = read_cpu_timer();
}

profiler_end_and_summarize :: () {
    FMT :: (x: Any, precision: s64) -> FormatFloat #expand {
        return formatFloat(x, trailing_width=precision, zero_removal=.NO);
    }

    using global_profiler;
    assert(start_tsc > 0); // Forgot to call profiler_begin()?

    total_elapsed := read_cpu_timer() - start_tsc;
    timer_freq := cast(float64) get_cpu_timer_freq();
    total_seconds := cast(float64) total_elapsed / timer_freq;
    print("Profiler Summary (total: % s; timer freq: % GHz)\n",
        FMT(total_seconds * 1000.0, 4),
        FMT(timer_freq / 1_000_000_000.0, 2));

    #if !DISABLED {

        unmeasured := total_elapsed;
        if profile_entry_count > 0  for index : 1..profile_entry_count-1 {
            entry := *entries[index];
            if entry.tsc_elapsed_inclusive == 0  continue;

            inclusive := entry.tsc_elapsed_inclusive;
            exclusive := entry.tsc_elapsed_exclusive;

            assert(unmeasured >= exclusive);
            unmeasured -= exclusive;

            percentage := 100.0 * cast(float64) exclusive / cast(float64) total_elapsed;
            print("  - %[%]: % (%0%%", entry.label, entry.hit_count, exclusive, FMT(percentage, 2));
            if inclusive != exclusive {
                percentage := 100.0 * cast(float64) inclusive / cast(float64) total_elapsed;
                print(", %0%% w/children", FMT(percentage, 2));
            }
            print(")");

            if entry.byte_count > 0 {
                megabytes := cast(float64) entry.byte_count / cast(float64) (1024 * 1024);
                gigabytes := megabytes / 1024.0;
                gigabytes_per_second := gigabytes * timer_freq / cast(float64) inclusive;
                print(" (% mb; % gb/s)", megabytes, gigabytes_per_second);
            }
            print("\n");
        }

        if (unmeasured > 0) {
            percentage := 100.0 * cast(float64) unmeasured / cast(float64) total_elapsed;
            print("  - (unmeasured): % (%0%%)\n", unmeasured, FMT(percentage, 2));
        }
    }
}

Timer :: struct {
    start: u64;
    elapsed: u64;
}
timer_start :: (using timer: *Timer) {
    start = read_cpu_timer();
}
timer_stop :: (using timer: *Timer) {
    timer_stop := read_cpu_timer();
    elapsed += timer_stop - start;
}
timer_reset :: (using timer: *Timer) {
    elapsed = 0;
}
timer_seconds :: (using timer: *Timer) -> float64 {
    return cast(float64) elapsed / get_cpu_timer_freq();
}
