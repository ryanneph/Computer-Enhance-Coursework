#if OS == .LINUX {
    #scope_file;
    #import "POSIX";

    libc :: #system_library "libc";
    sched_setaffinity :: (pid: pid_t, cpusetsize: size_t, mask: *cpu_set_t) -> s32 #foreign libc;

    cpu_set_t :: struct {
        a: [32]s32;
    }


    set_cpu_affinity :: () {
        mask: cpu_set_t;
        mask.a[0] = 0x1;
        sched_setaffinity(0, size_of(cpu_set_t), *mask);
    }

    #scope_export;
}
