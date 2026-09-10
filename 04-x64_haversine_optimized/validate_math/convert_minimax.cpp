#include <inttypes.h>
#include <memory.h>
#include <stdio.h>

typedef double f64;

void print_f64_table(const char *name, f64 *table, int max_order) {
   printf("%s : [%d][%d]float64 : .[\n", name, max_order, max_order-1);
   for (int i = 0; i < max_order; i++) {
      if (i) printf("\n");
      printf("    .[");

      for (int j = 0; j < max_order-1; j++) {
         f64 val = *(table + i*(max_order-1) + j);

         if (j) printf(", ");

#if 0
         uint64_t bits;
         memcpy(&bits, &val, sizeof(bits));
         printf("0x%016" PRIx64, bits);
#else
         printf("%0.17e", val);
#endif
      }
      printf("],");
   }
   printf("\n];\n");
}

#define ARRAY_SIZE(arr) (sizeof(arr) / sizeof(arr[0]))
#define PRINT_F64_TABLE(table)  print_f64_table(#table, (f64 *)table, ARRAY_SIZE(table))

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

static f64 ArcsineRadiansC_MFTWP[][22] =
{
    // NOTE(casey): This minimax coefficient table was donated by Demetri Spanos

    {},
    {},
    {0x1.fdfcefbdd3154p-1 , 0x1.c427597754a37p-3},
    {0x1.0019e5b9a7693p0, 0x1.3b5f83d579a47p-3, 0x1.0da162d6fae3dp-3},
    {0x1.fffa004bed736p-1, 0x1.5acaca323d3aep-3, 0x1.a52ade47d967dp-5, 0x1.b0931e5a07f25p-4},
    {0x1.0000609783343p0, 0x1.543eb056cd449p-3, 0x1.52db50c86c17fp-4, 0x1.c36707c70d21cp-8, 0x1.8faf3815344ddp-4},
    {0x1.ffffe6586d628p-1, 0x1.558b2dc0be61cp-3, 0x1.2a2202ec5cb8p-4, 0x1.f96fb970de571p-5, -0x1.ac22c3939a9a9p-6, 0x1.912219085f248p-4},
    {0x1.000001c517503p0, 0x1.554b23dabce0bp-3, 0x1.35948cff7046bp-4, 0x1.391ca703d0d07p-5, 0x1.03149c11e9277p-4, -0x1.e523c15fbf438p-5, 0x1.a906b64a9bdc7p-4},
    {0x1.ffffff7f5bbbcp-1, 0x1.55573c38fd397p-3, 0x1.329cc1329ab48p-4, 0x1.7f40be8459b49p-5, 0x1.ea3ebd68f4abp-7, 0x1.4b1dad0e7b7e5p-4, -0x1.912818d0401bfp-4, 0x1.d3ec796e5ec8bp-4},
    {0x1.00000009557b8p0, 0x1.5554fb74b4bffp-3, 0x1.3356afe11c66p-4, 0x1.685b6636af595p-5, 0x1.2c25059387c7ep-5, -0x1.5b983df09138p-7, 0x1.db45568eb9217p-4, -0x1.2c7c4453a9b3ep-3, 0x1.0903eea6d1357p-3},
    {0x1.fffffffd3e442p-1, 0x1.555565c9beb43p-3, 0x1.332b1eab3d6f2p-4, 0x1.6f3ed264eef28p-5, 0x1.cc5fc8ed87fdbp-6, 0x1.38c39ea555adep-5, -0x1.88322c8ce661fp-5, 0x1.656a2ea43451dp-3, -0x1.aed7e0dfdbd27p-3, 0x1.32de0e0b3820fp-3},
    {0x1.0000000034db9p0, 0x1.5555525723f64p-3, 0x1.3334fd1dd69f5p-4, 0x1.6d4c8c3659p-5, 0x1.fe5b240c320ebp-6, 0x1.0076fe3314273p-6, 0x1.b627b3be92bd4p-5, -0x1.ba657aa72abeep-4, 0x1.103aa8bb00a4ep-2, -0x1.2deb335977b56p-2, 0x1.699a7715830d2p-3},
    {0x1.ffffffffeff9dp-1, 0x1.555555dff5e06p-3, 0x1.3332d0221f548p-4, 0x1.6dd27e8c33d52p-5, 0x1.edd05e3dff008p-6, 0x1.992d0b8b03f01p-6, -0x1.ac779f1be0507p-13, 0x1.73bb5b359003ap-4, -0x1.a8326f2354f8ap-3, 0x1.9e1b8885f9661p-2, -0x1.a1b0aa236a282p-2, 0x1.b038b25a40e08p-3},
    {0x1.00000000013ap0, 0x1.5555553c5c8a7p-3, 0x1.33334839e1acap-4, 0x1.6dafeb7453ee6p-5, 0x1.f2f65baf85a8cp-6, 0x1.5f396c79d5687p-6, 0x1.9a8031b47fd85p-6, -0x1.cbd84d319158p-6, 0x1.53df7e2c17602p-3, -0x1.7a954b7cb46e6p-2, 0x1.38e97b1392a69p-1, -0x1.1eabdc3fe561ap-1, 0x1.056424720e768p-2},
    {0x1.ffffffffff9fp-1, 0x1.55555559d0d4p-3, 0x1.33332ecf01c13p-4, 0x1.6db88c4cfe8eap-5, 0x1.f17068ec7ac68p-6, 0x1.73b9408ccb9b1p-6, 0x1.d2a82629eb78ep-7, 0x1.1b4dda11bb1d2p-5, -0x1.5210c527bd7ep-4, 0x1.3a638b5965e45p-2, -0x1.4434b98838c1dp-1, 0x1.d52ccc09ba2cdp-1, -0x1.8792b45ef365ep-1, 0x1.3f5545e9e11eap-2},
    {0x1.0000000000079p0, 0x1.5555555487dd3p-3, 0x1.3333341adb0b8p-4, 0x1.6db67483a8f77p-5, 0x1.f1defdcf41a11p-6, 0x1.6ce213041c326p-6, 0x1.2f8bd23b33763p-6, 0x1.34a6d9f27428dp-8, 0x1.007f36ef69d66p-4, -0x1.850e0d65729e1p-3, 0x1.1f42350f23ccep-1, -0x1.0e0b5512f8d35p0, 0x1.5d065bf34c03ep0, -0x1.0a98c5604a5c6p0, 0x1.8978c6502660ap-2},
    {0x1.fffffffffffdap-1, 0x1.555555557a085p-3, 0x1.33333304070d3p-4, 0x1.6db6f35f4ac13p-5, 0x1.f1c0bdf8248f6p-6, 0x1.6f0e61397193p-6, 0x1.15740f26a5e24p-6, 0x1.24069344266aap-6, -0x1.c02ef74c5e655p-7, 0x1.07833aeac1562p-3, -0x1.97487ee8ceb5p-2, 0x1.0178f7f5c01bdp0, -0x1.b8b2ea879a2a5p0, 0x1.01ccfbe6e1f6ap1, -0x1.6a46d11c16386p0, 0x1.e86a774524862p-2},
    {0x1.0000000000003p0, 0x1.555555554ecb4p-3, 0x1.3333333cb4a27p-4, 0x1.6db6d5f669d29p-5, 0x1.f1c8c3485860bp-6, 0x1.6e64f7828f426p-6, 0x1.1ea1dc340da9p-6, 0x1.98123c756ff58p-7, 0x1.7a0c83f514b22p-6, -0x1.bd6eb7cdaf8e4p-5, 0x1.162743c14bf13p-2, -0x1.944c737b04ef5p-1, 0x1.c47bd23ee68a2p0, -0x1.61d1590acbbfp1, 0x1.7a6e0b194804dp1, -0x1.eba481b8f24dfp0, 0x1.311805d4c6d33p-1},
    {0x1.fffffffffffffp-1, 0x1.555555555683fp-3, 0x1.3333333148aa7p-4, 0x1.6db6dca9f82d4p-5, 0x1.f1c6b0ea300d7p-6, 0x1.6e96be6dbe49ep-6, 0x1.1b8cc838ee86ep-6, 0x1.dc086c5d99cdcp-7, 0x1.b1b8d27cd7e72p-8, 0x1.5565a3d3908b9p-5, -0x1.2ab04ba9012e3p-3, 0x1.224c4dbe13cbdp-1, -0x1.83633c76e4551p0, 0x1.86bbff2a6c7b6p1, -0x1.188f223fe5f34p2, 0x1.14672d35db97ep2, -0x1.4d84801ff1aa1p1, 0x1.7f820d52c2775p-1},
    {0x1p0, 0x1.555555555531ep-3, 0x1.3333333380df2p-4, 0x1.6db6db3184756p-5, 0x1.f1c73443a02f5p-6, 0x1.6e88ce94d1149p-6, 0x1.1c875d6c5323dp-6, 0x1.c37061f4e5f55p-7, 0x1.b8a33b8e380efp-7, -0x1.21438ccc95d62p-8, 0x1.69b370aad086ep-4, -0x1.57380bcd2890ep-2, 0x1.1fb54da575b22p0, -0x1.6067d334b4792p1, 0x1.4537ddde2d76dp2, -0x1.b06f523e74f33p2, 0x1.8bf4dadaf548cp2, -0x1.bec6daf74ed61p1, 0x1.dfc53682725cap-1},
    {0x1p0, 0x1.55555555555bap-3, 0x1.3333333323ebcp-4, 0x1.6db6db7adc18bp-5, 0x1.f1c716a8f3363p-6, 0x1.6e8c66fac48d5p-6, 0x1.1c3da3ac97e63p-6, 0x1.cbb180b74d85dp-7, 0x1.62b81445afbfdp-7, 0x1.050a65cdec399p-6, -0x1.018ae6d82506cp-5, 0x1.a361973086e84p-3, -0x1.7f8907c1978c3p-1, 0x1.1debe7d3f064p1, -0x1.411c99c675e12p2, 0x1.106a078008a9ap3, -0x1.500975aa37fb8p3, 0x1.1ea75d01d0debp3, -0x1.2ee507d6a1a5fp2, 0x1.3070aa6a5b88ep0},
    {0x1p0, 0x1.5555555555544p-3, 0x1.3333333336209p-4, 0x1.6db6db6aeb726p-5, 0x1.f1c71dcf049c4p-6, 0x1.6e8b6f8df785cp-6, 0x1.1c53c3234c54p-6, 0x1.c8eb3e8133ceap-7, 0x1.8335ee4136147p-7, 0x1.d9a5ff05f747ep-8, 0x1.b949ad43fb2bdp-6, -0x1.9080df821c302p-4, 0x1.e245cd46c886cp-2, -0x1.99434e2a3223ap0, 0x1.147d4d3b7ec76p2, -0x1.1e2a8ce097204p3, 0x1.c17aa6abf54eap3, -0x1.02778b2d86e57p4, 0x1.9ccd7e4c0706bp3, -0x1.9a13424bd53c2p2, 0x1.837ec3890fee1p0},
    {0x1p0, 0x1.5555555555558p-3, 0x1.3333333332aedp-4, 0x1.6db6db6e45234p-5, 0x1.f1c71c24301p-6, 0x1.6e8baf9ddc763p-6, 0x1.1c4d64d353371p-6, 0x1.c9cf1f8de89e6p-7, 0x1.778d723247697p-7, 0x1.5fcac651d07d4p-7, 0x1.799c2f33c0274p-12, 0x1.e288894a8bc33p-5, -0x1.0446ef7fdb149p-2, 0x1.0ba0fa7048fb2p0, -0x1.a273e0e74ee85p1, 0x1.034f776a3db58p3, -0x1.f1adf47b08719p3, 0x1.6c271c319b92ap4, -0x1.886f83ada1ccfp4, 0x1.26c247c3a321bp4, -0x1.146482ddd5f29p3, 0x1.ed3ada8793e41p0},
};

int main() {
   PRINT_F64_TABLE(SineRadiansC_MFTWP);
   PRINT_F64_TABLE(ArcsineRadiansC_MFTWP);

   return 0;
}
