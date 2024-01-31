#import "Basic";

libasm :: #library,no_dll "cpu_frontend";
mov_all_bytes_asm :: (dest: *u8, count: u64) #c_call #foreign libasm;
nop_all_bytes_asm :: (dest: *u8, count: u64) #c_call #foreign libasm;
cmp_all_bytes_asm :: (dest: *u8, count: u64) #c_call #foreign libasm;
dec_all_bytes_asm :: (dest: *u8, count: u64) #c_call #foreign libasm;

main :: () {
    dest: [512]u8;
    mov_all_bytes_asm(cast(*u8) dest.data, cast(u64) dest.count);
    for dest  print("%: %\n", it_index, it);

    nop_all_bytes_asm(cast(*u8) dest.data, cast(u64) dest.count);
    cmp_all_bytes_asm(cast(*u8) dest.data, cast(u64) dest.count);
    dec_all_bytes_asm(cast(*u8) dest.data, cast(u64) dest.count);
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
