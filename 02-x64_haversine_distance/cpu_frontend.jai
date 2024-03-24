#import "Basic";

#import,dir "./memory_utils";
#import,dir "./profiler";

libasm :: #library,no_dll "cpu_frontend";
mov_all_bytes_asm :: (dest: *u8, count: u64) #c_call #foreign libasm;
nop_all_bytes_asm :: (dest: *u8, count: u64) #c_call #foreign libasm;
cmp_all_bytes_asm :: (dest: *u8, count: u64) #c_call #foreign libasm;
dec_all_bytes_asm :: (dest: *u8, count: u64) #c_call #foreign libasm;


Test_Proc :: #type (dest: *u8, count: u64) #c_call;

main :: () {
    byte_count: u64 : 1024 * 1024 * 1024;
    dest := cast(*u8) alloc(cast(s64) byte_count);
    lock_memory_range(dest, byte_count); // pre-fault all memory pages

    Test :: struct {
        name: string;
        proc: Test_Proc;
        tester: Repetition_Test;
    }
    tests := Test.[
        // .{ name = "mov_all_bytes_asm", proc = mov_all_bytes_asm },
        // .{ name = "nop_all_bytes_asm", proc = nop_all_bytes_asm },
        .{ name = "cmp_all_bytes_asm", proc = cmp_all_bytes_asm },
        // .{ name = "dec_all_bytes_asm", proc = dec_all_bytes_asm },
    ];

    for *test: tests {
        test.tester = repetition_test_init(max_iters=100);
    }

    for test: tests {
        print("%\n", test.name);
        while repetition_test_is_running(*test.tester) {
            repetition_test_start(*test.tester);
            test.proc(dest, byte_count);
            repetition_test_stop(*test.tester, byte_count);
        }
    }

    for test: tests {
        print("Test \"%\":\n", test.name);
        repetition_test_report(*test.tester);
        print("\n");
    }
}

//
// BUILD-ONLY
//
#import "Compiler";
#import "Process";
build :: () {
    // build asm into a static libary
    output_filename :: "cpu_frontend.a";
    print("Building asm library: % ... ", output_filename);
    args := string.["nasm", "-g", "-f", "elf64", "-o", output_filename, "cpu_frontend.asm"];
    result, stdout, stderr := run_command(..args, capture_and_return_output=true);
    if result.type == .EXITED && result.exit_code == 0 {
        print("Success\n");
    } else {
        print("Failed\n");
        print("Error output:\n%", stderr);
        exit(1);
    }

    print("\nBuilding Main Program:\n");
}
#run build();
