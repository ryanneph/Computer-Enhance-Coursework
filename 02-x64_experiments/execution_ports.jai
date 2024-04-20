#import "Basic";

#import,dir "../modules/memory_utils";
#import,dir "../modules/profiler";

libasm :: #library,no_dll "execution_ports";
read_x1 :: (dest: *u8, count: u64) #c_call #foreign libasm;
read_x2 :: (dest: *u8, count: u64) #c_call #foreign libasm;
read_x3 :: (dest: *u8, count: u64) #c_call #foreign libasm;
read_x4 :: (dest: *u8, count: u64) #c_call #foreign libasm;


Test_Proc :: #type (dest: *u8, count: u64) #c_call;
Test :: struct {
    name: string;
    proc: Test_Proc;
    tester: Repetition_Test;
}
tests := Test.[
    .{ name = "read_x1", proc = read_x1 },
    .{ name = "read_x2", proc = read_x2 },
    .{ name = "read_x3", proc = read_x3 },
    .{ name = "read_x4", proc = read_x4 },
];

main :: () {
    byte_count: u64 : 1024 * 1024 * 1024;
    dest := cast(*u8) alloc(cast(s64) byte_count);
    lock_memory_range(dest, byte_count); // pre-fault all memory pages

    for *test: tests {
        test.tester = repetition_test_init(max_iters=100);
    }

    for test: tests {
        print("Running test '%' from iter=%\n", test.name, test.tester.iters);
        print("------------------------------------------------------------\n");
        while repetition_test_is_running(*test.tester) {
            repetition_test_start(*test.tester);
            test.proc(dest, byte_count);
            repetition_test_stop(*test.tester, byte_count);
        }
        print("------------------------------------------------------------\n\n");
    }
}


#import,file "./build_utils.jai";
build :: () {
    if !build_asm("execution_ports.asm")  exit(1);
}
#run build();
