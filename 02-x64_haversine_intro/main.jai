//===== Debug Options =======
USE_PROFILER        :: true;
REPORT_MEMORY_LEAKS :: false;
//===========================

#import "Basic"()(MEMORY_DEBUGGER=REPORT_MEMORY_LEAKS);
#import "Command_Line";
#import "File";
#import "Math";
#import "Random";

#import "profiler"()(DISABLED=!USE_PROFILER);
#import "platform";

#load "types.jai";

generate_pairs_uniform :: (count: u64) -> [..]Point_Pair {
    pairs: [..]Point_Pair;

    time := current_time_monotonic();
    time_ms := to_milliseconds(time);
    random_seed(cast(u64) time_ms);

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
    print("average of % pairs: %\n", pairs.count, average);

    // json encoding
    json_string := format_as_json(pairs, temporary_allocator);

    json_output_file := tprint("haversine_input_%.json", pairs.count);
    write_entire_file(json_output_file, json_string);
    print("Generated % pairs and saved to file '%'\n", pairs.count, json_output_file);

    // binary encoding
    {
        output_file := tprint("haversine_answer_%.bin", pairs.count);
        file, success := file_open(output_file, for_writing=true);
        assert(success);

        WRITE :: (value: $T) #expand {
            written := file_write(*file, *value, size_of(T));
            assert(written);
        }

        count: s64 = pairs.count;
        WRITE(count);

        for pair: pairs {
            WRITE(pair);
        }

        coefficient := 1 / cast(float64, pairs.count);
        sum: float64;
        for pair: pairs {
            distance: float64 = dists[it_index];
            sum += coefficient * distance;
            WRITE(distance);
        }
        WRITE(sum);

        file_close(*file);
        print("Generated % pairs and saved to file '%'\n", pairs.count, output_file);
    }
}

read_binary_data :: (filename: string) -> ([]Point_Pair, distances: []float64,  success: bool) {
    profile_block("read binary data file");

    file, ok := file_open(filename);
    if !ok  return .[], .[], false;

    READ_ONE :: ($T: Type) -> T #expand {
        dest: T;
        ok, bytes_read := file_read(file, *dest, size_of(T));
        assert(ok && bytes_read == size_of(T));
        return dest;
    }
    READ_MANY :: (dest: *$T, count: s64) #expand {
        bytes_to_read := size_of(T) * count;
        ok, bytes_read := file_read(file, dest, bytes_to_read);
        assert(ok && bytes_read == bytes_to_read);
    }

    pair_count := READ_ONE(s64);
    pairs     := NewArray(pair_count, Point_Pair, initialized = false);
    distances := NewArray(pair_count, float64, initialized = false);

    READ_MANY(cast(*Point_Pair)pairs.data, pair_count);
    READ_MANY(cast(*float64)distances.data, pair_count);

    return pairs, distances, true;
}

compute_from_binary :: (input_filename: string) {
    pairs, dists, ok := read_binary_data(input_filename);
    if !ok {
        print("failed to open binary data from file '%'\n", input_filename);
        return;
    }
    defer {
        free(pairs.data);
        free(dists.data);
    }

    print("Found % pairs in binary file '%'\n", pairs.count, input_filename);

    {
        profile_block("compute");
        for pairs {
            dist := reference_haversine(it);
            error := (dist - dists[it_index]) / dists[it_index];
            // print("% (actual: %, error=%0%%)\n", dist, dists[it_index], error * 100.0);
        }
    }
}

parse_haversine_pairs :: (input_json: string, max_pair_count: u64, pairs: *Point_Pair) -> u64 {
    pair_count: u64;

    profile_block("parse_haversine_pairs");
    #if 0 {
        // ryanneph: json parser v1
        #load "rn_json.jai";
    } else {
        // cmuratori: json parser ported to jai
        #load "cm_json.jai";
    }
    pair_count = parse_json_pairs(input_json, max_pair_count, pairs);

    return pair_count;
}

compute_from_json :: (input_filename: string) {
    json_string, read_success := read_full_file(input_filename);
    assert(read_success);
    defer free(json_string);

    min_json_pair_encoding: u64 = 16; // NOTE(ryan): there should be no way to define a pair in JSON without substantially more characters than this
    max_pair_count := cast(u64) json_string.count / min_json_pair_encoding;
    pairs := cast(*Point_Pair) alloc(xx max_pair_count * size_of(Point_Pair));
    defer free(pairs);

    pair_count := parse_haversine_pairs(json_string, max_pair_count, pairs);
    sum: float64;
    {
        profile_block_bandwidth("compute", pair_count * size_of(Point_Pair));
        for 1..cast(s64, pair_count)-1 {
            haversine_distance := reference_haversine(pairs[it]);
            sum += haversine_distance;
        }
    }
    average: float64 = sum / cast(float64)pair_count;
    print("Average of % pairs: %\n", pair_count, average);

}

arg_parse_flags :: Argument_Flags.FREE_ARGUMENTS_ALLOWED | .ALIGN_HELP;
arg_parse_help_triggers :: string.["h", "help"];
Program_Args :: struct {
    mode: string;  @"?choose from {generate, compute, compute-binary, timing-summary}"
    count: s64;    @"?generator output instance count"
    input: string; @"?json input filename"
}
show_help_wrapper :: inline () {
    show_help(Program_Args, arg_parse_flags, arg_parse_help_triggers);
}

main :: () {
    success, args, is_set, free_args := parse_arguments(Program_Args, arg_parse_flags, arg_parse_help_triggers);
    if !success {
        exit(1);
    }

    profiler_begin();
    if args.mode == {
        case "compute";
            if !args.input.count {
                args.input = "haversine_input.json";
                print("'-input' not set, defaulting to '%'.\n", args.input);
            }
            compute_from_json(args.input);

        case "compute-binary";
            if !args.input.count {
                args.input = "haversine_reference.bin";
                print("-input not set, defaulting to '%'.\n", args.input);
            }
            compute_from_binary(args.input);

        case "generate";
            if args.count <= 0 {
                old_count := args.count;
                args.count = 10;
                print("invalid value for '-count': %. Using default: %.\n", old_count, args.count);
            }
            generate(cast(u64) args.count);

        case "timing-summary";
            report_timing_info();
            exit(0);

        case;
            print("invalid value for '-mode': '%'.\n", args.mode);
            show_help_wrapper();
            exit(1);
    }

    if args.mode == "compute" || args.mode == "compute-binary" {
        profiler_end_and_summarize();
    }

    #if REPORT_MEMORY_LEAKS
    {
        options: Leak_Report_Options;
        options.roots_to_skip = .[
            .{"main", ""},
        ];
        report_memory_leaks(*options);
    }
}
