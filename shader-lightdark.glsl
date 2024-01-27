
// Example Pixel Shader

uniform float u_time;
uniform int u_samples;
uniform bool ub_jitter;

#define MASK sTD2DInputs[0] /// SDF
#define NOISE sTD2DInputs[1] /// noise texture for randomizing ray direction
#define EMIT sTD2DInputs[2] /// Brightness etc of objects in scene
#define RES uTD2DInfos[0].res.zw

#define TWO_PI 6.28318530718f
#define EPSILON 1e-6f

#define N u_samples
#define STEPS 10
// #define MAX_DISTANCE 200
#define MAX_DISTANCE (max(RES.x, RES.y) * 1.5)
#define BASIC_LIGHT 1.0f
#define MAX_STEP 64

struct Result { 
	float sd; // signed distance, i.e. how far are we from a shape? (negative means inside the shape)
	float emissive;
};

Result unionOp(Result a, Result b) {
    return a.sd < b.sd ? a : b;
}

Result intersectOp(Result a, Result b) {
    Result r = a.sd > b.sd ? b : a;
    r.sd = a.sd > b.sd ? a.sd : b.sd;
    return r;
}

Result subtractOp(Result a, Result b) {
    Result r = a;
    r.sd = (a.sd > -b.sd) ? a.sd : -b.sd;
    return r;
}

Result complementOp(Result a) {
    a.sd = -a.sd;
    return a;
}

// Result scene(float x, float y) {
// #if 0
    // Result r1 = { 
	// 	circleSDF(x, y, 0.3f, 0.3f, 0.10f), 
	// 	2.0f 
	// 	};

    // Result r2 = { 
	// 	circleSDF(x, y, 0.3f, 0.7f, 0.05f),
	// 	0.8f 
	// 	};
    // Result r3 = { 
	// 	circleSDF(x, y, 0.7f, 0.5f, 0.10f), 
	// 	0.0f 
	// 	};
    // return unionOp(unionOp(r1, r2), r3);
// #else
    // Result a = { circleSDF(x, y, 0.4f, 0.5f, 0.20f), 1.0f };
    // Result b = { circleSDF(x, y, 0.6f, 0.5f, 0.20f), 0.8f };
    // return unionOp(a, b);
// #endif
// }

// float trace(float ox, float oy, float dx, float dy) {

//     float t = 0.001f;

//     for (int i = 0; i < MAX_STEP && t < MAX_DISTANCE; i++) {

//         Result r = scene(ox + dx * t, oy + dy * t);

//         if (r.sd < EPSILON)
//             return r.emissive;
//         t += r.sd;
//     }
//     return 0.0f;
// }

/// origin xy, direction xy
/// This needs to be in screen pixel coords
/// Here we are ray-tracing from our pixel in a random direction
/// so we can see how much light should be at that pixel.
float trace(float ox, float oy, float dx, float dy) {

    float t = 0.001f;

    for (int i = 0; i < MAX_STEP && t < MAX_DISTANCE; i++) {

		// Calculate distance to a shape by reading our SDF input
		float xpos = ox + dx * t;
		float ypos = oy + dy * t;

		// If we don't check this the sides have a weird glow
		// which tbh looks nice
		if (xpos < 0 || ypos < 0 || xpos > RES.x || ypos > RES.y) {
			return 0.0f;
		}

		float sd = texelFetch(MASK, ivec2(xpos, ypos), 0).r;
		float emissive = texelFetch(EMIT, ivec2(xpos, ypos), 0).g;

        if (sd < EPSILON) {
            return emissive;
		}
        t += sd;
	}
    return 0.0f;
}

/// Figure out the colour for this pixel in... 0-1 normalised position?
/// conversion of the function 'sample' in the original code
float sampleXY() {

    float sum = 0.0f;

	float x = gl_FragCoord.x;
	float y = gl_FragCoord.y;

    for (int i = 0; i < N; i++) {

		/*
		For 0 to N, we get a random direction and trace out along that direction
		*/

		/// read noise from the texture in our coord
		float rand = texelFetch(NOISE, ivec2(x, y), 0).r;

		/// make a random direction from it
		float a = ub_jitter ? TWO_PI * (i + rand) / N : TWO_PI * i / N;
        
		/// call the trace function using OUR OWN COORD
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
