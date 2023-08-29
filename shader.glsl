
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
// #define MAX_DISTANCE (max(RES.x, RES.y) * 1.5)

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
