#include <x86intrin.h>

extern "C" {

double sqrt_intrinsic_cpp(double x) {
   __m128d input = _mm_set_sd(x);
   __m128d computed = _mm_sqrt_sd(input, input);
   double output = _mm_cvtsd_f64(computed);
   return output;
}

double sqrt_intrinsic_f32_precision_cpp(double x) {
   __m128d input = _mm_set_ss((float)x);
   __m128d computed = _mm_sqrt_ss(input);
   double output = _mm_cvtss_f32(computed);
   return output;
}

double sqrt_intrinsic_reciprocal_cpp(double x) {
   __m128d input = _mm_set_ss((float)x);
   __m128d computed = _mm_rsqrt_ss(input);
   computed = _mm_rcp_ss(computed);
   double output = _mm_cvtss_f32(computed);
   return output;
}

#define PI 3.141592653589793
double sin_quad_zero_to_pi(double input) {
   __m128d A = _mm_set_sd(-4.0 / (PI * PI));
   __m128d B = _mm_set_sd(4.0 / PI);
   __m128d x = _mm_set_sd(input);
   __m128d xsq = _mm_mul_sd(x, x);

   __m128d term1 = _mm_mul_sd(A, xsq);
   __m128d term2 = _mm_mul_sd(B, x);
   __m128 computed = _mm_add_sd(term1, term2);

   double result = _mm_cvtsd_f64(computed);
   return result;
}

}
