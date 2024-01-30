
uniform float u_time;
uniform int u_samples;
uniform bool ub_jitter;

#define MASK sTD2DInputs[0]
#define NOISE sTD2DInputs[1]
#define RES uTD2DInfos[0].res.zw
#define TWO_PI 6.28318530718f
#define EPSILON 1e-6f

#define N u_samples
#define STEPS 10
#define MAX_DISTANCE 200.0f
#define BASIC_LIGHT 1.f;
#define BLACK vec3(0)

#define MAX_STEP 64
#define MAX_DEPTH 5
#define BIAS 1e-4f

struct Result { 
	float sd;
	float reflectivity;
	float eta; 
	vec3 emissive;
	vec3 absorption; 
};

struct Refraction {
	bool result; // did it refract out?
	vec2 xy;
};

Result unionOp(Result a, Result b) {
    return a.sd < b.sd ? a : b;
}

vec3 colorScale(vec3 a, float s) {
    return a * s;
}

/// SDF in this shader for debugging
float circleSDF(float x, float y, float cx, float cy, float r) {

    float ux = x - cx;
    float uy = y - cy;

    return sqrt(ux * ux + uy * uy) - r;
}

float planeSDF(float x, float y, float px, float py, float nx, float ny) {
    return (x - px) * nx + (y - py) * ny;
}

float ngonSDF(float x, float y, float cx, float cy, float r, float n) {

    float ux = x - cx, uy = y - cy, a = TWO_PI / n;
    float t = mod(atan(uy, ux) + TWO_PI, a);
    float s = sqrt(ux * ux + uy * uy);

    return planeSDF(s * cos(t), s * sin(t), r, 0, cos(a * 0.5), sin(a * 0.5));
}

Result scene(float x, float y) {

    Result a = {
        circleSDF(x, y, 0.5, -0.2, 0.1),
        0,
        0,
        vec3(10),
        vec3(0)
    };

    Result b = {
        ngonSDF(x, y, 0.5, 0.5, 0.25, 5),
        0,
        1.5,
        vec3(0),
        vec3(4, 4, 1)
    };

    return unionOp(a, b);
}
///

vec2 reflect(float ix, float iy, float nx, float ny) {
    float idotn2 = (ix * nx + iy * ny) * 2.0f;

	return vec2(ix - idotn2 * nx,iy - idotn2 * ny);
}

Refraction refract(float ix, float iy, float nx, float ny, float eta) {
    float idotn = ix * nx + iy * ny;
    float k = 1.0f - eta * eta * (1.0f - idotn * idotn);
    if (k < 0.0f) {
        return Refraction(false, vec2(0)); // Total internal reflection
	}
    float a = eta * idotn + sqrt(k);
    float rx = eta * ix - a * nx;
    float ry = eta * iy - a * ny;
    return Refraction(true, vec2(rx, ry));
}

float fresnel(float cosi, float cost, float etai, float etat) {
    float rs = (etat * cosi - etai * cost) / (etat * cosi + etai * cost);
    float rp = (etai * cosi - etat * cost) / (etai * cosi + etat * cost);
    return (rs * rs + rp * rp) * 0.5f;
}

vec3 beerLambert(vec3 a, float d) {
    return vec3(exp(-a.r * d), exp(-a.g * d), exp(-a.b * d));
}

float beerLambertF(float a, float d) {
    return exp(-a * d);
}

// vec2 gradient(float x, float y) {

// 	float xp = texelFetch(MASK, ivec2(x + EPSILON, y), 0).r;
// 	float xm = texelFetch(MASK, ivec2(x - EPSILON, y), 0).r;
// 	float nx = (xp - xm) * (0.5f / EPSILON);

// 	float yp = texelFetch(MASK, ivec2(x, y + EPSILON), 0).r;
// 	float ym = texelFetch(MASK, ivec2(x, y - EPSILON), 0).r;
// 	float ny = (yp - ym) * (0.5f / EPSILON);

// 	return vec2(nx, ny);
// }

vec2 gradient(float x, float y) {

    float nx = (scene(x + EPSILON, y).sd - scene(x - EPSILON, y).sd) * (0.5 / EPSILON);
    float ny = (scene(x, y + EPSILON).sd - scene(x, y - EPSILON).sd) * (0.5 / EPSILON);

    return vec2(nx, ny);
}

// ox oy in screen pixel coords
vec3 trace(float ox, float oy, float dx, float dy, int depth) {

    float t = 1e-3f;

	// float sign = texelFetch(MASK, ivec2(ox, oy), 0).r > 0.0f ? 1.0f : -1.0f;
    float sign = scene(ox, oy).sd > 0 ? 1 : -1;

    for (int i = 0; i < MAX_STEP && t < MAX_DISTANCE; i++) {

        float x = ox + dx * t, y = oy + dy * t;

        Result r = scene(x, y);
		
        if (r.sd * sign < EPSILON) {

            vec3 sum = r.emissive;

            if (depth < MAX_DEPTH && r.eta > 0.0f) {

                float rx, ry, refl = r.reflectivity;
                vec2 nxy = gradient(x, y);
                float nx = nxy.x;
                float ny = nxy.y;
                float s = 1.0f / (nx * nx + ny * ny);
                nx *= sign * s;
                ny *= sign * s;

                if (r.eta > 0.0f) {

                    Refraction rxy = refract(dx, dy, nx, ny, sign < 0.0f ? r.eta : 1.0f / r.eta);

                    if (rxy.result) {

                        rx = rxy.xy.x;
                        ry = rxy.xy.y;

                        float cosi = -(dx * nx + dy * ny);
                        float cost = -(rx * nx + ry * ny);
                        refl = sign < 0.0f ? fresnel(cosi, cost, r.eta, 1.0f) : fresnel(cosi, cost, 1.0f, r.eta);
                        refl = max(min(refl, 1.0f), 0.0f);

                        //// ARGH GLSL can't do recursion!
                        // sum += trace(x - nx * BIAS, y - ny * BIAS, rx, ry, depth + 1) * (1.0f - refl);
                    }
                    else
                        refl = 1.0f; // Total internal reflection
                }
                if (refl > 0.0f) {

                    vec2 rxy = reflect(dx, dy, nx, ny);
                    rx = rxy.x;
                    ry = rxy.y;
                    // sum += trace(x + nx * BIAS, y + ny * BIAS, rx, ry, depth + 1) * refl;
                }
            }
            return sum * beerLambert(r.absorption, t);
        }
        t += r.sd * sign;
    }

    return BLACK;
}

/// origin xy, direction xy
/// I think this needs to be in screen pixel coords
// float trace(float ox, float oy, float dx, float dy) {

//     float t = 0.0f;

//     for (int i = 0; i < STEPS && t < MAX_DISTANCE; i++) {

// 		// Calculate distance to a shape by reading our SDF input
// 		float xpos = ox + dx * t;
// 		float ypos = oy + dy * t;

// 		// If we don't check this the sides have a weird glow
// 		// which tbh looks nice
// 		if (xpos < 0 || ypos < 0 || xpos > RES.x || ypos > RES.y) {
// 			return 0.0f;
// 		}

// 		float sd = texelFetch(MASK, ivec2(xpos, ypos), 0).r;

//         if (sd < EPSILON) {
//             return BASIC_LIGHT;
// 		}
//         t += sd;
// 	}
//     return 0.0f;
// }

/// Figure out the colour for this pixel in... screen coords
vec3 sampleXY() {

    vec3 sum = vec3(0);

	float x = gl_FragCoord.x;
	float y = gl_FragCoord.y;

    for (int i = 0; i < N; i++) {

		/*
		For 0 to N, we get a random direction and trace out along that direction
		*/

		float rand = texelFetch(NOISE, ivec2(x, y), 0).r;

		float a = ub_jitter ? TWO_PI * (i + rand) / N : TWO_PI * i / N;
        sum += trace(x, y, cos(a), sin(a), 0);
    }
    // return sum;
    return sum / N;
}

out vec4 fragColor;
void main() {

	// vec2 pos = gl_FragCoord.xy / uTD2DInfos[0].res.zw;
	vec3 col = sampleXY();

	// float val = sampleXY(gl_FragCoord.x, gl_FragCoord.y);
	
	vec4 color = vec4(col, 1);
	fragColor = TDOutputSwizzle(color);
}
