#import "File";
#import "File_Utilities";
#import "String";

path_join :: #bake_arguments join(separator="/");

assemble :: (asm_path: string, output_path: string) -> bool {
    args: [..]string;
    array_add(*args, "nasm", "-o", output_path, asm_path);
    result, output_string, error_string := run_command(..args, capture_and_return_output=true);
    if result.type != .EXITED {
        print("Process failed to execute with reason: %", result.type);
        return false;
    } else if (result.exit_code != 0) {
        print("Error in command '%':\n%", join(..args, " "), error_string);
        return false;
    }

    return true;
}

run_one_decode_test :: (test_file: Test_File) -> bool {
    actual_asm_path := test_file.filename;

    temp_dirname := "test_tmp";
    asm_filename := path_filename(actual_asm_path);

    temp_asm_path := path_join(temp_dirname, asm_filename);
    temp_encoded_path := path_strip_extension(temp_asm_path);

    temp_our_asm_path := join(temp_encoded_path, "_ours.asm");
    temp_our_encoded_path := join(temp_encoded_path, "_ours");

    // make temp dir
    make_directory_if_it_does_not_exist(temp_dirname);

    // copy ground truth (GT) asm
    copy_file(actual_asm_path, temp_asm_path);

    // assemble GT asm to machine code
    if DEBUG  print("Assembling input '%' to '%'\n", temp_asm_path, temp_encoded_path);
    if !assemble(temp_asm_path, temp_encoded_path) {
        print("Error assembling '%'\n", temp_asm_path);
        return false;
    }

    // run our disassembler
    if DEBUG  print("Disassembling '%' to '%':\n", temp_encoded_path, temp_our_asm_path);
    disassemble_file(temp_encoded_path, output_asm_path=temp_our_asm_path);

    // assemble our disassembled asm to machine code
    if DEBUG  print("Assembling input '%' to '%'\n", temp_our_asm_path, temp_our_encoded_path);
    if !assemble(temp_our_asm_path, temp_our_encoded_path) {
        print("Error assembling '%'\n", temp_our_asm_path);
        return false;
    }

    // binary compare assembled GT vs ours
    encoded_bytes := file_read_all_as_bytes(temp_encoded_path);
    our_encoded_bytes := file_read_all_as_bytes(temp_our_encoded_path);
    defer free(encoded_bytes.data);
    defer free(our_encoded_bytes.data);

    if encoded_bytes.count != our_encoded_bytes.count ||
        memcmp(encoded_bytes.data, our_encoded_bytes.data, encoded_bytes.count) {
        print("Encoded instructions do not match!\n");
        return false;
    }
    return true;
}

run_one_exec_test :: (test_file: Test_File) -> bool {
    return false;
}

run_one_test :: (test_file: Test_File) -> (fail_count: s64) {
    fail_count := 0;

    run_test :: (name: string, enabled: bool, proc: #type (Test_File) -> bool) #expand {
        if !enabled
            return;
        success := proc(test_file);
        if !success {
            print("  -- % test failed\n", name);
            fail_count += 1;
        }
    }

    run_test("decode", test_file.decode, run_one_decode_test);
    run_test("exec",   test_file.exec,   run_one_exec_test);

    return fail_count;
}

TEST_PATH_PREFIX :: "../cmuratori-computer_enhance/perfaware/part1/";
Test_File :: struct {
    filename: string;
    decode:   bool;
    exec:     bool;
}
test_files :: Test_File.[
    .{ "listing_0037_single_register_mov.asm",  true,  false, },
    .{ "listing_0038_many_register_mov.asm",    true,  false, },
    .{ "listing_0039_more_movs.asm",            true,  false, },
    .{ "listing_0040_challenge_movs.asm",       true,  false, },
    .{ "listing_0041_add_sub_cmp_jnz.asm",      true,  false, },
    .{ "listing_0042_completionist_decode.asm", true,  false, },
    .{ "listing_0043_immediate_movs.asm",       true,  true, },
];

run_tests :: () {
    DEBUG = false;
    print("RUNNING TESTS:\n");

    total_fail_count := 0;
    for test_files {
        test_file := it;
        test_file.filename = tprint("%/%", TEST_PATH_PREFIX, it.filename);

        print("Testing '%'\n", test_file.filename);
        fail_count := run_one_test(test_file);
        if fail_count {
            print("  % tests FAILED!\n", fail_count);
            total_fail_count += fail_count;
        } else {
            print("  All tests PASSED!\n");
        }
        print("\n");
    }

    if total_fail_count
        print("TEST RESULTS: % tests FAILED!\n", total_fail_count);
    else
        print("TEST_RESULTS: all tests PASSED!\n");
}

