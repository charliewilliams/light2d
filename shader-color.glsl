
uniform float u_time;
uniform int u_samples;

#define shapeTexture sTD2DInputs[0] /// Shapes
#define emissiveTexture sTD2DInputs[1] /// Brightness etc of objects in scene
#define noiseTexture sTD2DInputs[2] /// noise texture for randomizing ray direction
#define sdfTexture sTD2DInputs[3]
#define colorTexture sTD2DInputs[4]
#define RES uTD2DInfos[0].res.zw

#define TWO_PI 6.28318530718f
#define EPSILON 1e-6f

#define N u_samples
// #define STEPS 10
#define MAX_DISTANCE (max(RES.x, RES.y) * 1.5)
#define BASIC_LIGHT 1.0f
#define MAX_STEP 10

#define LENGTH_SQ(dir) ((dir).x*(dir).x + (dir).y*(dir).y)

out vec4 fragColor;
out vec4 debugOut;

struct Result {
	float sd; // signed distance, i.e. how far are we from a shape? (negative means inside the shape)
	float emissive;
	float reflective;
	vec4 color; // includes opacity

	// Result() : sd(0), emissive(0), reflective(0), opacity(1), color(vec4(1)) {};
	// Result() : {}

	// Result(float _sd, float _emissive, float _reflective, float _opacity, vec4 _color) {
	// 	sd(_sd),
	// 	emissive(_emissive),
	// 	reflective(_reflective),
	// 	opacity(_opacity),
	// 	color(_color)
	// };
} result;

// float rand(vec2 co) {
//     return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
// }

vec4 readShape(vec2 xy) {
	return texelFetch(shapeTexture, ivec2(xy), 0);
}

float readEmissive(vec2 xy) {
	return texelFetch(emissiveTexture, ivec2(xy), 0).r;
}

float readSDF(vec2 xy) {
	return texelFetch(sdfTexture, ivec2(xy), 0).r;
}

vec4 readColor(vec2 xy) {
	return texelFetch(colorTexture, ivec2(xy), 0);
}

Result scene(vec2 xy) {

	Result result;
	result.sd = readSDF(xy);
	result.emissive = readEmissive(xy);
	result.color = readColor(xy);

	return result;
}

/// Ray march in a direction, adding up the light when we hit something
Result rayMarch(vec2 origin, vec2 direction) {

	Result result = {0, 0, 0, vec4(0)};

	float t = 0.001;

	for (int i = 0; i < MAX_STEP && t < MAX_DISTANCE; i++) {

		vec2 point = origin + direction * t;

		// If we don't check this the sides have a weird glow
		// which tbh looks nice
		if (point.x < 0 || point.y < 0 || point.x > RES.x || point.y > RES.y) {
			return result;
		}

		Result r = scene(point);

		/// calculate the distance from our pixel
		// float dist = LENGTH_SQ( point - origin );

		/// Add the emissiveness in this pixel
		result.emissive += r.emissive;// / sqrt(dist);
		result.color += r.color;

		/// Are we in a shape? Break...
		/// Otherwise internal points get infinite light
		/// TODO handle transparent shapes
		if (r.sd < EPSILON) { // && r.emissive > 0) {
			result.color = r.color;
			return result;
		}

		t += r.sd;
	}

	return result;
}

Result sampleXY() {

    Result result = {0, 0, 0, vec4(0)};

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
		Result r = rayMarch(vec2(x, y), vec2(cos(a), sin(a)));
		result.emissive += r.emissive / N;
		result.color += r.color / N;
    }

	// result.emissive /= N;
	// result.color /= N;
	// result.emissive /= 16;
	// result.color /= 16;
    return result;
}

void main()
{
	// debugOut = vec4(0);

	result = sampleXY();

	vec4 debug = vec4(vec3(result.color.rgb), 1);
	debugOut = TDOutputSwizzle(debug);
	
	vec4 color = vec4(vec3(result.emissive * result.color.rgb), 1);
	fragColor = TDOutputSwizzle(color);

	// debugOut = texelFetch(noiseTexture, ivec2(gl_FragCoord.xy), 0);

	// debugOut = texelFetch(colorTexture, ivec2(gl_FragCoord.xy), 0);
}
