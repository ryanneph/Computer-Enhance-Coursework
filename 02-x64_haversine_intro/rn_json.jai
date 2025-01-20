#import "Basic";
#import "Bucket_Array";
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

lex :: (json_string: string, tokenize_whitespace := false) -> ([..]Token, success: bool) {
    cursor: s64 = 0;
    level: s64 = 0;
    tokens: [..]Token;

    add_token :: (token_type: Token_Type, offset: s64, char_count: s64) -> *Token #expand {
        value_string: string;
        value_string.data = json_string.data + offset;
        value_string.count = char_count;

        token: Token;
        token.type = token_type;
        token.value_string = value_string;

        array_add(*tokens, token);
        return *tokens[tokens.count - 1];
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

        // TODO(ryan): combine all "types" of token identification into one switch

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
                    add_token(.WHITESPACE, cursor, whitespace_count);
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
                    token := add_token(.STRING, cursor + 1, next_cursor - cursor - 1);
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
            token := add_token(token_type, cursor, 1);
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
                token := add_token(token_type, cursor, keyword.count);
                print("Keyword ('%')\n", keyword);
            }

            cursor = temp_cursor - 1;
            continue;
        }

        //
        // Number
        //
        {
            to_lowercase :: (char: u8) -> u8 #expand {
                char & ~32 & 0xff;
            }
            is_number_char :: inline (char: u8) -> bool {
                return (char >= #char "0" && char <= #char "9") || char == #char "+" || char == #char "-" ||
                    char == #char "." || to_lowercase(char) == #char "e";
            }

            next_cursor := cursor;
            while next_cursor < json_string.count {
                if !is_number_char(json_string[next_cursor])  break;
                next_cursor += 1;
            }

            number_char_count: s64 = next_cursor - cursor;
            if number_char_count > 0 {
                token := add_token(.NUMBER, cursor, number_char_count);
                debug_print("Number ('%')\n", token.value_string);
                cursor = next_cursor - 1;
                continue;
            }
        }

        print("Unexpected Char: '");
        print_character(char);
        print("'\n");
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
        print("LEXED TOKENS (count=%, size=% bytes):\n", tokens.count, tokens.count * size_of(Token));

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
            print("%\n", token);
        }
    }

    return tokens, true;
}

// used as a stable allocator for new nodes during parsing
Json_Node_Storage :: Bucket_Array(Json_Node, 1024);

parse_tokens :: (node_storage: *Json_Node_Storage, tokens: []Token) -> (root: *Json_Node) {
    if !tokens  return null;

    throwaway_root: Json_Node;
    throwaway_root.type = .ARRAY;

    stack: [..] *Json_Node;
    array_add(*stack, *throwaway_root);
    defer array_free(stack);

    New_Node :: (node_type: Json_Node_Type) -> *Json_Node #expand {
        node: Json_Node;
        node.type = node_type;

        locator, pointer := bucket_array_add(node_storage, node);
        return pointer;
    }

    next_token :: () -> *Token #expand {
        // skips whitespace tokens and returns null at end
        while true {
            token_index += 1;
            if token_index >= tokens.count
                return null;

            token := *tokens[token_index];
            if token.type != .WHITESPACE
                return token;
        }
    }

    token_index := 0;
    token := *tokens[0];
    while token {
        parent := peek(stack);
        if parent.type == .ARRAY || parent.type == .OBJECT {
            if token.type == .ARRAY_END || token.type == .OBJECT_END {
                debug_print("Ending array/object\n");
                pop(*stack);
                token = next_token();
                continue;
            }

            // enforce json format ","
            if parent.next_child {
                if token.type != .MEMBER_SEPARATOR {
                    print("invalid token '%' following array/object member definition.\n", token.type);
                    return null;
                } else {
                    token = next_token();

                    // catch trailing ","
                    if token && (token.type == .ARRAY_END || token.type == .OBJECT_END) {
                        print("trailing ',' not allowed but found in array.\n");
                        return null;
                    }
                }
            }

            member_name_token: *Token = null;
            if (parent.type == .OBJECT) {
                // get the entry name string
                if token.type != .STRING {
                    print("Expected member name string but found token of type %\n", token.type);
                    return null;
                }
                member_name_token = token;
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
            }

            node: *Json_Node = null;
            if token.type == {
                case .STRING;       node = New_Node(.STRING);
                case .NUMBER;       node = New_Node(.NUMBER);
                case .BOOLEAN;      node = New_Node(.BOOLEAN);
                case .NULL;         node = New_Node(.NULL);
                case .OBJECT_BEGIN; node = New_Node(.OBJECT);
                case .ARRAY_BEGIN;  node = New_Node(.ARRAY);
                case;
                    print("unhandled token type %\n", token.type);
                    return null;
            }

            if member_name_token {
                assert(parent.type == .OBJECT);
                node.member_name = member_name_token.value_string;
            }

            if !parent.next_child {
                parent.next_child = node;
                parent.last_child = node;
            } else {
                parent.last_child.next_sibling = node;
                parent.last_child = node;
            }

            if #complete node.type == {
                case .STRING; #through;
                case .NUMBER; #through;
                case .BOOLEAN; #through;
                case .NULL;
                    node.value_string = token.value_string;

                case .OBJECT; #through;
                case .ARRAY;
                    array_add(*stack, node);
            }

            debug_print("Added % to %: %\n", node.type, parent.type, <<node);
            token = next_token();
        }
    }

    if token_index < tokens.count {
        print("% tokens remain after parsing.\n", tokens.count - token_index);
        return null;
    }

    return throwaway_root.next_child;
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

    next_sibling: *Json_Node;

    next_child: *Json_Node;
    last_child: *Json_Node;

    // only used for OBJECT type
    member_name: string;
}

Json_Document :: struct {
    root: *Json_Node;

    // internal use
    node_storage: Json_Node_Storage;
}

parse_json :: (json_string: string, debug_output := false) -> (Json_Document, success: bool) {
    print_debug_output = debug_output;

    tokens, lex_success := lex(json_string);
    if (!lex_success) {
        print("Failed lexing json\n");
        return .{}, false;
    }

    // TODO(ryan): lex tokens during json parsing as needed.
    node_storage: Json_Node_Storage;
    root_node := parse_tokens(*node_storage, tokens);

    array_free(tokens);

    if !root_node {
        print("Failed parsing json\n");
        return .{}, false;
    }

    doc: Json_Document;
    doc.root = root_node;
    doc.node_storage = node_storage;

    return doc, true;
}

free_memory :: (doc: Json_Document) {
    bucket_array_reset(*doc.node_storage);
}

find_node_by_name :: (object_node: *Json_Node, name: string) -> node: *Json_Node {
    node: *Json_Node;

    assert(object_node.type == .OBJECT);
    it := object_node.next_child;
    while it != null {
        if it.member_name == name {
            node = it;
            break;
        }
        it = it.next_sibling;
    }

    return node;
}

parse_json_pairs :: (json_string: string, max_pair_count: u64, pairs: *Point_Pair) -> u64 {
    pair_count: u64;

    json_doc: Json_Document;
    parse_success: bool;
    {
        profile_block("json:lex+parse");
        json_doc, parse_success = parse_json(json_string);
        if !parse_success {
            print("failed to parse json\n");
            return 0;
        }
    }

    pairs_node := find_node_by_name(json_doc.root, "pairs");
    if pairs_node {
        profile_block("parse floats");
        it := pairs_node.next_child;
        while it != null {
            assert(it.type == .OBJECT);

            get_member :: (object_node: *Json_Node, member_name: string) -> float64 {
                result: float64 = 0;

                node := find_node_by_name(object_node, member_name);
                if node {
                    result=, success := string_to_float64(node.value_string);
                    if !success {
                        print("Error parsing float from string '%'.\n", node.value_string);
                        result = 0.0;
                    }
                }
                return result;
            }

            pair := pairs + pair_count;
            pair_count += 1;
            pair.* = .{
                x0 = get_member(it, "x0"),
                y0 = get_member(it, "y0"),
                x1 = get_member(it, "x1"),
                y1 = get_member(it, "y1"),
            };

            it = it.next_sibling;
        }
    }

    return pair_count;
}
