#import "Basic";
#import "Command_Line";
#import "File";
#import "Math";
#import "Random";

Point_Pair :: struct {
    x0, y0: float64;
    x1, y1: float64;
}

generate_pairs_uniform :: (count: u64) -> [..]Point_Pair {
    pairs: [..]Point_Pair;

    for 0..count-1 {
        p: Point_Pair = ---;
        p.x0 = random_get_within_range(-180, 180);
        p.x1 = random_get_within_range(-180, 180);
        p.y0 = random_get_within_range(-90, 90);
        p.y1 = random_get_within_range(-90, 90);

        array_add(*pairs, p);
    }

    return pairs;
}

format_as_json :: (pairs: [..]Point_Pair, allocator: Allocator) -> string {
    FMT :: (value: float64) -> FormatFloat #expand {
        return formatFloat(value, width=21, trailing_width=16, zero_removal=.NO);
    }

    builder: String_Builder;
    builder.allocator = allocator;

    append(*builder, "{\"pairs\": [\n");
    for p: pairs {
        print_to_builder(*builder, "    {\"x0\": %, \"y0\": %, \"x1\": %, \"y1\": %}%\n",
            FMT(p.x0), FMT(p.y0), FMT(p.x1), FMT(p.y1), ifx it_index == pairs.count-1 then "" else ",");
    }
    append(*builder, "]}");

    return builder_to_string(*builder);
}

reference_haversine :: (pair: Point_Pair, earth_radius: float64 = 6372.8) -> float64 {
    radians :: inline (degrees: float64) -> float64 {
        return degrees * 0.01745329251994329577;
    }

    lat0 := pair.y0;
    lat1 := pair.y1;
    lon0 := pair.x0;
    lon1 := pair.x1;

    dlat := radians(lat1 - lat0);
    dlon := radians(lon1 - lon0);
    lat0  = radians(lat0);
    lat1  = radians(lat1);

    a := square(sin(dlat / 2.0)) + cos(lat0) * cos(lat1) * square(sin(dlon / 2.0));
    c := 2.0 * asin(sqrt(a));

    result := earth_radius * c;
    return result;
}

generate :: (pair_count: u64) {
    pairs := generate_pairs_uniform(pair_count);
    dists: [..]float64;
    array_resize(*dists, pairs.count);

    average: float64 = 0;
    for pair: pairs {
        dist := reference_haversine(pair);
        average += dist;
        dists[it_index] = dist;
    }
    average /= pairs.count;

    // json encoding
    json_string := format_as_json(pairs, temporary_allocator);

    json_output_file := "haversine_input.json";
    write_entire_file(json_output_file, json_string);

    // binary encoding
    {
        output_file := "haversine_reference.bin";
        file, success := file_open(output_file, for_writing=true);
        assert(success);

        WRITE :: (value: $T) #expand {
            written := file_write(*file, *value, size_of(T));
            assert(written);
        }

        count: u64 = xx pairs.count;
        WRITE(count);

        for pair: pairs {
            pair_encoding: struct {
                pair: Point_Pair;
                distance: float64;
            };
            pair_encoding.pair = pair;
            pair_encoding.distance = dists[it_index];

            WRITE(pair_encoding);
        }

        file_close(*file);
    }

    print("average of % pairs: %\n", pairs.count, average);
}

#load "json.jai";
compute :: (input_name: string) {
    json_doc, success := parse_json(input_name);
    if !success {
        print("failed to parse json: '%'\n", input_name);
        return;
    }

    print("JSON DOC: \n%\n", json_doc);
}

Program_Args :: struct {
    mode: string;  @"?choose from {generate, compute}"
    count: s64;    @"?generator output instance count"
    input: string; @"?json input filename"
}

main :: () {
    success, args, is_set, free_args := parse_arguments(Program_Args,
        Argument_Flags.FREE_ARGUMENTS_ALLOWED | .ALIGN_HELP);

    if !args.mode.count {
        args.mode = "compute";
        print("'-mode' not set, defaulting to '%'.\n", args.mode);
    }
    if args.mode == {
        case "compute";
            if !args.input.count {
                args.input = "haversine_input.json";
                print("'-input' not set, defaulting to '%'.\n", args.input);
            }
            compute(args.input);

        case "generate";
            if args.count <= 0 {
                old_count := args.count;
                args.count = 10;
                print("invalid value for '-count': %. Using default: %.\n",
                    old_count, args.count);
            }
            generate(xx args.count);

        case;
            print("invalid value for '-mode': '%'.\n", args.mode);
    }

}
