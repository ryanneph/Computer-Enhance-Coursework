#include <math.h>
#include "validate_math/intrinsics.cpp"

extern "C" {

struct Point_Pair {
   double x0, y0, x1, y1;
};

static inline double radians(double degrees) {
   double result = degrees * 0.01745329251994329577;
   return result;
}
static inline double square(double a) {
   double result = a * a;
   return result;
}

static double sin_(double x) {
   return sinq_intrin_cpp(x);
}

static double cos_(double x) {
   return cosq_intrin_cpp(x);
}

static double asin_(double x) {
   return asin_intrin3_cpp(x);
}

static double sqrt_(double x) {
   return sqrt_intrin_cpp(x);
}

double reference_haversine_cpp(Point_Pair pair, double earth_radius) {
   double lat0 = pair.y0;
   double lat1 = pair.y1;
   double lon0 = pair.x0;
   double lon1 = pair.x1;

   double dlat = radians(lat1 - lat0);
   double dlon = radians(lon1 - lon0);
   lat0 = radians(lat0);
   lat1 = radians(lat1);

   double a = square(sin(dlat / 2.0)) + cos(lat0) * cos(lat1) * square(sin(dlon / 2.0));
   double c = 2.0 * asin(sqrt(a));

   double result = earth_radius * c;
   return result;
}

double reference_haversine_approx_cpp(Point_Pair pair, double earth_radius) {
   double lat0 = pair.y0;
   double lat1 = pair.y1;
   double lon0 = pair.x0;
   double lon1 = pair.x1;

   double dlat = radians(lat1 - lat0);
   double dlon = radians(lon1 - lon0);
   lat0 = radians(lat0);
   lat1 = radians(lat1);

   double a = square(sin_(dlat / 2.0)) + cos_(lat0) * cos_(lat1) * square(sin_(dlon / 2.0));
   double c = 2.0 * asin_(sqrt_(a));

   double result = earth_radius * c;
   return result;
}

}
