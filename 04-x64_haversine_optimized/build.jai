#import "Basic";
#import "Compiler";
#import "Process";

compile_cpp_lib :: () -> bool {
    args :: string.[
        "clang++", "-fPIC", "--shared", "-O2", "-g",
        "-o", "libhaversinecpp.so",
        "reference_haversine.cpp",
    ];
    result := run_command(..args);

    return result.type == .EXITED && result.exit_code == 0;
}

configure_default_options :: (w: Workspace, output_name: string, output_directory: string = "") {
    options := get_build_options(w);
    if output_directory.count {
        options.output_path = output_directory;
    }
    options.output_executable_name = output_name;

    import_paths: [..]string;
    array_add(*import_paths, "../modules");
    array_add(*import_paths, ..options.import_path);
    options.import_path = import_paths;

    set_optimization(*options, .OPTIMIZED, preserve_debug_info=true);
    set_build_options(options, w);
}

compile_module :: (output_name: string, build_file: string = .{}, output_directory: string = "") -> bool {
    result := true;
    if output_name.count {
        // pass build file or default to building from <output_name>.jai
        actual_build_file := build_file;
        if !actual_build_file.count {
            if output_directory.count {
                actual_build_file = tprint("%/%.jai", output_directory, output_name);
            } else {
                actual_build_file = tprint("%.jai", output_name);
            }
        }

        w := compiler_create_workspace(actual_build_file);
        if w {
            print("Starting build for target: %'\n", actual_build_file);
            configure_default_options(w, output_name, output_directory);

            compiler_begin_intercept(w);
            add_build_file(actual_build_file, w);
            array_add(*workspaces, w);

            result = true;
        } else {
            print("workspace creation failed for %\n", output_name);
            result = false;
        }
    } else {
        print("ERROR: % expects non-empty output_name.\n", #procedure_name());
        result = false;
    }

    return result;
}

get_compiler_error_count :: () -> u64 {
    error_count: u64;
    complete_count: u64;

    message: Message;
    while complete_count < cast(u64, workspaces.count) {
        // intercept messages for all workspaces
        message = compiler_wait_for_message();
        if message.kind == .COMPLETE {
            complete_count += 1;
        }
        if message.kind == .ERROR {
            error_count += 1;
        }
    }

    return error_count;
}

workspaces: [..]Workspace;
build :: () {
    set_build_options_dc(.{do_output=false});

    exit_code: s32 = 1;
    if compile_cpp_lib() {
        if compile_module("main") {
            if compile_module("main", output_directory="validate_math") {
                error_count := get_compiler_error_count();
                if !error_count {
                    print("All done.\n");
                    exit_code = 0;
                } else {
                    print("Encountered % errors while compiling\n", error_count);
                    exit_code = 1;
                }
            } else {
                print("Failed building main program\n");
            }
        } else {
            print("Failed building main program\n");
        }
    } else {
        print("Failed building libhaversinecpp\n");
    }

    exit(exit_code);
}
#run build();
