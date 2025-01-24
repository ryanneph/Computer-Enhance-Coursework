#include <math.h>
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

}
