#import "Basic";
#import "File";

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
    // NOTE(ryan): obviously this is not thread-safe...
    input_return_buf: [512]u8;
    read_input :: () -> string {
        read_count := read(STDIN_FILENO, input_return_buf.data, input_return_buf.count);
        view := string.{read_count, input_return_buf.data};
        return view;
    }

    read_full_file :: (filename: string) -> (data: string, success: bool) {
        success: bool;
        contents: string;

        file:, success = file_open(filename);
        if !success {
            return .{}, false;
        }

        contents.count, success = file_length(file);
        if !success || !contents.count {
            return .{}, false;
        }

        contents.data = alloc(contents.count);
        success=, read_count: = file_read(file, contents.data, contents.count);
        if !success || read_count != contents.count {
            free(contents.data);
            return .{}, false;
        }

        return contents, success;
    }
}
