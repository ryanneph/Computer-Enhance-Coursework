#import "Basic";
#import "Compiler";

build :: () {
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

    set_build_options(options, w);

    // Compilation begins once we add a build file, so set_build_options must come before
    print("Building target '%'\n", options.output_executable_name);
    add_build_file("main.jai", w);
}
#run build();
