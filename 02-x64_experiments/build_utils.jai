#import "Basic";
#import "Compiler";
#import "Process";
#import "String";

build_asm :: (input: string, output := "") -> bool {
    // build asm into a static libary
    output_filename := tprint("%.a", path_strip_extension(input));

    print("Building asm library: % ... ", output_filename);
    args := string.["nasm", "-g", "-f", "elf64", "-o", output_filename, input];
    result, stdout, stderr := run_command(..args, capture_and_return_output=true);
    if result.type == .EXITED && result.exit_code == 0 {
        print("Success\n");
        return true;
    } else {
        print("Failed\n");
        print("Error output:\n%", stderr);
        return false;
    }
    // UNREACHABLE
}

build_self :: (output_name: string, output_dir := "./") {
    // This "Default" metaprogram should not generate any output executable
    set_build_options_dc(.{do_output=false});

    // Create a separate workspace to build the actual program
    w := compiler_create_workspace(output_name);
    options := get_build_options(w);
    options.output_executable_name = output_name;
    if output_dir  options.output_path = output_dir;

    import_paths: [..]string;
    array_add(*import_paths, "../modules");
    array_add(*import_paths, ..options.import_path);
    options.import_path = import_paths;
    print("%\n", import_paths);

    set_build_options(options, w);

    // Compilation begins once we add a build file, so set_build_options must come before
    add_build_file("branch_predictor.jai", w);
}
