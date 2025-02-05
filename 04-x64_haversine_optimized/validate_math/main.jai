#import "Basic";
#import "Math";

#load "golden_data.jai";
absolute_error_threshold: float64 : 1.0E-12;

Test_Case :: struct {
    input: float64;
    expected: float64;
}

Test_Result :: struct {
    test_count: u64;
    error_count: u64;
    max_absolute_error: float64;
    sampling: Sampling;
}

compute_proc_type :: #type (float64) -> float64;
run_golden_test :: ($compute_proc: compute_proc_type, test_cases: []Test_Case) -> Test_Result {
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
        max_absolute_error,
        .{},
    };
    return result;
}

Sampling :: struct {
    first: float64;
    last: float64;
    count: u64;
}

run_approx_test :: ($compute_proc: compute_proc_type, golden_proc: compute_proc_type, domain: Sampling)
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
            domain,
        };
    } else {
        print("ERROR: Invalid Sampling. Must have first < last and non-zero count: first=% last=% count=%\n", first, last, count);
    }

    return result;
}

libintrinsicscpp :: #library,no_dll "libintrinsicscpp";
sinq :: (input: float64) -> float64 {
    A: float64 : -4.0 / (PI64 * PI64);
    B: float64 : 4.0 / PI64;

    x := input;
    sign: float64 = 1.0;
    if x < 0 {
        x = -x;
        sign = -1.0;
    }

    result := sign * (A*x*x + B*x);
    return result;
}

bind_to_cpp :: (name: string) -> string #compile_time {
    format := #string END
        %1 :: (input: float64) -> float64 {
            proc :: (x: float64) -> float64 #foreign libintrinsicscpp "%1_cpp";
            result := proc(input);
            return result;
        }
    END
    return tprint(format, name);
}
#insert #run bind_to_cpp("sqrt_intrin");
#insert #run bind_to_cpp("sqrt_intrin_f32");
#insert #run bind_to_cpp("sqrt_intrin_rcp");
#insert #run bind_to_cpp("sinq_intrin");
#insert #run bind_to_cpp("cosq_intrin");
#insert #run bind_to_cpp("asin_intrin1");
#insert #run bind_to_cpp("asin_intrin2");
#insert #run bind_to_cpp("asin_intrin3");

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
    //
    // Golden Tests
    //
    golden_results := struct { name: string; result: Test_Result; }.[
        .{"sin",  run_golden_test(sin,  sin_golden_tests)},
        .{"cos",  run_golden_test(cos,  cos_golden_tests)},
        .{"asin", run_golden_test(asin, asin_golden_tests)},
        .{"sqrt", run_golden_test(sqrt, sqrt_golden_tests)},
    ];

    //
    // Approximation Tests
    //
    sample_count :: 1024;
    approx_results := struct { name: string; result: Test_Result; }.[
        .{"sinq_halfdomain", run_approx_test(sinq, sin, .{-PI, PI, sample_count})},
        .{"sinq_quartdomain_intrin", run_approx_test(sinq_intrin, sin, .{-PI, PI, sample_count})},
        .{"cosq_quartdomain_intrin", run_approx_test(cosq_intrin, cos, .{-PI/2, PI/2, sample_count})},

        .{"asin_intrin1", run_approx_test(asin_intrin1, asin, .{0.0, 1.0, sample_count})},
        .{"asin_intrin2", run_approx_test(asin_intrin2, asin, .{0.0, 1.0, sample_count})},
        .{"asin_intrin3", run_approx_test(asin_intrin3, asin, .{0.0, 1.0, sample_count})},

        .{"sqrt_intrin",     run_approx_test(sqrt_intrin,     sqrt, .{0.0, 1.0, sample_count})},
        .{"sqrt_intrin_f32", run_approx_test(sqrt_intrin_f32, sqrt, .{0.0, 1.0, sample_count})},
        .{"sqrt_intrin_rcp", run_approx_test(sqrt_intrin_rcp, sqrt, .{0.0, 1.0, sample_count})},
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
        if test_count > 0 {
            print_to_builder(*builder, "- % RANGE=[%, %]: #errors=%/% max_absolute_error=%\n",
                name, sampling.first, sampling.last, error_count, test_count, max_absolute_error);
        } else {
            print_to_builder(*builder, "- %: no tests cases\n", name);
        }
    }

    write_builder(*builder);
}
