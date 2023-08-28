#include "shared.h"

#define N 256
#define MAX_STEP 64
#define MAX_DISTANCE 5.0f
//#define MAX_DEPTH 3
//
//
//unsigned char img[W * H * 3];
//
//Result scene(float x, float y) {
//    Result a = { circleSDF(x, y, -0.2f, -0.2f, 0.1f), 10.0f, 0.0f, 0.0f, 0.0f };
//    Result b = {    boxSDF(x, y, 0.5f, 0.5f, 0.0f, 0.3, 0.2f), 0.0f, 0.2f, 1.5f, 4.0f };
//    return unionOp(a, b);
//}
//
//void gradient(float x, float y, float* nx, float* ny) {
//    *nx = (scene(x + EPSILON, y).sd - scene(x - EPSILON, y).sd) * (0.5f / EPSILON);
//    *ny = (scene(x, y + EPSILON).sd - scene(x, y - EPSILON).sd) * (0.5f / EPSILON);
//}
//
//float trace(float ox, float oy, float dx, float dy, int depth) {
//    float t = 1e-3f;
//    float sign = scene(ox, oy).sd > 0.0f ? 1.0f : -1.0f;
//    for (int i = 0; i < MAX_STEP && t < MAX_DISTANCE; i++) {
//        float x = ox + dx * t, y = oy + dy * t;
//        Result r = scene(x, y);
//        if (r.sd * sign < EPSILON) {
//            float sum = r.emissive;
//            if (depth < MAX_DEPTH && (r.reflectivity > 0.0f || r.eta > 0.0f)) {
//                float nx, ny, rx, ry, refl = r.reflectivity;
//                gradient(x, y, &nx, &ny);
//                float s = 1.0f / (nx * nx + ny * ny);
//                nx *= sign * s;
//                ny *= sign * s;
//                if (r.eta > 0.0f) {
//                    if (refract(dx, dy, nx, ny, sign < 0.0f ? r.eta : 1.0f / r.eta, &rx, &ry)) {
//                        float cosi = -(dx * nx + dy * ny);
//                        float cost = -(rx * nx + ry * ny);
//                        refl = sign < 0.0f ? fresnel(cosi, cost, r.eta, 1.0f) : fresnel(cosi, cost, 1.0f, r.eta);
//                        sum += (1.0f - refl) * trace(x - nx * BIAS, y - ny * BIAS, rx, ry, depth + 1);
//                    }
//                    else
//                        refl = 1.0f; // Total internal reflection
//                }
//                if (refl > 0.0f) {
//                    reflect(dx, dy, nx, ny, &rx, &ry);
//                    sum += refl * trace(x + nx * BIAS, y + ny * BIAS, rx, ry, depth + 1);
//                }
//            }
//            return sum * beerLambertF(r.absorption, t);
//        }
//        t += r.sd * sign;
//    }
//    return 0.0f;
//}
//
//float sample(float x, float y) {
//    float sum = 0.0f;
//    for (int i = 0; i < N; i++) {
//        float a = TWO_PI * (i + (float)rand() / RAND_MAX) / N;
//        sum += trace(x, y, cosf(a), sinf(a), 0);
//    }
//    return sum / N;
//}
//
//int beerLambertRender(void) {
//    unsigned char* p = img;
//    for (int y = 0; y < H; y++)
//        for (int x = 0; x < W; x++, p += 3)
//            p[0] = p[1] = p[2] = (int)(fminf(sample((float)x / W, (float)y / H) * 255.0f, 255.0f));
//    svpng(fopen("beerlambert.png", "wb"), W, H, img, 0);
//    return 0;
//}
