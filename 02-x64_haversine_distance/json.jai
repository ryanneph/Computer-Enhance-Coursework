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

parse_tokens :: (tokens: [] *Token, iterative_token_cleanup := false) -> (root: *Json_Node) {
    if !tokens  return null;

    throwaway_root: Json_Node;
    throwaway_root.type = .ARRAY;

    stack: [..] *Json_Node;
    array_add(*stack, *throwaway_root);

    next_token :: () -> *Token #expand {
        // skips whitespace tokens and returns null at end
        while true {
            // NOTE(ryan): aggressively reclaim memory for no-longer-used tokens
            if iterative_token_cleanup {
                free(tokens[token_index]);
                tokens[token_index] = null;
            }

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

            node := token_to_value_node(token);
            if node {
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
                debug_print("Added % to %: %\n", node.type, parent.type, <<node);
            } else {
                if token.type == {
                    case .OBJECT_BEGIN; #through;
                    case .ARRAY_BEGIN;
                        node_type := ifx token.type == .OBJECT_BEGIN then Json_Node_Type.OBJECT else .ARRAY;
                        node := New_Node(Json_Node, node_type);
                        if member_name_token {
                            assert(parent.type == .OBJECT);
                            node.member_name = member_name_token.value_string;
                        }
                        debug_print("Added % to %: %\n", node.type, parent.type, <<node);

                        if !parent.next_child {
                            parent.next_child = node;
                            parent.last_child = node;
                        } else {
                            parent.last_child.next_sibling = node;
                            parent.last_child = node;
                        }

                        array_add(*stack, node);

                    case;
                        print("unhandled token type %\n", token.type);
                }
            }

            token = next_token();
        }
    }

    if token_index < tokens.count {
        print("% tokens remain after parsing.\n");
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

// TODO(ryan): chunked linear allocator for all storage, free all on destruction.
Json_Document :: struct {
    root: *Json_Node;

    // internal use
    _allocator: Allocator;
}

parse_json :: (json_string: string, debug_output := false) -> (Json_Document, success: bool) {
    print_debug_output = debug_output;

    // TODO(ryan): use a dynamically growable linear allocator, then free all token storage in one call.
    // note that temporary_allocator doesn't support sizes large enough for 10M haversine pairs, so we need
    // to roll our own.
    temp_storage_context := context;

    tokens: [..] *Token;
    lex_success: bool;
    push_context temp_storage_context {
        tokens, lex_success = lex(json_string);
        if (!lex_success) {
            print("Failed lexing json\n");
            exit(1);
        }
    }

    // NOTE(ryan): parse_tokens() free()'s tokens as it monotonically iterates the token list.
    // Non-null members of "tokens" must be free()'d by us.
    root := parse_tokens(tokens, iterative_token_cleanup = true);
    for token: tokens {
        if token != null  free(token);
    }
    array_free(tokens);

    if !root {
        print("Failed parsing json\n");
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
            if node.type == .ARRAY || node.type == .OBJECT {
                it := node.next_child;
                while it != null
                    array_add(*stack, it);
            }

            free(node);
        }
    }
}

find_node_by_name :: (object_node: *Json_Node, name: string) -> (found: bool, node: *Json_Node) {
    assert(object_node.type == .OBJECT);

    found := false;
    node: *Json_Node;
    it := object_node.next_child;
    while it != null {
        if it.member_name == name {
            found = true;
            node = it;
            break;
        }
        it = it.next_sibling;
    }

    return found, node;
}

