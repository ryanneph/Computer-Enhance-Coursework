#include <x86intrin.h>

extern "C" {

double sqrt_intrin_cpp(double x) {
   __m128d input = _mm_set_sd(x);
   __m128d computed = _mm_sqrt_sd(input, input);
   double output = _mm_cvtsd_f64(computed);
   return output;
}

double sqrt_intrin_f32_cpp(double x) {
   __m128d input = _mm_set_ss((float)x);
   __m128d computed = _mm_sqrt_ss(input);
   double output = _mm_cvtss_f32(computed);
   return output;
}

double sqrt_intrin_rcp_cpp(double x) {
   __m128d input = _mm_set_ss((float)x);
   __m128d computed = _mm_rsqrt_ss(input);
   computed = _mm_rcp_ss(computed);
   double output = _mm_cvtss_f32(computed);
   return output;
}

#define PI 3.141592653589793
double sinq_zero_to_pi_cpp(double input) {
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

double sinq_intrin_cpp(double x) {
   double sign = 1.0;
   if (x < 0) {
      x = -x;
      sign = -1.0;
   }

   double result = sign * sinq_zero_to_pi_cpp(x);
   return result;
}

double cosq_intrin_cpp(double x) {
   x = x + (PI / 2.0);
   double result = sinq_intrin_cpp(x);
   return result;
}

double asin_intrin1_cpp(double input) {
   // ops: 5 (4 cheap + 1 expensive)
   //   mul: 3
   //   add: 1
   //   div: 1
   double x = input;
   double result = x + (1.0/6.0) * (x*x*x);
   return result;
}

double asin_intrin2_cpp(double input) {
   // ops: 6 (4 cheap, 2 expensive)
   //   mul:  2
   //   add:  2
   //   div:  1
   //   sqrt: 1
   double x = input;
   double result = (2/x) * (1 - sqrt_intrin_cpp(1 - x*x));
   return result;
}

double asin_intrin3_cpp(double input) {
   // ops: 9 (7 cheap, 2 expensive)
   //   mul:  4
   //   add:  3
   //   div:  1
   //   sqrt: 1
   double x = input;
   double result = (PI/2.0) * (0.136*x + (1/x)*(1-sqrt_intrin_cpp(1-x*x)));
   return result;
}

}
