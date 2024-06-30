#if OS == .LINUX {
    #scope_file
    #import "System"; // for get_error_value, get_error_string

    RUSAGE_SELF: u32 : 0;
    getrusage :: (who: u32, usage: *rusage) -> s32 #foreign libc;
    libc :: #library,system "libc";

    #scope_export
    page_fault_counter :: () -> (count: u64, success: bool) {
        // rusage distinguishes between soft and hard page faults:
        //
        // ru_minflt (soft)
        //     The number of page faults serviced without any I/O activity;
        //     here I/O activity is avoided by "reclaiming" a page frame from
        //     the list of pages awaiting reallocation.
        //     (the normal lazy evaluation of virtual-to-physical memory mapping).
        // ru_majflt (hard)
        //     The number of page faults serviced that required I/O activity
        //     (recall after previously swapping to disk, or other mmio).
        //
        // Just return the sum of both here, and leave distinguishing to other API
        // calls.

        usage: rusage;
        ret := getrusage(RUSAGE_SELF, *usage);
        if (ret != 0) {
            errno, error := get_error_value_and_string();
            print("call to getrusage failed with error (%): %\n", errno, error);
            return 0, false;
        }

        fault_count := cast(u64) usage.ru_minflt + cast(u64) usage.ru_majflt;
        return fault_count, true;
    }
} else {
    page_fault_counter :: () -> (count: u64, success: bool) {
        print("% is not implemented on this platform", #procedure_name());
        return 0, false;
    }
}
