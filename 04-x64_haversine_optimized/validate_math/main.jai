#import "Basic";
#import "Math";

#load "golden_data.jai";

Test_Case :: struct {
    input: float64;
    expected: float64;
}

Test_Result :: struct {
    test_count: u64;
    error_count: u64;
    max_absolute_error: float64;
}

compute_proc_type :: #type (float64) -> float64;
run_tests :: ($compute_proc: compute_proc_type, test_cases: []Test_Case, absolute_error_threshold: float64) -> Test_Result {
    error_count: u64;

    max_absolute_error := FLOAT64_MIN;
    for test: test_cases {
        computed: float64 = xx compute_proc(test.input);
        absolute_error := abs(computed - test.expected);
        // print("computed=%, expected=%, absolute_error: %\n", computed, test.expected, absolute_error);
        if absolute_error >= absolute_error_threshold {
            error_count += 1;
        }
        max_absolute_error = max(max_absolute_error, absolute_error);
    }

    result := Test_Result.{
        xx test_cases.count,
        error_count,
        max_absolute_error};
    return result;
}

main :: () {
    absolute_error_threshold: float64 = 1.0E-12;
    results := struct { name: string; result: Test_Result; }.[
        .{"sin", run_tests(sin, sin_tests, absolute_error_threshold)},
        .{"cos", run_tests(cos, cos_tests, absolute_error_threshold)},
        .{"asin", run_tests(asin, asin_tests, absolute_error_threshold)},
        .{"sqrt", run_tests(sqrt, sqrt_tests, absolute_error_threshold)},
    ];

    //
    // Print Results
    //
    format_float := *context.print_style.default_format_float;
    format_float.mode = .SHORTEST;
    format_float.trailing_width = 3;

    builder: String_Builder;

    before_length := builder_string_length(*builder);
    print_to_builder(*builder, "Golden Data Test Summary (error_threshold=%)", absolute_error_threshold);
    header_length := builder_string_length(*builder) - before_length;
    print_to_builder(*builder, "\n");

    for 1..header_length  print_to_builder(*builder, "-");
    print_to_builder(*builder, "\n");

    for results {
        using it;
        using it.result;
        if test_count > 0 {
            print_to_builder(*builder, "- %: #errors=%/% max_absolute_error=%\n",
                name, error_count, test_count, max_absolute_error);
        } else {
            print_to_builder(*builder, "- %: no tests cases\n", name);
        }
    }

    write_builder(*builder);
}
