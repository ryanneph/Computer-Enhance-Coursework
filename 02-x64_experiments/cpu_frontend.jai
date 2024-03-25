#import "Basic";

#import,dir "../modules/memory_utils";
#import,dir "../modules/profiler";

libasm :: #library,no_dll "cpu_frontend";
mov_all_bytes_asm :: (dest: *u8, count: u64) #c_call #foreign libasm;
nop_all_bytes_asm :: (dest: *u8, count: u64) #c_call #foreign libasm;
cmp_all_bytes_asm :: (dest: *u8, count: u64) #c_call #foreign libasm;
dec_all_bytes_asm :: (dest: *u8, count: u64) #c_call #foreign libasm;


Test_Proc :: #type (dest: *u8, count: u64) #c_call;
Test :: struct {
    name: string;
    proc: Test_Proc;
    tester: Repetition_Test;
}
tests := Test.[
    .{ name = "mov_all_bytes_asm", proc = mov_all_bytes_asm },
    .{ name = "nop_all_bytes_asm", proc = nop_all_bytes_asm },
    .{ name = "cmp_all_bytes_asm", proc = cmp_all_bytes_asm },
    .{ name = "dec_all_bytes_asm", proc = dec_all_bytes_asm },
];

main :: () {
    byte_count: u64 : 1024 * 1024 * 1024;
    dest := cast(*u8) alloc(cast(s64) byte_count);
    lock_memory_range(dest, byte_count); // pre-fault all memory pages

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
#import,file "./build_utils.jai";
build :: () {
    if !build_asm("cpu_frontend.asm")  exit(1);
}
#run build();
