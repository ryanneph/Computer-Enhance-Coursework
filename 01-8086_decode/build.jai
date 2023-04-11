#import "Basic";
#import "Compiler";
#import "Sort";
#import "String";

Register_Definition_Parsed :: struct {
    decl:         *Code_Declaration;
    name:         string;
    bit_encoding: u64;

    offset:       u64;
    size:         u64;
}
register_defs: [..]Register_Definition_Parsed;

parse_register_definition :: (decl: *Code_Declaration) -> Register_Definition_Parsed {
    get_literal_u64 :: (node: *Code_Node) -> u64 {
        assert(node.kind == .LITERAL);
        literal := cast(*Code_Literal) node;

        assert(literal.value_type == .NUMBER);
        assert(literal.value_flags & .IS_A_NUMBER != 0);
        assert(literal.value_flags & .FLOAT == 0);
        return literal._u64;
    }
    get_struct_literal_info :: (literal_node: *Code_Node) -> *Code_Struct_Literal_Info {
        assert(literal_node.kind == .LITERAL);
        literal := cast(*Code_Literal)literal_node;

        assert(literal.value_type == .STRUCT);
        return literal.struct_literal_info;
    }
    get_struct_member_index_by_name :: (info: *Type_Info, member_name: string) -> s64 {
        assert(info.type == .STRUCT);
        info_struct := cast(*Type_Info_Struct) info;

        for info_struct.members
            if it.name == member_name  return it_index;

        return -1;
    }
    get_bit_encoding :: inline (decl: *Code_Declaration) -> u64 {
        struct_literal_info := get_struct_literal_info(decl.expression);
        member_index := get_struct_member_index_by_name(decl.type, "bit_encoding");
        assert(member_index >= 0, "member not found");
        return get_literal_u64(struct_literal_info.arguments[member_index]);
    }
    get_offset_size :: inline (decl: *Code_Declaration) -> (offset: u64, size: u64) {
        struct_literal_info := get_struct_literal_info(decl.expression);

        offset_index := get_struct_member_index_by_name(decl.type, "offset");
        assert(offset_index >= 0, "offset not found");
        offset := get_literal_u64(struct_literal_info.arguments[offset_index]);

        size_index := get_struct_member_index_by_name(decl.type, "size");
        assert(size_index  >= 0, "size not found");
        size := get_literal_u64(struct_literal_info.arguments[size_index]);

        return offset, size;
    }

    success, _, register_name := split_from_right(decl.name, "_");
    assert(success, "Register definition has incompatible declaration name (must be like 'anything_ax')!");

    offset, size := get_offset_size(decl);

    parsed: Register_Definition_Parsed;
    parsed.decl         = decl;
    parsed.name         = register_name;
    parsed.bit_encoding = get_bit_encoding(decl);
    parsed.offset       = offset;
    parsed.size         = size;

    return parsed;
}

add_generated_build_string :: (s: string, workspace: s64) {
    array_add(*builder_generated_strings, s);

    print(#string END
Generated compile-time string:
===============<start>===============
%
================<end>================

END, s);
}

generate_once_already_done := false;
builder_generated_strings: [..]string;
generate_register_tables :: (workspace: s64) {
    if generate_once_already_done  return;
    generate_once_already_done = true;

    // sort register definitions (in-place) by bit encoding
    sorted_register_defs := quick_sort(register_defs,
        (a, b) => (cast(s32) a.bit_encoding) - (cast(s32) b.bit_encoding) );

    generated_string: string;
    name_table_builder: String_Builder;
    region_table_builder: String_Builder;

    for sorted_register_defs {
        if it_index > 0 && it_index % 16 == 0
            append(*name_table_builder, "\n");
        print_to_builder(*name_table_builder, "\"%\",", it.name);
        print_to_builder(*region_table_builder, "\n    .{ offset=%, size=% }, // %",
            formatInt(it.offset, minimum_digits=2), formatInt(it.size, minimum_digits=2), it.name);
    }

    generated_string = tprint(REGISTER_NAME_TABLE_TEMPL,
        sorted_register_defs.count, builder_to_string(*name_table_builder));
    add_generated_build_string(generated_string, workspace);

    generated_string = tprint(REGISTER_REGION_TABLE_TEMPL,
        sorted_register_defs.count, builder_to_string(*region_table_builder));
    add_generated_build_string(generated_string, workspace);
}

// %1: register count
// %2: flat array of register name string entries, sorted by bit_encoding
REGISTER_NAME_TABLE_TEMPL :: #string END
register_name_table: [%1]string : .[
    %2
];
END

// %1: register count
// %2: flat array of Register_Region entries, sorted by bit_encoding
REGISTER_REGION_TABLE_TEMPL :: #string END
register_region_table: [%1]Register_Region : .[%2
];
END

builder_message_loop :: () {
    is_struct_type :: (decl: *Code_Declaration, type_name: string) -> bool {
        if decl.type.type != .STRUCT  return false;
        info_struct := cast(*Type_Info_Struct) decl.type;
        return info_struct.name == type_name;
    }

    while true {
        msg := compiler_wait_for_message();

        if msg.kind == {
            case .TYPECHECKED;
                typechecked := cast(*Message_Typechecked) msg;
                for typechecked.declarations {
                    decl := it.expression;

                    // only consider "our" types
                    if decl.enclosing_load.enclosing_import.module_type != .MAIN_PROGRAM
                        continue;

                    if is_struct_type(decl, "Register_Definition")
                        array_add(*register_defs,  parse_register_definition(decl));
                }

            case .PHASE;
                phase := cast(*Message_Phase) msg;
                if phase.phase == .TYPECHECKED_ALL_WE_CAN {
                    generate_register_tables(msg.workspace);
                }

            case .COMPLETE;
                break;
            case; // ignore unhandled messages
        }
    }
}

build :: () {
    // Create a hermetic workspace for operating on compile-time-only types and
    // generating strings to inject during main program compilation.
    builder_workspace := compiler_create_workspace("builder");
    if !builder_workspace {
        print("Builder workspace creation failed!\n");
        return;
    }

    builder_target_options := get_build_options(builder_workspace);
    builder_target_options.output_type = .NO_OUTPUT;
    set_build_options(builder_target_options, builder_workspace);

    // the builder should not generate any output object/executable
    compiler_begin_intercept(builder_workspace);
    add_build_file("builder_defs.jai", builder_workspace);
    builder_message_loop();
    compiler_end_intercept(builder_workspace);


    // Now build main program with static files and builder-generated strings
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
    for builder_generated_strings
        add_build_string(it, w);


    // This "Default" metaprogram should not generate any output executable:
    set_build_options_dc(.{do_output=false});
}

#run build();
