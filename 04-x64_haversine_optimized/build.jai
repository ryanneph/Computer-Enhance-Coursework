#import "Basic";
#import "Compiler";
#import "Process";

compile_cpp_lib :: () {
    args := string.[
        "clang++", "-fPIC", "--shared", "-O2",
        "-o", "libhaversinecpp.so",
        "reference_haversine.cpp",
    ];
    result := run_command(..args, );
    // run_command(..args, working_directory := "", capture_and_return_output := false, print_captured_output := false, timeout_ms := -1, arg_quoting := Process_Argument_Quoting.QUOTE_IF_NEEDED) -> (process_result: Process_Result, output_string := "", error_string := "", timeout_reached := false) {
;
}

build :: () {
    compile_cpp_lib();

    // This "Default" metaprogram should not generate any output executable
    set_build_options_dc(.{do_output=false});

    // Create a separate workspace to build the actual program
    w := compiler_create_workspace("main");
    if !w {
        print("Main program workspace creation failed!\n");
        return;
    }
    options := get_build_options(w);
    options.output_executable_name = "main";

    import_paths: [..]string;
    array_add(*import_paths, "../modules");
    array_add(*import_paths, ..options.import_path);
    options.import_path = import_paths;

    set_optimization(*options, .OPTIMIZED, preserve_debug_info=true);
    set_build_options(options, w);

    // Compilation begins once we add a build file, so set_build_options must come before
    print("Building target '%'\n", options.output_executable_name);
    add_build_file("main.jai", w);
}
#run build();
