#include "shared.h"

#define N 64
#define MAX_STEP 10
#define MAX_DISTANCE 2.0f

unsigned char img[W * H * 3];

static float trace(float ox, float oy, float dx, float dy) {
    float t = 0.0f;
    for (int i = 0; i < MAX_STEP && t < MAX_DISTANCE; i++) {
        float sd = circleSDF(ox + dx * t, oy + dy * t, 0.5f, 0.5f, 0.1f);
        if (sd < EPSILON)
            return 2.0f;
        t += sd;
    }
    return 0.0f;
}

float sample(float x, float y) {
    float sum = 0.0f;
    for (int i = 0; i < N; i++) {
        // float a = TWO_PI * rand() / RAND_MAX;
        // float a = TWO_PI * i / N;
        float a = TWO_PI * (i + (float)rand() / RAND_MAX) / N;
        sum += trace(x, y, cosf(a), sinf(a));
    }
    return sum / N;
}

int basic(void) {
    
    unsigned char* p = img;
    
    for (int y = 0; y < H; y++) {
        for (int x = 0; x < W; x++, p += 3) {
            
            float xpos = (float)x / W;
            float ypos = (float)y / H;
            float val = sample(xpos, ypos);
            float scaled = val * 255.0f;
            float clamped = fminf(scaled, 255.0f);
            int out = (int)clamped;
            
            p[0] = p[1] = p[2] = out;
            p[1] = 0;
        }
    }
    
    FILE *file = fopen("basic-cw2.png", "wb");
    svpng(file, W, H, img, 0);
    return 0;
}
