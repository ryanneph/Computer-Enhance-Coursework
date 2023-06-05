#import "Basic";
#import "File";
#import "Hash_Table";

#scope_file;
print_debug_output := false;

Parse_State :: struct {
    json_string: string;
    cursor: s64;
    line: s64;
    level: s64;

    string_escape: bool;
    string_buffer: String_Builder;
    latest_string: string;
}

string_char_allowed :: (char: u8, escaped := false) -> bool {
    if escaped {
        if char == {
            case #char "\""; #through;
            case #char "\\"; #through;
            case #char "/";  #through;
            case #char "b";  #through;
            case #char "f";  #through;
            case #char "n";  #through;
            case #char "r";  #through;
            case #char "t";  #through;
            case #char "u";
                return true;

            case;
                return false;
        }
    } else {
        // NOT control characters (excluding space) OR \ OR "
        return !(char <= 31 || char == 127 || char == #char "\\" || char == #char "\"");
    }
}

parse_to_node_tree :: (json_string_input: string) -> (root: *Json_Node) {
    using state: Parse_State;
    state.json_string = json_string_input;
    state.cursor = 0;
    state.line = 1;
    state.level = 0;

    root: *Json_Node;
    node_stack: [..] *Json_Node;

    Push_New_Node :: ($T: Type) -> *T #expand {
        node := New(T);
        if T == {
            case Json_Node_Object;  node.type = .OBJECT;
            case Json_Node_Array;   node.type = .ARRAY;
            case Json_Node_String;  node.type = .STRING;
            case Json_Node_Number;  node.type = .NUMBER;
            case Json_Node_Boolean; node.type = .BOOLEAN;
            case Json_Node_Null;    node.type = .NULL;
            case;
        }

        if !root  root = node;
        array_add(*node_stack, node);

        return node;
    }

    debug_print :: (message: string, args: ..Any) #expand {
        if !print_debug_output  return;
        print(message, ..args);
    }
    debug_print_char :: (char: u8) #expand {
        if !print_debug_output  return;
        print_character(char);
    }

    Parse_Mode :: enum_flags {
        NORMAL;
        STRING;
        OBJECT_NAME;
        OBJECT_VALUE;
    };
    parse_mode := Parse_Mode.NORMAL;

    while cursor < json_string.count {
        char: u8 = json_string[cursor];
        defer cursor += 1;

        if print_debug_output {
            INDENT_SPACE_PER_LEVEL :: 2;
            for i: 1..level * INDENT_SPACE_PER_LEVEL {
                print(" ");
            }
        }

        debug_print("% '", cursor);
        if char >= 32 debug_print_char(char);
        else          debug_print("0x%", char);
        debug_print("': ");

        if parse_mode == .STRING {
            // TODO(ryan): handle escaped (i.e. '\"')
            if char == #char "\"" && !string_escape {
                s := builder_to_string(*string_buffer, do_reset = true);
                debug_print("String (close; value='%')\n", s);
                latest_string = s;

                parent := peek(node_stack);
                assert(parent.type == .OBJECT);

                parse_mode = .NORMAL;
                string_escape = false;
            } else if char == #char "\\" {
                debug_print("begin char escape\n");
                string_escape = true;
            } else {
                if !string_char_allowed(char, string_escape) {
                    print("ERROR: invalid character (0x%; '", char);
                    print_character(char);
                    print("') in string sequence at line %\n", line);
                }

                if string_escape && char == #char "u" {
                    print("UTF-16 hex codepoints aren't supported yet. skipping 4 characters.\n");
                    cursor += 4;
                } else {
                    append(*string_buffer, char);
                    debug_print("append to string\n");
                }

                string_escape = false;
            }

            continue;
        }

        assert(!!(parse_mode & (Parse_Mode.NORMAL)));
        if char == {
            case #char "\n"; #through;
            case #char "\r";
                debug_print("Newline\n");
                line += 1;

            case #char " "; #through;
            case #char "\t";
                debug_print("Whitespace\n");

            case #char ":";
                debug_print("Separator\n");

            case #char "\"";
                debug_print("String ");
                if parse_mode == .STRING {
                    s := builder_to_string(*string_buffer, do_reset = true);
                    debug_print("(close; value='%')\n", s);

                    parent := peek(node_stack);
                    assert(parent.type == .OBJECT);

                    parse_mode = .NORMAL;
                } else {
                    debug_print("(open)\n");
                    parse_mode = .STRING;
                }

            case #char "{";
                level += 1;
                debug_print("Object (begin level=%)\n", level);
                node := Push_New_Node(Json_Node_Object);
            case #char "}";
                debug_print("Object (end level=%)\n", level);
                node := pop(*node_stack);
                assert(node.type == .OBJECT);
                level -= 1;

            case #char "[";
                level += 1;
                debug_print("Array (begin level=%)\n", level);
                node := Push_New_Node(Json_Node_Array);
            case #char "]";
                debug_print("Array (end level=%)\n", level);
                node := pop(*node_stack);
                assert(node.type == .ARRAY);
                level -= 1;

            case #char ",";
                debug_print("Member end\n");

            case;
                debug_print("?\n");
        }
    }
    assert(level == 0);

    return root;
}


#scope_export;
Json_Node_Type :: enum {
    OBJECT  :: 1;
    ARRAY   :: 2;
    STRING  :: 3;
    NUMBER  :: 4;
    BOOLEAN :: 5;
    NULL    :: 6;
}

Json_Node :: struct {
    type: Json_Node_Type;
}
Json_Node_Object :: struct {
    using #as base: Json_Node;
    table: Table(string, *Json_Node);
}
Json_Node_Array :: struct {
    using #as base: Json_Node;
    array: [..] *Json_Node;
}
Json_Node_String :: struct {
    using #as base: Json_Node;
    value: string;
}
Json_Node_Number :: struct {
    using #as base: Json_Node;
    value: float64;
}
Json_Node_Boolean :: struct {
    using #as base: Json_Node;
    value: bool;
}
Json_Node_Null :: struct {
    using #as base: Json_Node;
}

// TODO(ryan): chunked linear allocator for all storage, free all on destruction.
Json_Document :: struct {
    root: *Json_Node;

    // internal use
    _allocator: Allocator;
}

parse_json :: (input_filename: string, debug_output := true) -> (Json_Document, success: bool) {
    print_debug_output = debug_output;

    file_string, success := read_entire_file(input_filename);
    print("FILE CONTENTS\n%\n", file_string);

    root := parse_to_node_tree(file_string);

    doc: Json_Document;
    doc.root = root;
    doc._allocator = context.allocator;

    return doc, true;
}
