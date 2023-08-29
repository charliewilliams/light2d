
// Example Pixel Shader

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

struct Result { 
	float sd;
	float reflectivity;
	float eta; 
	vec3 emissive;
	vec3 absorption; 
};

struct Refraction {
	int result; // did it refract out?
	vec2 xy;
};

Result unionOp(Result a, Result b) {
    return a.sd < b.sd ? a : b;
}

vec2 reflect(float ix, float iy, float nx, float ny) {
    float idotn2 = (ix * nx + iy * ny) * 2.0f;

	return vec2(ix - idotn2 * nx,iy - idotn2 * ny);
}

Refraction refract(float ix, float iy, float nx, float ny, float eta) {
    float idotn = ix * nx + iy * ny;
    float k = 1.0f - eta * eta * (1.0f - idotn * idotn);
    if (k < 0.0f) {
        return Refraction(0, vec2(0)); // Total internal reflection
	}
    float a = eta * idotn + sqrt(k);
    float rx = eta * ix - a * nx;
    float ry = eta * iy - a * ny;
    return Refraction(1, vec2(rx, ry));
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

vec2 gradient(float x, float y) {

	float xp = texelFetch(MASK, ivec2(x + EPSILON, y), 0).r;
	float xm = texelFetch(MASK, ivec2(x - EPSILON, y), 0).r;
	float nx = (xp - xm) * (0.5f / EPSILON);

	float yp = texelFetch(MASK, ivec2(x, y + EPSILON), 0).r;
	float ym = texelFetch(MASK, ivec2(x, y - EPSILON), 0).r;
	float ny = (yp - ym) * (0.5f / EPSILON);

	return vec2(nx, ny);
}

// ox oy in screen pixel coords
vec3 trace(float ox, float oy, float dx, float dy, int depth) {

    float t = 1e-3f;

	float sign = texelFetch(MASK, ivec2(ox, oy), 0).r > 0.0f ? 1.0f : -1.0f;

    for (int i = 0; i < MAX_STEP && t < MAX_DISTANCE; i++) {
        float x = ox + dx * t, y = oy + dy * t;
        Result r = scene(x, y);
        if (r.sd * sign < EPSILON) {
            vec3 sum = r.emissive;
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

    return BLACK;
}

/// origin xy, direction xy
/// I think this needs to be in screen pixel coords
float trace(float ox, float oy, float dx, float dy) {

    float t = 0.0f;

    for (int i = 0; i < STEPS && t < MAX_DISTANCE; i++) {

		// Calculate distance to a shape by reading our SDF input
		float xpos = ox + dx * t;
		float ypos = oy + dy * t;

		// If we don't check this the sides have a weird glow
		// which tbh looks nice
		if (xpos < 0 || ypos < 0 || xpos > RES.x || ypos > RES.y) {
			return 0.0f;
		}

		float sd = texelFetch(MASK, ivec2(xpos, ypos), 0).r;

        if (sd < EPSILON) {
            return BASIC_LIGHT;
		}
        t += sd;
	}
    return 0.0f;
}

/// Figure out the colour for this pixel in... 0-1 normalised position?
float sampleXY() {

    float sum = 0.0f;

	float x = gl_FragCoord.x;
	float y = gl_FragCoord.y;

    for (int i = 0; i < N; i++) {

		/*
		For 0 to N, we get a random direction and trace out along that direction
		*/

		float rand = texelFetch(NOISE, ivec2(x, y), 0).r;

		float a = ub_jitter ? TWO_PI * (i + rand) / N : TWO_PI * i / N;
        sum += trace(x, y, cos(a), sin(a));
    }
    return sum / N;
}

out vec4 fragColor;
void main() {

	// vec2 pos = gl_FragCoord.xy / uTD2DInfos[0].res.zw;

	// float val = sampleXY(pos.x, pos.y);

	/// Normalised 0-1 position of this pixel
	float val = sampleXY();

	// float val = sampleXY(gl_FragCoord.x, gl_FragCoord.y);
	
	vec4 color = vec4(vec3(val), 1);
	fragColor = TDOutputSwizzle(color);
}
