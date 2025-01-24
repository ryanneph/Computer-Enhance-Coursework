#import "Math";

#import "memory_utils";

// FOREIGN FUNCTIONS
libhaversinecpp :: #library "libhaversinecpp";
reference_haversine_cpp :: (pair: Point_Pair, earth_radius: float64 = EARTH_RADIUS) -> float64 #foreign libhaversinecpp;

Haversine_Data :: struct {
    json_string: string;
    answer_buffer: string;

    pair_count: u64;
    pairs: *Point_Pair;
    answers: *float64;
    sum_answer: float64;

    parsed_byte_count: u64;
    is_valid: bool;
}

approx_equal :: (a: float64, b: float64, $epsilon: float64 = 1.0e-8) -> bool {
    difference := a - b;
    result := difference > -epsilon && difference < epsilon;
    return result;
}

EARTH_RADIUS :: 6372.8;
reference_haversine :: (pair: Point_Pair, earth_radius: float64 = EARTH_RADIUS) -> float64 {
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

reference_haversine_compute :: #bake_arguments haversine_compute(use_cpp=false);
reference_haversine_cpp_compute :: #bake_arguments haversine_compute(use_cpp=true);
haversine_compute :: (haversine: Haversine_Data, $use_cpp: bool = false) -> float64 {
    sum: float64;

    coefficient := 1.0 / cast(float64, haversine.pair_count);
    for 0..haversine.pair_count-1 {
        pair := haversine.pairs[it];
        computed: float64;
        #if use_cpp {
            computed = reference_haversine_cpp(pair, EARTH_RADIUS);
        } else {
            computed = reference_haversine(pair, EARTH_RADIUS);
        }
        sum += coefficient * computed;
    }

    return sum;
}

reference_haversine_validate :: #bake_arguments haversine_validate(use_cpp=false);
reference_haversine_cpp_validate :: #bake_arguments haversine_validate(use_cpp=true);
haversine_validate :: (haversine: Haversine_Data, $use_cpp: bool = false) -> u64 {
    error_count: u64;

    for 0..haversine.pair_count-1 {
        pair := haversine.pairs[it];
        answer := haversine.answers[it];
        computed: float64;
        #if use_cpp {
            computed = reference_haversine_cpp(pair, EARTH_RADIUS);
        } else {
            computed = reference_haversine(pair, EARTH_RADIUS);
        }
        if !approx_equal(computed, answer) {
            error_count += 1;
        }
    }

    return error_count;
}

load_haversine_data :: (json_filename: string, answer_filename: string) -> Haversine_Data {
    data: Haversine_Data;

    data.json_string   = Platform.read_full_file(json_filename);
    data.answer_buffer = Platform.read_full_file(answer_filename);

    min_json_pair_encoding: u64 : 16; // NOTE(ryan): there should be no way to define a pair in JSON without substantially more characters than this
    max_pair_count := cast(u64) data.json_string.count / min_json_pair_encoding;
    data.pairs = cast(*Point_Pair) alloc(xx max_pair_count * size_of(Point_Pair));

    if data.json_string.count > 0 && data.answer_buffer.count > 0 && data.pairs != null {
        data.pair_count = parse_json_pairs(data.json_string, max_pair_count, data.pairs);

        // binary format: (count:u64),(pair:f64,f64,f64,f64)*pair_count,(answer:f64)*pair_count,(sum_answer:f64)
        answer_count := (cast(u64, data.answer_buffer.count / size_of(float64)) - 1) / 5;
        if answer_count == data.pair_count {
            answers_offset := size_of(u64) + size_of(Point_Pair) * data.pair_count;
            data.answers = cast(*float64, data.answer_buffer.data + answers_offset);
            data.sum_answer = data.answers[data.pair_count];

            data.parsed_byte_count = cast(u64) size_of(Point_Pair) * data.pair_count;
            data.is_valid = data.pair_count > 0;

            print("Source JSON: %\n", pretty_print_byte_size(xx data.json_string.count));
            print("Parsed: % (% pairs)\n", pretty_print_byte_size(xx data.parsed_byte_count), data.pair_count);
        } else {
            print("ERROR: json has % pairs, but answer has % pairs. They must match.\n",
                data.pair_count, answer_count);
        }
    } else {
        print("ERROR: '%' empty or failed loading\n");
    }

    return data;
}

free_haversine_data :: (using data: Haversine_Data) {
    free(pairs);
    free(json_string.data);
    free(answer_buffer.data);
}

is_valid :: (using data: Haversine_Data) -> bool {
    result := is_valid;
    return result;
}
