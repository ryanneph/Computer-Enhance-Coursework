#import "Basic";

#import,dir "../modules/memory_utils";
#import,dir "../modules/profiler";

libasm :: #library,no_dll "simd_mov";
read_4x2 :: (dest: *u8, count: u64) #c_call #foreign libasm;
read_8x2 :: (dest: *u8, count: u64) #c_call #foreign libasm;
read_16x2 :: (dest: *u8, count: u64) #c_call #foreign libasm;
read_32x2 :: (dest: *u8, count: u64) #c_call #foreign libasm;

read_4x3 :: (dest: *u8, count: u64) #c_call #foreign libasm;
read_8x3 :: (dest: *u8, count: u64) #c_call #foreign libasm;
read_16x3 :: (dest: *u8, count: u64) #c_call #foreign libasm;
read_32x3 :: (dest: *u8, count: u64) #c_call #foreign libasm;

read_4x4 :: (dest: *u8, count: u64) #c_call #foreign libasm;
read_8x4 :: (dest: *u8, count: u64) #c_call #foreign libasm;
read_16x4 :: (dest: *u8, count: u64) #c_call #foreign libasm;
read_32x4 :: (dest: *u8, count: u64) #c_call #foreign libasm;

read_64x2 :: (dest: *u8, count: u64) #c_call #foreign libasm;
read_64x3 :: (dest: *u8, count: u64) #c_call #foreign libasm;
read_64x4 :: (dest: *u8, count: u64) #c_call #foreign libasm;


Test_Proc :: #type (dest: *u8, count: u64) #c_call;
Test :: struct {
    name: string;
    proc: Test_Proc;
    tester: Repetition_Test;
}
tests := Test.[
    .{ name = "read_4x2", proc = read_4x2 },
    .{ name = "read_4x3", proc = read_4x3 },
    .{ name = "read_4x4", proc = read_4x4 },

    .{ name = "read_8x2", proc = read_8x2 },
    .{ name = "read_8x3", proc = read_8x3 },
    .{ name = "read_8x4", proc = read_8x4 },

    .{ name = "read_16x2", proc = read_16x2 },
    .{ name = "read_16x3", proc = read_16x3 },
    .{ name = "read_16x4", proc = read_16x4 },

    .{ name = "read_32x2", proc = read_32x2 },
    .{ name = "read_32x3", proc = read_32x3 },
    .{ name = "read_32x4", proc = read_32x4 },

    // these will crash if AVX512 is not supported
    // .{ name = "read_64x2", proc = read_64x2 },
    // .{ name = "read_64x3", proc = read_64x3 },
    // .{ name = "read_64x4", proc = read_64x4 },
];

main :: () {
    byte_count: u64 : 1024 * 1024 * 1024;
    dest := cast(*u8) alloc(cast(s64) byte_count);
    lock_memory_range(dest, byte_count); // pre-fault all memory pages

    for *test: tests {
        test.tester = repetition_test_init(max_iters=200);
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
    if !build_asm("simd_mov.asm")  exit(1);
}
#run build();
