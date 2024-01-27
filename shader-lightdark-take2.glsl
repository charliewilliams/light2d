
#define shapeTexture sTD2DInputs[0] /// Shapes
#define emissiveTexture sTD2DInputs[1] /// Brightness etc of objects in scene
#define noiseTexture sTD2DInputs[2] /// noise texture for randomizing ray direction
#define sdfTexture sTD2DInputs[3]
#define RES uTD2DInfos[0].res.zw

#define TWO_PI 6.28318530718f
#define EPSILON 1e-6f

#define N 64
// #define STEPS 10
#define MAX_DISTANCE (max(RES.x, RES.y) * 1.5)
#define BASIC_LIGHT 1.0f
#define MAX_STEP 64

#define LENGTH_SQ(dir) ((dir).x*(dir).x + (dir).y*(dir).y)

out vec4 fragColor;
out vec4 debugOut;

struct Result {
	float sd; // signed distance, i.e. how far are we from a shape? (negative means inside the shape)
	float emissive;
	vec4 color;
};

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 readShape(vec2 xy) {
	return texelFetch(shapeTexture, ivec2(xy), 0);
}

float readEmissive(vec2 xy) {
	return texelFetch(emissiveTexture, ivec2(xy), 0).r;
}

float readSDF(vec2 xy) {
	return texelFetch(sdfTexture, ivec2(xy), 0).r;
}

Result scene(vec2 xy) {

	Result result;
	result.sd = readSDF(xy);
	result.emissive = readEmissive(xy);
	result.color = readShape(xy);

	return result;
}

/// Ray march in a direction, adding up the light when we hit something
Result rayMarch(vec2 origin, vec2 direction) {

	Result result = Result(0, 0, vec4(0));

	float t = 0.001;

	for (int i = 0; i < MAX_STEP && t < MAX_DISTANCE; i++) {

		vec2 point = origin + direction * t;

		Result r = scene(point);

		/// calculate the distance from our pixel
		// float dist = LENGTH_SQ( point - origin );

		/// Add the emissiveness in this pixel
		result.emissive += r.emissive;// / sqrt(dist);

		/// Are we in a shape? Break...
		/// Otherwise internal points get infinite light
		/// TODO handle transparent shapes
		if (r.sd < EPSILON && r.emissive > 0) {
			return result;
		}

		t += r.sd;
	}

	return result;
}

Result sampleXY() {

    Result result = Result(0, 0, vec4(0));

	float x = gl_FragCoord.x;
	float y = gl_FragCoord.y;

    for (int i = 0; i < N; i++) {

		/*
		For 0 to N, we get a random direction and trace out along that direction
		*/

		/// read noise from the texture in our coord
		float randNum = texelFetch(noiseTexture, ivec2(x, y), 0).r;

		/// make a random direction from it
		float a = TWO_PI * (i + randNum) / N;
        
		/// call the trace function using OUR OWN COORD
		result.emissive += rayMarch(vec2(x, y), vec2(cos(a), sin(a))).emissive;
    }

	result.emissive /= N / 4;
    return result;
}

void main()
{
	debugOut = vec4(0);

	Result result = sampleXY();
	
	vec4 color = vec4(vec3(result.emissive), 1);
	fragColor = TDOutputSwizzle(color);

	// debugOut = texelFetch(noiseTexture, ivec2(gl_FragCoord.xy), 0);
}
