#include <x86intrin.h>

extern "C" {

double sqrt_intrinsic_cpp(double x) {
   __m128d input = _mm_set_sd(x);
   __m128d computed = _mm_sqrt_sd(input, input);
   double output = _mm_cvtsd_f64(computed);
   return output;
}

double sqrt_intrinsic_reciprocal_cpp(double x) {
   __m128d input = _mm_set_ss((float)x);
   __m128d computed;
   computed = _mm_rsqrt_ss(input);
   computed = _mm_rcp_ss(computed);
   double output = _mm_cvtss_f32(computed);
   return output;
}

}
