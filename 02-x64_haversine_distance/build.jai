#import "Basic";
#import "Compiler";

build :: () {
    w := compiler_create_workspace("default");
    if !w {
        print("Main program workspace creation failed!\n");
        return;
    }

    target_options := get_build_options(w);
    target_options.output_executable_name = "main";
    set_build_options(target_options, w);

    print("Building target '%'\n", target_options.output_executable_name);
    add_build_file("main.jai", w);

    // This "Default" metaprogram should not generate any output executable:
    set_build_options_dc(.{do_output=false});
}

#run build();
