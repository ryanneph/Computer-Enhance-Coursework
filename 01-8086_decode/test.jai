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

run_one_test :: (actual_asm_path: string) -> bool {
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
    bytes := file_read_all_as_bytes(temp_encoded_path);
    disassemble(bytes, output_asm_path=temp_our_asm_path);

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

run_tests :: (asm_filenames: []string) {
    DEBUG = false;
    print("RUNNING TESTS:\n");
    for asm_filenames {
        print("Testing '%'\n", it);
        if !run_one_test(it) {
            print("  Test FAILED!\n");
        } else {
            print("  Test PASSED!\n");
        }
        print("\n");
    }
}

