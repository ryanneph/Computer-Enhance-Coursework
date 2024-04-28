#import "Basic";

#import,dir "../modules/memory_utils";
#import,dir "../modules/profiler";

libasm :: #library,no_dll "execution_ports";
read_8x1 :: (dest: *u8, count: u64) #c_call #foreign libasm;
read_8x2 :: (dest: *u8, count: u64) #c_call #foreign libasm;
read_8x3 :: (dest: *u8, count: u64) #c_call #foreign libasm;
read_8x4 :: (dest: *u8, count: u64) #c_call #foreign libasm;
read_1x16 :: (dest: *u8, count: u64) #c_call #foreign libasm;

write_8x1 :: (dest: *u8, count: u64) #c_call #foreign libasm;
write_8x2 :: (dest: *u8, count: u64) #c_call #foreign libasm;
write_8x3 :: (dest: *u8, count: u64) #c_call #foreign libasm;
write_8x4 :: (dest: *u8, count: u64) #c_call #foreign libasm;
write_1x16 :: (dest: *u8, count: u64) #c_call #foreign libasm;


Test_Proc :: #type (dest: *u8, count: u64) #c_call;
Test :: struct {
    name: string;
    proc: Test_Proc;
    tester: Repetition_Test;
}
tests := Test.[
    .{ name = "read_8x1", proc = read_8x1 },
    .{ name = "read_8x2", proc = read_8x2 },
    .{ name = "read_8x3", proc = read_8x3 },
    .{ name = "read_8x4", proc = read_8x4 },
    .{ name = "read_1x16", proc = read_1x16 },

    .{ name = "write_8x1", proc = write_8x1 },
    .{ name = "write_8x2", proc = write_8x2 },
    .{ name = "write_8x3", proc = write_8x3 },
    .{ name = "write_8x4", proc = write_8x4 },
    .{ name = "write_1x16", proc = write_1x16 },
];

main :: () {
    byte_count: u64 : 1024 * 1024 * 1024;
    dest := cast(*u8) alloc(cast(s64) byte_count);
    lock_memory_range(dest, byte_count); // pre-fault all memory pages

    for *test: tests {
        test.tester = repetition_test_init(test.name);
        while repetition_test_is_running(*test.tester) {
            repetition_test_start(*test.tester);
            test.proc(dest, byte_count);
            repetition_test_stop(*test.tester, byte_count);
        }
    }
}


#import,file "./build_utils.jai";
build :: () {
    if !build_asm("execution_ports.asm")  exit(1);
}
#run build();
