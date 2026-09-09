#include <inttypes.h>
#include <memory.h>
#include <stdio.h>

typedef double f64;

static f64 SineRadiansC_MFTWP[12][11] =
{
    // NOTE(casey): This minimax coefficient table was donated by Demetri Spanos

    {},
    {},
    {0x1.fc4eac57b4a27p-1, -0x1.2b704cf682899p-3},
    {0x1.fff1d21fa9dedp-1, -0x1.53e2e5c7dd831p-3, 0x1.f2438d36d9dbbp-8},
    {0x1.ffffe07d31fe8p-1, -0x1.554f800fc5ea1p-3, 0x1.105d44e6222ap-7, -0x1.83b9725dff6e8p-13},
    {0x1.ffffffd25a681p-1, -0x1.555547ef5150bp-3, 0x1.110e7b396c557p-7, -0x1.9f6445023f795p-13, 0x1.5d38b56aee7f1p-19},
    {0x1.ffffffffd17d1p-1, -0x1.55555541759fap-3, 0x1.11110b74adb14p-7, -0x1.a017a8fe15033p-13, 0x1.716ba4fe56f6ep-19, -0x1.9a0e192a4e2cbp-26},
    {0x1.ffffffffffdcep-1, -0x1.5555555540b9bp-3, 0x1.111111090f0bcp-7, -0x1.a019fce979937p-13, 0x1.71dce5ace58d2p-19, -0x1.ae00fd733fe8dp-26, 0x1.52ace959bd023p-33},
    {0x1.fffffffffffffp-1, -0x1.5555555555469p-3, 0x1.111111110941dp-7, -0x1.a01a0199e0eb3p-13, 0x1.71de37e62aacap-19, -0x1.ae634d22bb47cp-26, 0x1.60e59ae00e00cp-33, -0x1.9ef5d594b342p-41},
    {0x1p0, -0x1.5555555555555p-3, 0x1.11111111110c9p-7, -0x1.a01a01a014eb6p-13, 0x1.71de3a52aab96p-19, -0x1.ae6454d960ac4p-26, 0x1.6123ce513b09fp-33, -0x1.ae43dc9bf8ba7p-41, 0x1.883c1c5deffbep-49},
    {0x1p0, -0x1.5555555555555p-3, 0x1.11111111110dcp-7, -0x1.a01a01a016ef6p-13, 0x1.71de3a53fa85cp-19, -0x1.ae6455b871494p-26, 0x1.612421756f93fp-33, -0x1.ae671378c3d43p-41, 0x1.90277dafc8ab9p-49, -0x1.78262e1f2709cp-58},
    {0x1p0, -0x1.5555555555555p-3, 0x1.11111111110dp-7, -0x1.a01a01a01559ap-13, 0x1.71de3a52ad36dp-19, -0x1.ae64549aa7ca9p-26, 0x1.612392f66fdcdp-33, -0x1.ae11556cad6c4p-41, 0x1.71744c339ad03p-49, 0x1.52947c90f8199p-55, -0x1.ff1898c107cfap-59},
};

void print_u64_table(void) {
   printf("SineRadiansC_MFTWP :: [11]u64.[\n");
   for (int i = 0; i < 12; i++) {
      if (i) printf("\n");
      printf("    .[");

      for (int j = 0; j < 11; j++) {
         double val = SineRadiansC_MFTWP[i][j];

         if (j) printf(", ");

         uint64_t bits;
         memcpy(&bits, &val, sizeof(bits));
         printf("0x%016" PRIx64, bits);
      }
      printf("],");
   }
   printf("\n];\n");
}

void print_f64_table(void) {
   printf("SineRadiansC_MFTWP :: [11]float64.[\n");
   for (int i = 0; i < 12; i++) {
      if (i) printf("\n");
      printf("    .[");

      for (int j = 0; j < 11; j++) {
         double val = SineRadiansC_MFTWP[i][j];

         if (j) printf(", ");

         printf("%32.24E", val);
      }
      printf("],");
   }
   printf("\n];\n");
}

int main() {
   print_u64_table();
   print_f64_table();

   return 0;
}
