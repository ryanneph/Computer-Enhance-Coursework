#import "Basic";

#scope_file;
error :: (parser: *Json_Parser, token: Json_Token, message: string, args: ..Any) {
    parser.had_error = true;

    full_message := tprint("ERROR: {%, '%'}: %\n", token.type, as_string(token.value), message);
    print(full_message, ..args);
}

Json_Parser :: struct {
    source: Buffer;
    at: u64;
    had_error: b32;
}

Json_Token_Type :: enum {
    END_OF_STREAM :: 0;
    ERROR;

    OPEN_BRACE;
    CLOSE_BRACE;
    OPEN_BRACKET;
    CLOSE_BRACKET;
    COMMA;
    COLON;

    // keywords
    FALSE;
    NULL;
    TRUE;

    STRING_LITERAL;
    NUMBER;
}

Json_Token :: struct {
    type: Json_Token_Type;
    value: Buffer;
}

Json_Element :: struct {
    label: Buffer;
    value: Buffer;
    first_sub_element: *Json_Element;
    next_sibling: *Json_Element;
}

alloc_json_element :: (count: u64 = 1) -> *Json_Element {
    result := cast(*Json_Element) alloc(xx count * size_of(Json_Element));
    for 1..count {
        result[0] = .{};
    }
    return result;
}

free_json_element :: (element: *Json_Element) {
    free(element);
}

is_json_whitespace :: (source: Buffer, at: u64) -> b32 {
    result := false;
    if is_in_bounds(source, at) {
        val: u8 = source.data[at];
        if val == {
            case #char " "; #through;
            case #char "\t"; #through;
            case #char "\n"; #through;
            case #char "\r";
                result = true;
        }
    }
    return result;
}

is_json_digit :: (source: Buffer, at: u64) -> b32 {
    result := false;
    if is_in_bounds(source, at) {
        val := source.data[at];
        result = val >= #char "0" && val <= #char "9";
    }
    return result;
}

parse_keyword :: (source: Buffer, at: *u64, keyword_remaining: Buffer, type: Json_Token_Type,
        result: *Json_Token)
{
    if is_in_bounds(source, at.* + keyword_remaining.count) {
        check := source;
        check.data += at.*;
        check.count = keyword_remaining.count;

        if are_equal(check, keyword_remaining) {
            result.type = type;
            result.value.count += keyword_remaining.count;
            at.* += keyword_remaining.count;
        }
    }
}

get_json_token :: (parser: *Json_Parser) -> Json_Token {
    result: Json_Token;

    source := parser.source;
    at := parser.at;

    while is_json_whitespace(source, at) {
        at += 1;
    }

    if is_in_bounds(source, at) {
        result.type = .ERROR;
        result.value = .{count=1, data=source.data + at};

        val := source.data[at];
        at += 1;

        char :: () -> u8 #expand { return source.data[at]; }
        char_is :: (s: string) -> b32 #expand {
            #assert(s.count == 1);
            return source.data[at] == s.data[0];
        }
        if val == {
            case #char "{";  result.type = .OPEN_BRACE;
            case #char "}";  result.type = .CLOSE_BRACE;
            case #char "[";  result.type = .OPEN_BRACKET;
            case #char "]";  result.type = .CLOSE_BRACKET;
            case #char ",";  result.type = .COMMA;
            case #char ":";  result.type = .COLON;

            case #char "f";
                parse_keyword(source, *at, BUFFER("alse"), .FALSE, *result);
            case #char "n";
                parse_keyword(source, *at, BUFFER("ull"), .NULL, *result);
            case #char "t";
                parse_keyword(source, *at, BUFFER("rue"), .TRUE, *result);

            case #char "\""; {
                start := at;
                result.type = .STRING_LITERAL;

                while is_in_bounds(source, at) && !char_is("\"") {
                    // NOTE(ryan): skip escaped quotation marks
                    if is_in_bounds(source, at + 1) &&
                        source.data[at] == #char "\\" && source.data[at + 1] == #char "\""
                    {
                        at += 1;
                    }

                    at += 1;
                }

                result.value.data = source.data + start;
                result.value.count = at - start;
                if is_in_bounds(source, at) {
                    assert(char_is("\""));
                    at += 1;
                }
            }

            case #char "-"; #through;
            case #char "0"; #through;
            case #char "1"; #through;
            case #char "2"; #through;
            case #char "3"; #through;
            case #char "4"; #through;
            case #char "5"; #through;
            case #char "6"; #through;
            case #char "7"; #through;
            case #char "8"; #through;
            case #char "9"; {
                start := at - 1; // have already incremented;
                result.type = .NUMBER;

                // NOTE(ryan): move past leading negative sign if one exists
                if val == #char "-" && is_in_bounds(source, at) {
                    val = char();
                    at += 1;
                }

                // NOTE(ryan): if the leading digit wasn't 0, parse any digits before the decimal point
                if val != #char "0" {
                    while is_json_digit(source, at) {
                        at += 1;
                    }
                }

                // NOTE(ryan): if there is a decimal point, parse any digits after the decimal point
                if is_in_bounds(source, at) && char_is(".") {
                    at += 1;
                    while is_json_digit(source, at) {
                        at += 1;
                    }
                }

                // NOTE(ryan): if it's in scientific notation, parse any digits after the "e"
                if is_in_bounds(source, at) && (char_is("e") || char_is("E")) {
                    at += 1;

                    if is_in_bounds(source, at) && (char_is("+") || char_is("-")) {
                        at += 1;
                    }

                    while is_json_digit(source, at) {
                        at += 1;
                    }
                }

                result.value.count = at - start;
            }

            case;
        }
    }

    parser.at = at;
    return result;
}

parse_json_list :: (parser: *Json_Parser, end_type: Json_Token_Type, has_labels: b32)
    -> *Json_Element
{
    first_element: *Json_Element;
    last_element: *Json_Element;

    while is_parsing(parser) {
        label: Buffer;
        token := get_json_token(parser);

        // NOTE(ryan): get label and reassign value
        if has_labels {
            if token.type == .STRING_LITERAL {
                label = token.value;

                expect_colon := get_json_token(parser);
                if expect_colon.type == .COLON {
                    token = get_json_token(parser);
                } else {
                    error(parser, expect_colon, "expected colon after field name.");
                }
            } else if token.type != end_type {
                error(parser, token, "Unexpected token in JSON (expected %).", token.type, end_type);
            }
        }

        element := parse_json_element(parser, label, token);
        if element {
            // NOTE(ryan): append to linked-list of siblings
            if last_element {
                last_element.next_sibling = element;
            } else {
                first_element = element;
            }
            last_element = element;
        } else if token.type == end_type {
            break;
        } else {
            error(parser, token, "Unexpected token in JSON.");
        }

        expect_comma := get_json_token(parser);
        if expect_comma.type == end_type {
            break;
        } else if expect_comma.type != .COMMA {
            error(parser, expect_comma, "Expected comma.");
        }
    }

    return first_element;
}

parse_json_element :: (parser: *Json_Parser, label: Buffer, value: Json_Token) -> *Json_Element {
    valid: b32 = true;

    sub_element: *Json_Element;
    if value.type == {
        case .OPEN_BRACKET; {
            sub_element = parse_json_list(parser, .CLOSE_BRACKET, has_labels=false);
        }
        case .OPEN_BRACE; {
            sub_element = parse_json_list(parser, .CLOSE_BRACE, has_labels=true);
        }

        case .FALSE; #through;
        case .NULL; #through;
        case .TRUE; #through;
        case .STRING_LITERAL; #through;
        case .NUMBER; {
            // NOTE(ryan): nothing to do, since there's no additional data
        }

        case;  valid = false;
    }

    result: *Json_Element;
    if valid {
        result = alloc_json_element();
        result.label = label;
        result.value = value.value;
        result.first_sub_element = sub_element;
    }

    return result;
}

is_parsing :: (parser: *Json_Parser) -> b32 {
    result := !parser.had_error && is_in_bounds(parser.source, parser.at);
    return result;
}

parse_json :: (input_json: Buffer) -> *Json_Element {
    parser := Json_Parser.{source=input_json};

    element := parse_json_element(*parser, .{}, get_json_token(*parser));
    return element;
}

free_json :: (top_element: *Json_Element) {
    element := top_element;
    while element {
        free_element := element;
        element = element.next_sibling;

        free_json(free_element.first_sub_element);
        free(free_element);
    }
}

lookup_element :: (top_element: *Json_Element, element_name: Buffer) -> *Json_Element {
    element := top_element;
    found: *Json_Element;
    while (element) {
        if are_equal(element.label, element_name) {
            found = element;
            break;
        }

        found = lookup_element(element.first_sub_element, element_name);
        if found {
            break;
        }

        element = element.next_sibling;
    }

    return found;
}

convert_json_sign :: (source: Buffer, at_result: *u64) -> float64 {
    at := at_result.*;

    result: float64 = 1.0;
    if is_in_bounds(source, at) && source.data[at] == #char "-" {
        result = -1.0;
        at += 1;
    }

    at_result.* = at;
    return result;
}

convert_json_number :: (source: Buffer, at_result: *u64) -> float64 {
    at := at_result.*;

    result: float64 = 0;
    while is_in_bounds(source, at) {
        digit := source.data[at] - #char "0";
        if digit < 10 {
            result = 10 * result + digit;
            at += 1;
        } else {
            break;
        }
    }

    at_result.* = at;
    return result;
}

convert_element_to_f64 :: (top_element: *Json_Element, element_name: Buffer) -> float64 {
    result: float64 = 0;

    element := lookup_element(top_element, element_name);
    if element {
        source := element.value;
        at := cast(u64, 0);

        sign   := convert_json_sign(source, *at);
        number := convert_json_number(source, *at);

        if is_in_bounds(source, at) && source.data[at] == #char "." {
            at += 1;
            factor: float64 = 0.1;
            while is_in_bounds(source, at) {
                digit := source.data[at] - #char "0";
                if digit < 10 {
                    number += factor * digit;
                    factor *= 0.1;
                    at += 1;
                } else {
                    break;
                }
            }
        }

        if is_in_bounds(source, at) && (source.data[at] == #char "e" || source.data[at] == #char "E") {
            at += 1;
            if is_in_bounds(source, at) && source.data[at] == #char "+" {
                at += 1;
            }

            exponent_sign := convert_json_sign(source, *at);
            exponent      := exponent_sign * convert_json_number(source, *at);
            number *= pow(10.0, exponent);
        }

        result = sign * number;
    }

    return result;
}

#scope_export
parse_json_pairs :: (input_json_string: string, max_pair_count: u64, pairs: *Point_Pair) -> u64 {
    pair_count: u64 = 0;
    input_json := BUFFER(input_json_string);

    json := parse_json(input_json);
    defer free_json(json);

    pairs_array := lookup_element(json, BUFFER("pairs"));
    if (pairs_array) {
        element := pairs_array.first_sub_element;
        while element != null && pair_count < max_pair_count {
            defer element = element.next_sibling;

            pair := pairs + pair_count;
            pair_count += 1;

            pair.* = .{
                x0 = convert_element_to_f64(element, BUFFER("x0")),
                y0 = convert_element_to_f64(element, BUFFER("y0")),
                x1 = convert_element_to_f64(element, BUFFER("x1")),
                y1 = convert_element_to_f64(element, BUFFER("y1")),
            };
        }
    }

    return pair_count;
}
