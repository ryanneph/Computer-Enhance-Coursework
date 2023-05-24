#import "Basic";
#import "File";
#import "Random";

Point_Pair :: struct {
    x0, y0: float64;
    x1, y1: float64;
}

generate_pairs :: (count: u64) -> [..]Point_Pair {
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

main :: () {
    pairs := generate_pairs(10);

    json_string := format_as_json(pairs, temporary_allocator);
    print("%\n", json_string);

    {
        output_file := "haversine_input.json";
        file, success := file_open(output_file, for_writing=true);
        assert(success);

        file_write(*file, json_string);
        file_close(*file);
    }
}
