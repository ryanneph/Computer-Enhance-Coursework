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

flags_equal :: inline (state: *Processor_State, flags: Flag) -> bool {
    return (load_register(state, .FLAG) & cast(u16) flags) == cast(u16) flags;
}

processor_state_equal :: (state: *Processor_State, expected: *Processor_State) -> bool {
    equal := true;
    equal &= !memcmp(expected.register_memory.data, state.register_memory.data, size_of(type_of(expected.register_memory)));
    equal &= state.ip == expected.ip;
    return equal;
}

validate_immediate_movs :: (state: *Processor_State) -> bool {
    expected: Processor_State;
    expected.ip = state.ip;
    store_register(*expected, .AX, 1);
    store_register(*expected, .BX, 2);
    store_register(*expected, .CX, 3);
    store_register(*expected, .DX, 4);
    store_register(*expected, .SP, 5);
    store_register(*expected, .BP, 6);
    store_register(*expected, .SI, 7);
    store_register(*expected, .DI, 8);

    return processor_state_equal(*expected, state);
}

validate_register_movs :: (state: *Processor_State) -> bool {
    expected: Processor_State;
    expected.ip = state.ip;
    store_register(*expected, .AX, 4);
    store_register(*expected, .BX, 3);
    store_register(*expected, .CX, 2);
    store_register(*expected, .DX, 1);
    store_register(*expected, .SP, 1);
    store_register(*expected, .BP, 2);
    store_register(*expected, .SI, 3);
    store_register(*expected, .DI, 4);

    return processor_state_equal(*expected, state);
}

validate_challenge_register_movs :: (state: *Processor_State) -> bool {
    expected: Processor_State;
    expected.ip = state.ip;
    store_register(*expected, .AX, 0x4411);
    store_register(*expected, .BX, 0x3344);
    store_register(*expected, .CX, 0x6677);
    store_register(*expected, .DX, 0x7788);
    store_register(*expected, .SP, 0x4411);
    store_register(*expected, .BP, 0x3344);
    store_register(*expected, .SI, 0x6677);
    store_register(*expected, .DI, 0x7788);
    store_register(*expected, .ES, 0x6677);
    store_register(*expected, .SS, 0x4411);
    store_register(*expected, .DS, 0x3344);

    return processor_state_equal(*expected, state);
}

validate_add_sub_cmp :: (state: *Processor_State) -> bool {
    expected: Processor_State;
    expected.ip = state.ip;
    store_register(*expected, .BX, 0xE102);
    store_register(*expected, .CX, 0x0F01);
    store_register(*expected, .SP, 0x03E6);
    store_register(*expected, .BP, 0x0000);

    flags := Flag.PARITY | .ZERO;
    store_flags(*expected, flags);

    return processor_state_equal(*expected, state);
}

validate_challenge_flags :: (state: *Processor_State) -> bool {
    expected: Processor_State;
    expected.ip = state.ip;
    store_register(*expected, .BX, 0x9CA5);
    store_register(*expected, .DX, 0x000A);
    store_register(*expected, .SP, 0x0063);
    store_register(*expected, .BP, 0x0062);

    flags := Flag.CARRY | .PARITY | .AUX_CARRY | .SIGN;
    store_flags(*expected, flags);

    return processor_state_equal(*expected, state);
}

validate_ip_register :: (state: *Processor_State) -> bool {
    expected: Processor_State;
    expected.ip = 0x000E;
    store_register(*expected, .BX, 0x07D0);
    store_register(*expected, .CX, 0xFCE0);

    flags := Flag.CARRY | .SIGN | .AUX_CARRY; // BUG(ryanneph): no AUX_CARRY
    store_flags(*expected, flags);

    return processor_state_equal(*expected, state);
}

validate_conditional_jumps :: (state: *Processor_State) -> bool {
    expected: Processor_State;
    expected.ip = 0x000E;
    store_register(*expected, .BX, 0x0406);

    flags := Flag.PARITY | .ZERO;
    store_flags(*expected, flags);

    return processor_state_equal(*expected, state);
}

validate_challenge_jumps :: (state: *Processor_State) -> bool {
    expected: Processor_State;
    expected.ip = 0x001C;
    store_register(*expected, .AX, 0x000D);
    store_register(*expected, .BX, 0xFFFB);

    flags := Flag.CARRY | .AUX_CARRY | .SIGN;
    store_flags(*expected, flags);

    return processor_state_equal(*expected, state);
}

validate_memory_mov :: (state: *Processor_State) -> bool {
    expected: Processor_State;
    expected.ip = 0x0030;
    store_register(*expected, .BX, 0x0001);
    store_register(*expected, .CX, 0x0002);
    store_register(*expected, .DX, 0x000A);
    store_register(*expected, .BP, 0x0004);

    return processor_state_equal(*expected, state);
}

validate_memory_add_loop :: (state: *Processor_State) -> bool {
    expected: Processor_State;
    expected.ip = 0x0023;
    store_register(*expected, .BX, 0x0006);
    store_register(*expected, .CX, 0x0004);
    store_register(*expected, .DX, 0x0006);
    store_register(*expected, .BP, 0x03E8);
    store_register(*expected, .SI, 0x0006);

    flags := Flag.PARITY | .ZERO;
    store_flags(*expected, flags);

    return processor_state_equal(*expected, state);
}

validate_add_loop_challenge :: (state: *Processor_State) -> bool {
    expected: Processor_State;
    expected.ip = 0x0021;
    store_register(*expected, .BX, 0x0006);
    store_register(*expected, .DX, 0x0006);
    store_register(*expected, .BP, 0x03E6);

    flags := Flag.PARITY | .ZERO;
    store_flags(*expected, flags);

    return processor_state_equal(*expected, state);
}

validate_draw_rectangle :: (state: *Processor_State) -> bool {
    expected: Processor_State;
    expected.ip = 0x0026;
    store_register(*expected, .CX, 0x0040);
    store_register(*expected, .DX, 0x0040);
    store_register(*expected, .BP, 0x4100);

    flags := Flag.PARITY | .ZERO | .AUX_CARRY; // BUG(ryanneph): no AUX_CARRY
    store_flags(*expected, flags);

    return processor_state_equal(*expected, state);
}

validate_challenge_rectangle :: (state: *Processor_State) -> bool {
    expected: Processor_State;
    expected.ip = 0x0044;
    store_register(*expected, .BX, 0x4004);
    store_register(*expected, .BP, 0x02FC);

    return processor_state_equal(*expected, state);
}

run_one_exec_test :: (asm_filename: string, payload: Execute_Payload) -> bool {
    encoded_filename := path_join(TEST_TEMP_DIR, path_basename(asm_filename));
    assemble(asm_filename, encoded_filename);

    inst_memory: Memory_Region = file_read_all_as_bytes(encoded_filename);

    state: Processor_State;
    execute_from_ip(*state, inst_memory);

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
    add_test("listing_0046_add_sub_cmp.asm",             decode_subtest, make_exec_subtest(validate_add_sub_cmp));
    add_test("listing_0047_challenge_flags.asm",         decode_subtest, make_exec_subtest(validate_challenge_flags));
    add_test("listing_0048_ip_register.asm",             decode_subtest, make_exec_subtest(validate_ip_register));
    add_test("listing_0049_conditional_jumps.asm",       decode_subtest, make_exec_subtest(validate_conditional_jumps));
    add_test("listing_0050_challenge_jumps.asm",         decode_subtest, make_exec_subtest(validate_challenge_jumps));
    add_test("listing_0051_memory_mov.asm",              decode_subtest, make_exec_subtest(validate_memory_mov));
    add_test("listing_0052_memory_add_loop.asm",         decode_subtest, make_exec_subtest(validate_memory_add_loop));
    add_test("listing_0053_add_loop_challenge.asm",      decode_subtest, make_exec_subtest(validate_add_loop_challenge));
    add_test("listing_0054_draw_rectangle.asm",          decode_subtest, make_exec_subtest(validate_draw_rectangle));
    add_test("listing_0055_challenge_rectangle.asm",     decode_subtest, make_exec_subtest(validate_challenge_rectangle));

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

