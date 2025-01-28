#import "Basic";
#import "Compiler";
#import "Process";
#import "String";

Library_Type :: enum {
    SHARED;
    STATIC;
}

compile_cpp_lib :: (source_name: string, library_type: Library_Type, output: string = "") -> bool {
    result := true;

    output_name := output;
    if ! output.count {
        output_name = path_strip_extension(source_name);
    }

    args: [..]string;
    array_add(*args, "clang++", "-O2", "-g");

    extension: string;
    if library_type == .SHARED {
        extension = ".so";
        array_add(*args, "--shared", "-fPIC");
    } else if library_type == .STATIC {
        extension = ".a";
        array_add(*args, "-c", "--static");
    }

    full_output := join(output_name, extension,, allocator=temp);
    array_add(*args, "-o", full_output, source_name);
    print("Building % Cpp library % from %\n", library_type, full_output, source_name);
    result := run_command(..args, working_directory=#filepath);

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

compile_module :: (output_name: string, build_file: string = .{}, base_directory: string = "") -> bool {
    result := true;
    if output_name.count {
        // pass build file or default to building from <output_name>.jai
        actual_build_file := build_file;
        if !actual_build_file.count {
            if base_directory.count {
                actual_build_file = tprint("%/%.jai", base_directory, output_name);
            } else {
                actual_build_file = tprint("%.jai", output_name);
            }
        }

        w := compiler_create_workspace(actual_build_file);
        if w {
            print("Starting build for target: %'\n", actual_build_file);
            configure_default_options(w, output_name, base_directory);

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

    print("Receiving compiler messages\n");

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
    prepare_error_count: u64;
    if compile_cpp_lib("reference_haversine.cpp", .SHARED, output="libhaversinecpp") {
        if ! compile_module("main") {
            prepare_error_count += 1;
        }
    } else {
        print("ERROR: failed building libhaversinecpp\n");
        prepare_error_count += 1;
    }

    if compile_cpp_lib("validate_math/intrinsics.cpp", .STATIC, output="validate_math/libintrinsicscpp") {
        if ! compile_module("main", base_directory="validate_math") {
            prepare_error_count += 1;
        }
    } else {
        print("ERROR: failed building libintrinsicscpp\n");
        prepare_error_count += 1;
    }

    compile_error_count := get_compiler_error_count();
    if !prepare_error_count && !compile_error_count {
        print("All done.\n");
        exit_code = 0;
    } else {
        print("ERROR: % errors during prepare, % errors during compile\n", prepare_error_count, compile_error_count);
        exit_code = 1;
    }

    exit(exit_code);
}
#run build();
