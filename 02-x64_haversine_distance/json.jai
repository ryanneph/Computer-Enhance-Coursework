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

//
// Lexing
//
Token_Type :: enum {
    INVALID :: 0;

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
Token :: struct {
    type: Token_Type;
    value_string: string;
}
New_Token :: (token_type: Token_Type, value_string: string) -> *Token {
    token := New(Token);
    token.type = token_type;
    token.value_string = value_string;
    return token;
}

lex :: (json_string: string, tokenize_whitespace := false) -> ([..] *Token, success: bool) {
    cursor: s64 = 0;
    level: s64 = 0;
    tokens: [..] *Token;

    Add_Token :: (token_type: Token_Type, offset: s64, char_count: s64) -> *Token #expand {
        value_string: string;
        value_string.data = json_string.data + offset;
        value_string.count = char_count;

        token := New_Token(token_type, value_string);
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

            print("% '", cursor);
            if char >= 32 print_character(char);
            else          print("0x%", char);
            print("': ");
        }

        //
        // Whitespace
        //
        {
            is_whitespace :: inline (char: u8) -> bool {
                return char == #char " " || char == #char "\n" || char == #char "\r" || char == #char "\t";
            }

            next_cursor := cursor;
            while next_cursor < json_string.count && is_whitespace(json_string[next_cursor]) {
                next_cursor += 1;
            }
            if next_cursor > cursor {
                if tokenize_whitespace {
                    whitespace_count := next_cursor - cursor;
                    Add_Token(.WHITESPACE, cursor, whitespace_count);
                    debug_print("Whitespace (count=%)\n", whitespace_count);
                }
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
                    token := Add_Token(.STRING, cursor + 1, next_cursor - cursor - 1);
                    debug_print("String ('%')\n", token.value_string);

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
        token_type: Token_Type;
        if char == {
            case #char ":";
                token_type = .OBJECT_NAME_VALUE_SEPARATOR;
            case #char "{";
                token_type = .OBJECT_BEGIN;
                level += 1;
            case #char "}";
                token_type = .OBJECT_END;
                level -= 1;
            case #char "[";
                token_type = .ARRAY_BEGIN;
                level += 1;
            case #char "]";
                token_type = .ARRAY_END;
                level -= 1;
            case #char ",";
                token_type = .MEMBER_SEPARATOR;
        }
        if (token_type != .INVALID) {
            token := Add_Token(token_type, cursor, 1);
            debug_print("Container/Separator: %\n", token);
            continue;
        }

        //
        // Keywords: Boolean / null
        //
        temp_cursor := cursor;
        while (temp_cursor < json_string.count) {
            temp_char := json_string[temp_cursor];
            if !is_alpha(temp_char)  break;
            temp_cursor += 1;
        }
        if (temp_cursor - cursor > 0) {
            keyword: string;
            keyword.data = json_string.data + cursor;
            keyword.count = temp_cursor - cursor;

            token_type: Token_Type = .INVALID;
            if keyword == {
                case "true"; #through;
                case "false";
                    token_type = .BOOLEAN;
                case "null";
                    token_type = .NULL;
                case;
                    print("invalid keyword '%'\n.", keyword);
            }
            if token_type != .INVALID {
                token := Add_Token(token_type, cursor, keyword.count);
                print("Keyword ('%')\n", keyword);
            }

            cursor = temp_cursor - 1;
            continue;
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
                if !is_number_char(json_string[next_cursor])  break;
                next_cursor += 1;
            }

            number_char_count: s64 = next_cursor - cursor;
            if number_char_count > 0 {
                token := Add_Token(.NUMBER, cursor, number_char_count);
                debug_print("Number ('%')\n", token.value_string);
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
            print("%\n", <<token);
        }
    }

    return tokens, true;
}

New_Node :: ($T: Type, node_type: Json_Node_Type) -> *T {
    node := New(T);
    node.type = node_type;

    return node;
}

token_to_value_node :: inline (token: *Token) -> *Json_Node {
    node: *Json_Node;
    if token.type == {
        case .STRING;
            node = New_Node(Json_Node, .STRING);
        case .NUMBER;
            node = New_Node(Json_Node, .NUMBER);
        case .BOOLEAN;
            node = New_Node(Json_Node, .BOOLEAN);
        case .NULL;
            node = New_Node(Json_Node, .NULL);
        case;
            return null;
    }

    node.value_string = token.value_string;
    return node;
}

parse_tokens :: (tokens: [] *Token) -> (root: *Json_Node) {
    if !tokens  return null;

    throwaway_root: Json_Node_Array;
    throwaway_root.type = .ARRAY;

    stack: [..] *Json_Node;
    array_add(*stack, *throwaway_root);

    next_token :: () -> *Token #expand {
        // skips whitespace tokens and returns null at end
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
            member_name_token := token;
            debug_print("Found member name string: '%'\n", member_name_token.value_string);

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
                table_add(*parent_object_node.table, member_name_token.value_string, node);
                debug_print("Added % to %: (\"%\": %)\n", node.type, parent.type, token.value_string, <<node);
            } else {
                if token.type == {
                    case .OBJECT_BEGIN;
                        node := New_Node(Json_Node_Object, .OBJECT);
                        table_add(*parent_object_node.table, member_name_token.value_string, node);
                        debug_print("Added % to %: (\"%\": %)\n", node.type, parent.type, token.value_string, <<node);

                        array_add(*stack, node);

                    case .ARRAY_BEGIN;
                        node := New_Node(Json_Node_Array, .ARRAY);
                        table_add(*parent_object_node.table, member_name_token.value_string, node);
                        debug_print("Added % to %: (\"%\": %)\n", node.type, parent.type, token.value_string, <<node);

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
    value_string: string;
}
// TODO(ryan): use linked list with one Json_Node type, instead of array/table members
Json_Node_Object :: struct {
    using #as base: Json_Node;
    table: Table(string, *Json_Node);
}
Json_Node_Array :: struct {
    using #as base: Json_Node;
    arr: [..] *Json_Node;
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

    temp_storage_context := context;
    // temp_storage_context.allocator = temporary_allocator;

    tokens: [..] *Token;
    lex_success: bool;
    push_context temp_storage_context {
        tokens, lex_success = lex(file_string);
        if (!lex_success) {
            print("Failed lexing file '%'\n", input_filename);
            exit(1);
        }
    }

    root := parse_tokens(tokens);
    if !root {
        print("Failed parsing file '%'\n", input_filename);
        exit(1);
    }

    // reset_temporary_storage();

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
