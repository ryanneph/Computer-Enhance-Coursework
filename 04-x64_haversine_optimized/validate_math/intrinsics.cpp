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
double sinq_zero_to_halfpi_cpp(double input) {
   __m128d A = _mm_set_sd(-0.3357488673628103541807525733876701910953780492546723687387637750157263772845455);
   __m128d B = _mm_set_sd(1.164012859946630796034863328523423717191309716948615456152205566227330270901187);
   __m128d x = _mm_set_sd(input);
   __m128d xsq = _mm_mul_sd(x, x);

   __m128d term1 = _mm_mul_sd(A, xsq);
   __m128d term2 = _mm_mul_sd(B, x);
   __m128 computed = _mm_add_sd(term1, term2);

   double result = _mm_cvtsd_f64(computed);
   return result;
}

static double absf64(double x) {
   return x >= 0 ? x : -x;
}
double sinq_intrin_cpp(double x) {
   double halfpi = PI/2;
   double posx = absf64(x);
   double quartx = (posx > halfpi) ? (PI - posx) : posx;
   double result = sinq_zero_to_halfpi_cpp(quartx);
   result = (x < 0) ? -result : result;
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

double asin_intrin2_cpp(double x) {
   double result = 0;
   if (x != 0) {
      // ops: 6 (4 cheap, 2 expensive)
      //   mul:  2
      //   add:  2
      //   div:  1
      //   sqrt: 1
      result = (2/x) * (1 - sqrt_intrin_cpp(1 - x*x));
   }
   return result;
}

double asin_intrin3_cpp(double x) {
   double result = 0;
   if (x != 0) {
      // ops: 9 (7 cheap, 2 expensive)
      //   mul:  4
      //   add:  3
      //   div:  1
      //   sqrt: 1
      result = (PI/2.0) * (0.136*x + (1/x)*(1-sqrt_intrin_cpp(1-x*x)));
   }
   return result;
}

}
