#import "Basic";
#import "File";
#import "Hash_Table";

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

//
// Lexing
//
Json_Token_Type :: enum {
    OBJECT_BEGIN;
    OBJECT_END;
    OBJECT_NAME_RAW; // unparsed string that must still be validated
    OBJECT_VALUE_RAW; // unparsed string that may contain sub-hierarchy
    OBJECT_NAME_VALUE_SEPARATOR;

    ARRAY_BEGIN;
    ARRAY_END;
    ARRAY_MEMBER_RAW; // unparsed string that may contain sub-hierarchy

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
    level: s64;
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

Lex_State :: struct {
    json_string: string;
    cursor: s64;
    level: s64;

    string_escape: bool;
    string_buffer: String_Builder;
}

lex :: (json_string_input: string) -> [..] *Json_Token {
    using state: Lex_State;
    state.json_string = json_string_input;
    state.cursor = 0;
    state.level = 0;

    tokens: [..] *Json_Token;

    New_Token :: ($T: Type, token_type: Json_Token_Type, offset: s64, char_count: s64) -> *T #expand {
        token := New(T);
        token.type = token_type;
        token.offset = offset;
        token.count = char_count;
        token.level = level;

        array_add(*tokens, token);
        return token;
    }

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
                New_Token(Json_Token, .WHITESPACE, cursor, whitespace_count);
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

                    token := New_Token(Json_Token_String, .STRING, offset, s.count);
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
                token := New_Token(Json_Token, .OBJECT_NAME_VALUE_SEPARATOR, cursor, 1);

            case #char "{";
                debug_print("Object (begin level=%)\n", level);
                token := New_Token(Json_Token, .OBJECT_BEGIN, cursor, 1);
                level += 1;
            case #char "}";
                level -= 1;
                debug_print("Object (end level=%)\n", level);
                token := New_Token(Json_Token, .OBJECT_END, cursor, 1);

            case #char "[";
                debug_print("Array (begin level=%)\n", level);
                token := New_Token(Json_Token, .ARRAY_BEGIN,cursor,  1);
                level += 1;
            case #char "]";
                level -= 1;
                debug_print("Array (end level=%)\n", level);
                token := New_Token(Json_Token, .ARRAY_END, cursor, 1);

            case #char ",";
                debug_print("Member end\n");
                token := New_Token(Json_Token, .MEMBER_SEPARATOR, cursor, 1);

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

                token := New_Token(Json_Token_Boolean, .BOOLEAN, cursor, bool_char_count);
                token.value = bool_true;

                debug_print("Boolean (%)\n", token.value);

                cursor += bool_char_count - 1;
                continue;
            } else if is_null {
                token := New_Token(Json_Token, .NULL, cursor, 4);
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

                token := New_Token(Json_Token_Number, .NUMBER, cursor, number_char_count);
                token.value_string = s;

                debug_print("Number ('%')\n", s);
                cursor = next_cursor - 1;
                continue;
            }
        }

        print("UNKNOWN CHAR: '%'\n", char);
        assert(false);
    }
    assert(level == 0);

    return tokens;
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

parse_json :: (input_filename: string, debug_output := false) -> (Json_Document, success: bool) {
    print_debug_output = debug_output;

    file_string, success := read_entire_file(input_filename);
    print("FILE CONTENTS\n%\n", file_string);

    tokens := lex(file_string);

    print("TOKENS:\n");
    for token: tokens {
        if token.type == .WHITESPACE  continue;

        for 1..2*token.level  print(" ");
        print("%: ", it_index+1);
        print("%", <<token);

        if token.type != .WHITESPACE {
            s: string;
            s.data = file_string.data + token.offset;
            s.count = token.count;

            print(": '%'", s);
        }
        print("\n");
    }

    root: *Json_Node = null;
    // root := parse_tokens_to_node_tree(tokens);

    doc: Json_Document;
    doc.root = root;
    doc._allocator = context.allocator;

    return doc, true;
}
