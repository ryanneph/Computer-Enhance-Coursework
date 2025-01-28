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
run_golden_test :: ($compute_proc: compute_proc_type, test_cases: []Test_Case, absolute_error_threshold: float64) -> Test_Result {
    error_count: u64;
    max_absolute_error := FLOAT64_MIN;

    for test: test_cases {
        computed: float64 = compute_proc(test.input);
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
        max_absolute_error
    };
    return result;
}

Sampling :: struct {
    first: float64;
    last: float64;
    count: u64;
}

run_approx_test :: ($compute_proc: compute_proc_type, golden_proc: compute_proc_type, domain: Sampling, absolute_error_threshold: float64)
    -> Test_Result
{
    using domain;
    result: Test_Result;

    if first < last && count > 0 {
        error_count: u64;
        max_absolute_error := FLOAT64_MIN;

        step_size := (last - first) / count;
        input := first;
        for 1..count+1 { // include last sample
            computed := compute_proc(input);
            expected := golden_proc(input);
            absolute_error := abs(computed - expected);
            if absolute_error >= absolute_error_threshold {
                error_count += 1;
            }
            max_absolute_error = max(max_absolute_error, absolute_error);

            input += step_size;
        }

        result = .{
            domain.count+1,
            error_count,
            max_absolute_error,
        };
    } else {
        print("ERROR: Invalid Sampling. Must have first < last and non-zero count: first=% last=% count=%\n", first, last, count);
    }

    return result;
}

approx_sin_stub :: (x: float64) -> float64 {
    result := x;
    return result;
}

approx_cos_stub :: (x: float64) -> float64 {
    result := x;
    return result;
}

approx_asin_stub :: (x: float64) -> float64 {
    result := x;
    return result;
}

approx_sqrt_stub :: (x: float64) -> float64 {
    result := x;
    return result;
}

print_header :: (builder: *String_Builder, format: string, args: ..Any) {
    print_to_builder(builder, "\n");

    before_length := builder_string_length(builder);
    print_to_builder(builder, format, ..args);
    header_length := builder_string_length(builder) - before_length;

    print_to_builder(builder, "\n");

    for 1..header_length  print_to_builder(builder, "-");
    print_to_builder(builder, "\n");
}

main :: () {
    absolute_error_threshold: float64 = 1.0E-12;

    //
    // Golden Tests
    //
    golden_results := struct { name: string; result: Test_Result; }.[
        .{"sin",  run_golden_test(sin,  sin_golden_tests,  absolute_error_threshold)},
        .{"cos",  run_golden_test(cos,  cos_golden_tests,  absolute_error_threshold)},
        .{"asin", run_golden_test(asin, asin_golden_tests, absolute_error_threshold)},
        .{"sqrt", run_golden_test(sqrt, sqrt_golden_tests, absolute_error_threshold)},
    ];

    //
    // Approximation Tests
    //
    approx_results := struct { name: string; result: Test_Result; }.[
        .{ "sin_stub", run_approx_test(approx_sin_stub, sin, .{-PI, PI, 64}, absolute_error_threshold)},
        .{ "cos_stub", run_approx_test(approx_cos_stub, cos, .{-PI/2, PI/2, 64}, absolute_error_threshold)},
        .{ "asin_stub", run_approx_test(approx_asin_stub, asin, .{0.0, 1.0, 64}, absolute_error_threshold)},
        .{ "sqrt_stub", run_approx_test(approx_sqrt_stub, sqrt, .{0.0, 1.0, 64}, absolute_error_threshold)},
    ];

    //
    // Print Results
    //
    format_float := *context.print_style.default_format_float;
    format_float.mode = .SHORTEST;
    format_float.trailing_width = 3;

    builder: String_Builder;

    print_header(*builder, "Golden Data Test Summary (error_threshold=%)", absolute_error_threshold);
    for golden_results {
        using it;
        using it.result;
        if test_count > 0 {
            print_to_builder(*builder, "- %: #errors=%/% max_absolute_error=%\n",
                name, error_count, test_count, max_absolute_error);
        } else {
            print_to_builder(*builder, "- %: no tests cases\n", name);
        }
    }

    print_header(*builder, "Approx. Test Summary (error_threshold=%)", absolute_error_threshold);
    for approx_results {
        using it;
        using it.result;
        print_to_builder(*builder, "- %: #errors=%/% max_absolute_error=%\n",
            name, error_count, test_count, max_absolute_error);
    }

    write_builder(*builder);
}
