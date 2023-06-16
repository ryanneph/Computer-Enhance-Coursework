#import "Basic";
#import "Command_Line";
#import "File";
#import "Math";
#import "Random";

#load "json.jai";
#load "timer.jai";

Program_Timing_Segment :: struct {
    desc: string;
    timer_elapsed: u64;

    percentage: float64;
}
program_timing: [..] Program_Timing_Segment;
add_program_timing_segment_elapsed :: (desc: string, timer_elapsed: u64) {
    segment: Program_Timing_Segment;
    segment.desc = desc;
    segment.timer_elapsed = timer_elapsed;

    array_add(*program_timing, segment);
}

Timer :: struct {
    start: u64;
    elapsed: u64;
}
timer_start :: inline (timer: *Timer) {
    timer.start = read_cpu_timer();
}
timer_stop :: inline (timer: *Timer) {
    timer_stop := read_cpu_timer();
    timer.elapsed += timer_stop - timer.start;
}

Point_Pair :: struct {
    x0, y0: float64;
    x1, y1: float64;
}

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
            distance: float64 = dists[it_index];

            WRITE(pair.x0);
            WRITE(pair.y0);
            WRITE(pair.x1);
            WRITE(pair.y1);
            WRITE(distance);
        }

        file_close(*file);
        print("Generated % pairs and saved to file '%'\n", pairs.count, output_file);
    }
}

compute :: (input_filename: string) {
    file_read_timer: Timer;
    json_parse_timer: Timer;
    json_navigate_timer: Timer;
    compute_timer: Timer;

    timer_start(*file_read_timer);
    json_string, read_success := read_entire_file(input_filename);
    assert(read_success);
    timer_stop(*file_read_timer);
    add_program_timing_segment_elapsed("read file", file_read_timer.elapsed);

    timer_start(*json_parse_timer);
    json_doc, success := parse_json(json_string);
    if !success {
        print("failed to parse json: '%'\n", input_filename);
        return;
    }
    timer_stop(*json_parse_timer);
    add_program_timing_segment_elapsed("parse json", json_parse_timer.elapsed);

    timer_start(*json_navigate_timer);
    assert(json_doc.root.type == .OBJECT);
    node, found := table_find(*(cast(*Json_Node_Object)json_doc.root).table, "pairs");
    assert(found);
    timer_stop(*json_navigate_timer);

    sum: float64 = 0.0;
    pairs_node := cast(*Json_Node_Array) node;
    for pairs_node.arr {
        assert(it.type == .OBJECT);
        pair_node := cast(*Json_Node_Object) it;

        get_member :: (member_name: string) -> float64 #expand {
            node, found := table_find(*pair_node.table, member_name);
            assert(found && node.type == .NUMBER);

            number_node := node;

            float_value, success := parse_float(*node.value_string);
            if !success {
                print("Error parsing float from string '%'.\n", node.value_string);
                float_value = 0.0;
            }

            return float_value;
        }

        timer_start(*json_navigate_timer);
        pair: Point_Pair;
        pair.x0 = get_member("x0");
        pair.y0 = get_member("y0");
        pair.x1 = get_member("x1");
        pair.y1 = get_member("y1");
        timer_stop(*json_navigate_timer);

        timer_start(*compute_timer);
        haversine_distance := reference_haversine(pair);
        sum += haversine_distance;
        timer_stop(*compute_timer);

        // print("Pair: % -> %\n", pair, haversine_distance);
    }

    add_program_timing_segment_elapsed("json navigation", json_navigate_timer.elapsed);
    add_program_timing_segment_elapsed("compute", compute_timer.elapsed);

    count := pairs_node.arr.count;
    average: float64 = sum / cast(float64)count;
    print("Average of % pairs: %\n", count, average);
}

arg_parse_flags :: Argument_Flags.FREE_ARGUMENTS_ALLOWED | .ALIGN_HELP;
arg_parse_help_triggers :: string.["h", "help"];
Program_Args :: struct {
    mode: string;  @"?choose from {generate, compute, timing-summary}"
    count: s64;    @"?generator output instance count"
    input: string; @"?json input filename"
}
show_help_wrapper :: inline () {
    show_help(Program_Args, arg_parse_flags, arg_parse_help_triggers);
}

summarize_program_timing :: () {
    total_elapsed: u64 = 0;
    for *program_timing
        total_elapsed += it.timer_elapsed;
    for *program_timing
        it.percentage = 100.0 * cast(float64) it.timer_elapsed / cast(float64) total_elapsed;

    print("Program Timing:\n");
    for program_timing {
        print("  - %: % ticks (%0%% of measured)\n", it.desc, it.timer_elapsed, it.percentage);
    }
}

main :: () {
    success, args, is_set, free_args := parse_arguments(Program_Args, arg_parse_flags, arg_parse_help_triggers);
    if !args.mode.count {
        print("Error: mode was not set.\n");
        show_help_wrapper();
        exit(1);
    }

    if args.mode == {
        case "compute";
            if !args.input.count {
                args.input = "haversine_input.json";
                print("'-input' not set, defaulting to '%'.\n", args.input);
            }
            compute(args.input);
            summarize_program_timing();

        case "generate";
            if args.count <= 0 {
                old_count := args.count;
                args.count = 10;
                print("invalid value for '-count': %. Using default: %.\n",
                    old_count, args.count);
            }
            generate(cast(u64) args.count);

        case "timing-summary";
            report_timing_info();
            exit(0);

        case;
            print("invalid value for '-mode': '%'.\n", args.mode);
            exit(1);
    }
}
