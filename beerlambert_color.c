
#include "shared.h"

#define N 256
#define MAX_STEP 64
#define MAX_DISTANCE 5.0f

unsigned char img[W * H * 3];

typedef struct { float r, g, b; } Color;
typedef struct { float sd, reflectivity, eta; Color emissive, absorption; } Result;

Result scene(float x, float y) {
    
    /// Bright emissive circle above the centre of the image
    Result a = {
        circleSDF(x, y, 0.5f, -0.2f, 0.1f), // sd
        0.0f, // reflectivity
        0.0f, // eta
        { 10.0f, 10.0f, 10.0f }, // emissive
        BLACK // absorption
    };
    
    /// Transparent, non-reflective n-gon in the middle of the screen
    Result b = {
        ngonSDF(x, y, 0.5f, 0.5f, 0.25f, 5.0f),
        0.0f,
        1.5f,
        BLACK,
        { 4.0f, 4.0f, 1.0f}
    };
    
    return unionOp(a, b);
}

void gradient(float x, float y, float* nx, float* ny) {
    *nx = (scene(x + EPSILON, y).sd - scene(x - EPSILON, y).sd) * (0.5f / EPSILON);
    *ny = (scene(x, y + EPSILON).sd - scene(x, y - EPSILON).sd) * (0.5f / EPSILON);
}

Color trace(float ox, float oy, float dx, float dy, int depth) {
    float t = 1e-3f;
    float sign = scene(ox, oy).sd > 0.0f ? 1.0f : -1.0f;
    for (int i = 0; i < MAX_STEP && t < MAX_DISTANCE; i++) {
        float x = ox + dx * t, y = oy + dy * t;
        Result r = scene(x, y);
        if (r.sd * sign < EPSILON) {
            Color sum = r.emissive;
            if (depth < MAX_DEPTH && r.eta > 0.0f) {
                float nx, ny, rx, ry, refl = r.reflectivity;
                gradient(x, y, &nx, &ny);
                float s = 1.0f / (nx * nx + ny * ny);
                nx *= sign * s;
                ny *= sign * s;
                if (r.eta > 0.0f) {
                    if (refract(dx, dy, nx, ny, sign < 0.0f ? r.eta : 1.0f / r.eta, &rx, &ry)) {
                        float cosi = -(dx * nx + dy * ny);
                        float cost = -(rx * nx + ry * ny);
                        refl = sign < 0.0f ? fresnel(cosi, cost, r.eta, 1.0f) : fresnel(cosi, cost, 1.0f, r.eta);
                        refl = fmaxf(fminf(refl, 1.0f), 0.0f);
                        sum = colorAdd(sum, colorScale(trace(x - nx * BIAS, y - ny * BIAS, rx, ry, depth + 1), 1.0f - refl));
                    }
                    else
                        refl = 1.0f; // Total internal reflection
                }
                if (refl > 0.0f) {
                    reflect(dx, dy, nx, ny, &rx, &ry);
                    sum = colorAdd(sum, colorScale(trace(x + nx * BIAS, y + ny * BIAS, rx, ry, depth + 1), refl));
                }
            }
            return colorMultiply(sum, beerLambert(r.absorption, t));
        }
        t += r.sd * sign;
    }
    Color black = BLACK;
    return black;
}

Color sample(float x, float y) {
    Color sum = BLACK;
    for (int i = 0; i < N; i++) {
        float a = TWO_PI * (i + (float)rand() / RAND_MAX) / N;
        sum = colorAdd(sum, trace(x, y, cosf(a), sinf(a), 0));
    }
    return colorScale(sum, 1.0f / N);
}

int beerLambertColorRender(void) {
    unsigned char* p = img;
    for (int y = 0; y < H; y++)
        for (int x = 0; x < W; x++, p += 3) {
            Color c = sample((float)x / W, (float)y / H);
            p[0] = (int)(fminf(c.r * 255.0f, 255.0f));
            p[1] = (int)(fminf(c.g * 255.0f, 255.0f));
            p[2] = (int)(fminf(c.b * 255.0f, 255.0f));
        }
    svpng(fopen("beerlambert_color.png", "wb"), W, H, img, 0);
    return 0;
}
