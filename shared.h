//
//  shared.h
//  light2d
//
//  Created by Charlie Williams on 28/08/2023.
//

#ifndef shared_h
#define shared_h

#include "svpng.inc"
#include <math.h> // fabsf(), fminf(), fmaxf(), sinf(), cosf(), sqrt()
#include <stdlib.h> // rand(), RAND_MAX

#define TWO_PI 6.28318530718f
#define W 512
#define H 512
#define EPSILON 1e-6f
#define BIAS 1e-4f
#define MAX_DEPTH 5
#define BLACK { 0.0f, 0.0f, 0.0f }

typedef struct { float r, g, b; } Color;
typedef struct { float sd, reflectivity, eta; Color emissive, absorption; } Result;

float circleSDF(float x, float y, float cx, float cy, float r) {
    
    float ux = x - cx;
    float uy = y - cy;
    
    return sqrtf(ux * ux + uy * uy) - r;
}

float planeSDF(float x, float y, float px, float py, float nx, float ny) {
    return (x - px) * nx + (y - py) * ny;
}

float boxSDF(float x, float y, float cx, float cy, float theta, float sx, float sy) {
    float costheta = cosf(theta), sintheta = sinf(theta);
    float dx = fabs((x - cx) * costheta + (y - cy) * sintheta) - sx;
    float dy = fabs((y - cy) * costheta - (x - cx) * sintheta) - sy;
    float ax = fmaxf(dx, 0.0f), ay = fmaxf(dy, 0.0f);
    return fminf(fmaxf(dx, dy), 0.0f) + sqrtf(ax * ax + ay * ay);
}

float ngonSDF(float x, float y, float cx, float cy, float r, float n) {
    float ux = x - cx, uy = y - cy, a = TWO_PI / n;
    float t = fmodf(atan2f(uy, ux) + TWO_PI, a), s = sqrtf(ux * ux + uy * uy);
    return planeSDF(s * cosf(t), s * sinf(t), r, 0.0f, cosf(a * 0.5f), sinf(a * 0.5f));
}

Color colorAdd(Color a, Color b) {
    Color c = { a.r + b.r, a.g + b.g, a.b + b.b };
    return c;
}

Color colorMultiply(Color a, Color b) {
    Color c = { a.r * b.r, a.g * b.g, a.b * b.b };
    return c;
}

Color colorScale(Color a, float s) {
    Color c = { a.r * s, a.g * s, a.b * s };
    return c;
}

Result unionOp(Result a, Result b) {
    return a.sd < b.sd ? a : b;
}

void reflect(float ix, float iy, float nx, float ny, float* rx, float* ry) {
    float idotn2 = (ix * nx + iy * ny) * 2.0f;
    *rx = ix - idotn2 * nx;
    *ry = iy - idotn2 * ny;
}

int refract(float ix, float iy, float nx, float ny, float eta, float* rx, float* ry) {
    float idotn = ix * nx + iy * ny;
    float k = 1.0f - eta * eta * (1.0f - idotn * idotn);
    if (k < 0.0f)
        return 0; // Total internal reflection
    float a = eta * idotn + sqrtf(k);
    *rx = eta * ix - a * nx;
    *ry = eta * iy - a * ny;
    return 1;
}

float fresnel(float cosi, float cost, float etai, float etat) {
    float rs = (etat * cosi - etai * cost) / (etat * cosi + etai * cost);
    float rp = (etai * cosi - etat * cost) / (etai * cosi + etat * cost);
    return (rs * rs + rp * rp) * 0.5f;
}

Color beerLambert(Color a, float d) {
    Color c = { expf(-a.r * d), expf(-a.g * d), expf(-a.b * d) };
    return c;
}

float beerLambertF(float a, float d) {
    return expf(-a * d);
}

#endif /* shared_h */
