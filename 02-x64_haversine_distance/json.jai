#import "Basic";
#import "File";
#import "Hash_Table";
#import "String";

#scope_file;
print_debug_output := false;
debug_print :: (message: string, args: ..Any) {
    if !print_debug_output  return;
    print(message, ..args);
}
debug_print_char :: (char: u8) {
    if !print_debug_output  return;
    print_character(char);
}

#if false {
    validate_string :: (char: u8, escaped := false) -> bool {
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
}

//
// Lexing
//
Json_Token_Type :: enum {
    OBJECT_BEGIN;
    OBJECT_END;
    OBJECT_NAME_VALUE_SEPARATOR;

    ARRAY_BEGIN;
    ARRAY_END;

    MEMBER_SEPARATOR;
    WHITESPACE;

    // base types
    STRING;
    NUMBER;
    BOOLEAN;
    NULL;
}
Json_Token :: struct {
    type: Json_Token_Type;
    offset: s64;
    count: s64;
}
Json_Token_String :: struct {
    using #as base: Json_Token;
    value: string;
}
Json_Token_Number :: struct {
    using #as base: Json_Token;
    value_string: string;
}
Json_Token_Boolean :: struct {
    using #as base: Json_Token;
    value: bool;
}

New_Token :: ($T: Type, token_type: Json_Token_Type, offset: s64, char_count: s64) -> *T {
    token := New(T);
    token.type = token_type;
    token.offset = offset;
    token.count = char_count;
    return token;
}

Lex_State :: struct {
    json_string: string;
    cursor: s64;
    level: s64;

    string_escape: bool;
    string_buffer: String_Builder;
}

lex :: (json_string_input: string, tokenize_whitespace := false) -> ([..] *Json_Token, success: bool) {
    using state: Lex_State;
    state.json_string = json_string_input;
    state.cursor = 0;
    state.level = 0;

    tokens: [..] *Json_Token;

    Add_Token :: ($T: Type, token_type: Json_Token_Type, offset: s64, char_count: s64) -> *T #expand {
        token := New_Token(T, token_type, offset, char_count);
        array_add(*tokens, token);
        return token;
    }

    error_found := false;
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

        is_whitespace :: inline (char: u8) -> bool {
            if char == {
                case #char " ";  #through;
                case #char "\n"; #through;
                case #char "\r"; #through;
                case #char "\t";
                    return true;
                case;
                    return false;
            }
        }

        //
        // Whitespace
        //
        {
            next_cursor := cursor;
            while next_cursor < json_string.count && is_whitespace(json_string[next_cursor]) {
                next_cursor += 1;
            }
            if next_cursor > cursor {
                whitespace_count := next_cursor - cursor;
                debug_print("Whitespace (count=%)\n", whitespace_count);
                if tokenize_whitespace
                    Add_Token(Json_Token, .WHITESPACE, cursor, whitespace_count);
                cursor = next_cursor - 1;
                continue;
            }
        }

        //
        // String
        //
        if char == #char "\"" {
            next_cursor := cursor + 1;
            escaped := false;
            while next_cursor < json_string.count {
                next_char := json_string[next_cursor];

                if !escaped && next_char == #char "\"" {
                    offset := cursor + 1;

                    s: string;
                    s.data = json_string.data + offset;
                    s.count = next_cursor - cursor - 1;

                    debug_print("String ('%')\n",  s);

                    token := Add_Token(Json_Token_String, .STRING, offset, s.count);
                    token.value = s;

                    cursor = next_cursor;
                    break;
                }

                escaped = (next_char == #char "\\");
                next_cursor += 1;
            }

            continue;
        }

        //
        // Containers and Separators
        //
        keep_trying := false;
        if char == {
            case #char ":";
                debug_print("Object name/value separator\n");
                Add_Token(Json_Token, .OBJECT_NAME_VALUE_SEPARATOR, cursor, 1);

            case #char "{";
                debug_print("Object (begin level=%)\n", level);
                Add_Token(Json_Token, .OBJECT_BEGIN, cursor, 1);
                level += 1;
            case #char "}";
                debug_print("Object (end level=%)\n", level);
                Add_Token(Json_Token, .OBJECT_END, cursor, 1);
                level -= 1;

            case #char "[";
                debug_print("Array (begin level=%)\n", level);
                Add_Token(Json_Token, .ARRAY_BEGIN,cursor,  1);
                level += 1;
            case #char "]";
                debug_print("Array (end level=%)\n", level);
                Add_Token(Json_Token, .ARRAY_END, cursor, 1);
                level -= 1;

            case #char ",";
                debug_print("Member end\n");
                Add_Token(Json_Token, .MEMBER_SEPARATOR, cursor, 1);

            case;
                keep_trying = true;
        }
        if (!keep_trying)  continue;

        //
        // Keywords: Boolean / null
        //
        if json_string.count - cursor >= 4 {
            s4: string;
            s4.data = json_string.data + cursor;
            s4.count = 4;

            s5: string = s4;
            s5.count = 5;

            is_null    := (s4 == "null");
            bool_true  := (s4 == "true");
            bool_false := (s5 == "false");

            if bool_true || bool_false {
                bool_char_count := ifx bool_true then 4 else 5;
                token := Add_Token(Json_Token_Boolean, .BOOLEAN, cursor, bool_char_count);
                token.value = bool_true;
                debug_print("Boolean (%)\n", token.value);

                cursor += bool_char_count - 1;
                continue;

            } else if is_null {
                Add_Token(Json_Token, .NULL, cursor, 4);
                debug_print("Null\n");

                cursor += 4 - 1;
                continue;
            }
        }

        //
        // Number
        //
        {
            is_number_char :: inline (char: u8) -> bool {
                return char == #char "+" || char == #char "-" || char == #char "." || char == #char "e" ||
                    char == #char "E" || (char >= #char "0" && char <= #char "9");
            }

            next_cursor := cursor;
            while next_cursor < json_string.count {
                if !is_number_char(json_string[next_cursor])
                    break;

                next_cursor += 1;
            }

            number_char_count: s64 = next_cursor - cursor;
            if number_char_count > 0 {
                s: string;
                s.data = json_string.data + cursor;
                s.count = number_char_count;

                token := Add_Token(Json_Token_Number, .NUMBER, cursor, number_char_count);
                token.value_string = s;

                debug_print("Number ('%')\n", s);
                cursor = next_cursor - 1;
                continue;
            }
        }

        print("Unexpected Char: '");
        print_character(char);
        print("'\n", char);
        error_found = true;
        break;
    }

    if level != 0 {
        print("Error: unbalanced container types. Finished lexing at level %, but expected level 0.\n", level);
        error_found = true;
    }

    if error_found {
        array_reset(*tokens);
        return tokens, false;
    }

    if print_debug_output {
        print("LEXED TOKENS:\n");

        print_level := 0;
        for token: tokens {
            if token.type == {
                case .WHITESPACE;
                    continue;

                case .ARRAY_BEGIN; #through;
                case .OBJECT_BEGIN;
                    print_level += 1;

                case .ARRAY_END; #through;
                case .OBJECT_END;
                    print_level -= 1;
            }
            assert(print_level >= 0);

            for 1..2*print_level  print(" ");
            print("%: ", it_index+1);
            print("%", <<token);

            if token.type != .WHITESPACE {
                s: string;
                s.data = json_string_input.data + token.offset;
                s.count = token.count;

                print(": '%'", s);
            }
            print("\n");
        }
    }

    return tokens, true;
}

token_to_boolean_node :: inline (token: *Json_Token) -> *Json_Node_Boolean {
    assert(token.type == .BOOLEAN);

    node := New_Node(Json_Node_Boolean, .BOOLEAN);
    node.value = (cast(*Json_Token_Boolean)token).value;
    return node;
}
token_to_string_node :: inline (token: *Json_Token) -> *Json_Node_String {
    assert(token.type == .STRING);

    node := New_Node(Json_Node_String, .STRING);
    node.value = (cast(*Json_Token_String)token).value;
    return node;
}
token_to_number_node :: inline (token: *Json_Token) -> *Json_Node_Number {
    assert(token.type == .NUMBER);

    node := New_Node(Json_Node_Number, .NUMBER);
    float_string := (cast(*Json_Token_Number)token).value_string;

    success: bool;
    node.value, success = parse_float(*float_string);
    if !success {
        print("Failed to parse string to float: '%'\n", float_string);
        return null;
    }
    return node;
}

token_to_value_node :: inline (token: *Json_Token) -> *Json_Node {
    node: *Json_Node = null;
    if token.type == {
        case .STRING;
            node = token_to_string_node(token);
        case .NUMBER;
            node = token_to_number_node(token);
        case .BOOLEAN;
            node = token_to_boolean_node(token);
        case .NULL;
            node = New_Node(Json_Node_Null, .NULL);
    }
    return node;
}

parse_tokens :: (tokens: [] *Json_Token) -> (root: *Json_Node) {
    if !tokens  return null;

    throwaway_root: Json_Node_Array;
    throwaway_root.type = .ARRAY;

    stack: [..] *Json_Node;
    array_add(*stack, *throwaway_root);

    // skips whitespace tokens
    next_token :: () -> *Json_Token #expand {
        while true {
            token_index += 1;
            if token_index >= tokens.count
                return null;

            token := tokens[token_index];
            if token.type != .WHITESPACE
                return token;
        }
    }

    token_index := 0;
    token := tokens[0];
    while token {
        parent := peek(stack);
        if parent.type == .ARRAY {
            parent_array_node := cast(*Json_Node_Array) parent;

            if token.type == .ARRAY_END {
                debug_print("Ending array\n");

                pop(*stack);
                token = next_token();
                continue;
            }

            // enforce json format ","
            if parent_array_node.arr.count {
                if token.type != .MEMBER_SEPARATOR {
                    print("invalid token '%' following array member definition.\n", token.type);
                    return null;
                } else {
                    token = next_token();

                    // catch trailing ","
                    if token && token.type == .ARRAY_END {
                        print("trailing ',' not allowed but found in array.\n");
                        return null;
                    }
                }
            }

            node := token_to_value_node(token);
            if node {
                array_add(*parent_array_node.arr, node);
                debug_print("Added % to %: %\n", node.type, parent.type, <<node);
            } else {
                if token.type == {
                    case .OBJECT_BEGIN;
                        node := New_Node(Json_Node_Object, .OBJECT);
                        array_add(*parent_array_node.arr, node);
                        debug_print("Added object to array: %\n", <<node);

                        array_add(*stack, node);

                    case .ARRAY_BEGIN;
                        node := New_Node(Json_Node_Array, .ARRAY);
                        array_add(*parent_array_node.arr, node);
                        debug_print("Added array to array: %\n", <<node);

                        array_add(*stack, node);

                    case .OBJECT_END;
                        print("Unexpected OBJECT_END token while processing open array.\n");
                        return null;

                    case;
                        print("unhandled token type %\n", token.type);
                }
            }

            token = next_token();
        } else {
            assert(parent.type == .OBJECT);
            parent_object_node := cast(*Json_Node_Object) parent;

            if token.type == .OBJECT_END {
                debug_print("Ending object\n");

                pop(*stack);
                token = next_token();
                continue;
            }

            // enforce json format ","
            if parent_object_node.table.count {
                if token.type != .MEMBER_SEPARATOR {
                    print("invalid token '%' following object member definition.\n", token.type);
                    return null;
                } else {
                    token = next_token();

                    // catch trailing ","
                    if token && token.type == .OBJECT_END {
                        print("trailing ',' not allowed but found in array.\n");
                        return null;
                    }
                }
            }

            // get the entry name string
            if token.type != .STRING {
                print("Expected member name string but found token of type %\n", token.type);
                return null;
            }
            string_token := cast(*Json_Token_String) token;
            debug_print("Found member name string: '%'\n", string_token.value);

            // enforce json format ":"
            token = next_token();
            if !token || token.type != .OBJECT_NAME_VALUE_SEPARATOR {
                print("Expected ':' between name string and value for object member\n");
                return null;
            }

            token = next_token();
            if !token {
                print("Expected value token but reached end-of-file.\n");
                return null;
            }

            node := token_to_value_node(token);
            if node {
                table_add(*parent_object_node.table, string_token.value, node);
                debug_print("Added % to %: (\"%\": %)\n", node.type, parent.type, string_token.value, <<node);
            } else {
                if token.type == {
                    case .OBJECT_BEGIN;
                        node := New_Node(Json_Node_Object, .OBJECT);
                        table_add(*parent_object_node.table, string_token.value, node);
                        debug_print("Added % to %: (\"%\": %)\n", node.type, parent.type, string_token.value, <<node);

                        array_add(*stack, node);

                    case .ARRAY_BEGIN;
                        node := New_Node(Json_Node_Array, .ARRAY);
                        table_add(*parent_object_node.table, string_token.value, node);
                        debug_print("Added % to %: (\"%\": %)\n", node.type, parent.type, string_token.value, <<node);

                        array_add(*stack, node);

                    case .ARRAY_END;
                        print("Unexpected ARRAY_END token while processing open object.\n");
                        return null;

                    case;
                        print("Unexpected token type %\n", token.type);
                        return null;
                }
            }

            token = next_token();
        }
    }

    if token_index < tokens.count {
        print("% tokens remain after parsing.\n");
        return null;
    }

    assert(throwaway_root.arr.count == 1);
    return throwaway_root.arr[0];
}

New_Node :: ($T: Type, node_type: Json_Node_Type) -> *T {
    node := New(T);
    node.type = node_type;

    return node;
}


//
// User-facing API
//
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
    arr: [..] *Json_Node;
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

parse_json :: (input_filename: string, debug_output := false) -> (Json_Document, success: bool) {
    print_debug_output = debug_output;

    file_string, read_success := read_entire_file(input_filename);
    assert(read_success);
    debug_print("JSON CONTENTS\n%\n", file_string);

    tokens, lex_success := lex(file_string);
    if (!lex_success) {
        print("Failed lexing file '%'\n", input_filename);
        exit(1);
    }

    root := parse_tokens(tokens);
    if !root {
        print("Failed parsing file '%'\n", input_filename);
        exit(1);
    }

    doc: Json_Document;
    doc.root = root;
    doc._allocator = context.allocator;

    return doc, true;
}

free_memory :: (doc: Json_Document) {
    new_context: Context;
    new_context.allocator = doc._allocator;
    push_context new_context {
        stack: [..] *Json_Node;
        array_add(*stack, doc.root);

        while stack.count {
            node := pop(*stack);

            if node.type == .ARRAY {
                array_node := cast(*Json_Node_Array)node;
                for subnode: array_node.arr
                    array_add(*stack, subnode);
            } else if node.type == .OBJECT {
                object_node := cast(*Json_Node_Object)node;
                for subnode: object_node.table
                    array_add(*stack, subnode);
            }

            free(node);
        }
    }
}
