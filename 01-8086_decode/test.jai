#scope_file

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

run_one_decode_test :: (actual_asm_path: string) -> bool {
    temp_dirname := TEST_TEMP_DIR;
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
    if DEBUG_TEST  print("Assembling input '%' to '%'\n", temp_asm_path, temp_encoded_path);
    if !assemble(temp_asm_path, temp_encoded_path) {
        print("Error assembling '%'\n", temp_asm_path);
        return false;
    }

    // run our disassembler
    if DEBUG_TEST  print("Disassembling '%' to '%':\n", temp_encoded_path, temp_our_asm_path);
    disassemble_file(temp_encoded_path, output_asm_path=temp_our_asm_path);

    // assemble our disassembled asm to machine code
    if DEBUG_TEST  print("Assembling input '%' to '%'\n", temp_our_asm_path, temp_our_encoded_path);
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

validate_immediate_movs :: (state: *Processor_State) -> bool {
    success := true;
    success &= load_register(state, .AX) == 1;
    success &= load_register(state, .BX) == 2;
    success &= load_register(state, .CX) == 3;
    success &= load_register(state, .DX) == 4;
    success &= load_register(state, .SP) == 5;
    success &= load_register(state, .BP) == 6;
    success &= load_register(state, .SI) == 7;
    success &= load_register(state, .DI) == 8;

    return success;
}

validate_register_movs :: (state: *Processor_State) -> bool {
    success := true;
    success &= load_register(state, .AX) == 4;
    success &= load_register(state, .BX) == 3;
    success &= load_register(state, .CX) == 2;
    success &= load_register(state, .DX) == 1;
    success &= load_register(state, .SP) == 1;
    success &= load_register(state, .BP) == 2;
    success &= load_register(state, .SI) == 3;
    success &= load_register(state, .DI) == 4;

    return success;
}

validate_challenge_register_movs :: (state: *Processor_State) -> bool {
    success := true;
    success &= load_register(state, .AX) == 0x4411;
    success &= load_register(state, .BX) == 0x3344;
    success &= load_register(state, .CX) == 0x6677;
    success &= load_register(state, .DX) == 0x7788;
    success &= load_register(state, .SP) == 0x4411;
    success &= load_register(state, .BP) == 0x3344;
    success &= load_register(state, .SI) == 0x6677;
    success &= load_register(state, .DI) == 0x7788;
    success &= load_register(state, .ES) == 0x6677;
    success &= load_register(state, .SS) == 0x4411;
    success &= load_register(state, .DS) == 0x3344;

    return success;
}

run_one_exec_test :: (asm_filename: string, payload: Execute_Payload) -> bool {
    encoded_filename := path_join(TEST_TEMP_DIR, path_basename(asm_filename));
    assemble(asm_filename, encoded_filename);

    bytes: []u8 = file_read_all_as_bytes(encoded_filename);

    state: Processor_State;
    offset := 0;
    while offset < bytes.count {
        head := bytes.data + offset;
        inst, advance := decode_once(head);
        offset += advance;

        exec_instruction(*state, inst);
    }

    return payload.validate_proc(*state);
}

run_one_test :: (test: Test) -> (fail_count: s64) {
    fail_count := 0;

    for subtest: test.subtests {
        success: bool;
        if #complete subtest.type == {
            case .DECODE;
                success = run_one_decode_test(test.filename);
            case .EXECUTE;
                success = run_one_exec_test(test.filename, subtest.execute);
        }

        if !success {
            print("  -- % test failed\n", subtest.type);
            fail_count += 1;
        }
    }

    return fail_count;
}

Test :: struct {
    filename: string;
    subtests: [..]Subtest;
}
Subtest_Type :: enum {
    DECODE;
    EXECUTE;
}
Validate_Processor_State_Proc :: #type (*Processor_State) -> bool;
Execute_Payload :: struct {
    validate_proc: Validate_Processor_State_Proc;
}
Subtest :: struct {
    type: Subtest_Type;
    using payload: union {
        execute: Execute_Payload;
    };
}

TEST_TEMP_DIR :: "test_temp";
TEST_PATH_PREFIX :: "../cmuratori-computer_enhance/perfaware/part1";
init_tests :: () -> []Test {
    add_test :: (basename: string, subtests: .. Subtest) #expand {
        test: Test;
        test.filename = sprint("%/%", TEST_PATH_PREFIX, basename);

        for subtests
            array_add(*test.subtests, it);

        array_add(*tests, test);
    }
    make_exec_subtest :: (proc: Validate_Processor_State_Proc) -> Subtest {
        subtest: Subtest;
        subtest.type = .EXECUTE;
        subtest.execute.validate_proc = proc;
        return subtest;
    }
    decode_subtest :: Subtest.{ type = .DECODE };

    tests: [..]Test;
    add_test("listing_0037_single_register_mov.asm",     decode_subtest);
    add_test("listing_0038_many_register_mov.asm",       decode_subtest);
    add_test("listing_0039_more_movs.asm",               decode_subtest);
    add_test("listing_0040_challenge_movs.asm",          decode_subtest);
    add_test("listing_0041_add_sub_cmp_jnz.asm",         decode_subtest);
    add_test("listing_0042_completionist_decode.asm",    decode_subtest);
    add_test("listing_0043_immediate_movs.asm",          decode_subtest, make_exec_subtest(validate_immediate_movs));
    add_test("listing_0044_register_movs.asm",           decode_subtest, make_exec_subtest(validate_register_movs));
    add_test("listing_0045_challenge_register_movs.asm", decode_subtest, make_exec_subtest(validate_challenge_register_movs));

    return tests;
}


#scope_export

run_tests :: () {
    DEBUG_DECODE = false;
    DEBUG_EXEC   = false;

    tests := init_tests();

    print("RUNNING TESTS:\n");

    total_fail_count := 0;
    for test: tests {
        print("Testing '%'\n", test.filename);
        fail_count := run_one_test(test);
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
        print("TEST RESULTS: all tests PASSED!\n");
}

