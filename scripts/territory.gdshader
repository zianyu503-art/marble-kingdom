shader_type canvas_item;

// Parchment world map with kingdom territories: an additively weighted
// Voronoi diagram of the settlements, hatched and outlined in kingdom colour.

uniform vec2 map_size = vec2(1232.0, 720.0);
uniform int count = 0;
uniform vec2 pts[64];
uniform vec4 cols[64];
uniform float rads[64];
uniform float owners[64];

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 p = UV * map_size;
	vec3 paper = vec3(0.95, 0.87, 0.70);
	paper *= 0.88 + 0.16 * fbm(p * 0.008);
	paper -= 0.045 * fbm(p * 0.05 + 3.0);
	vec2 q = UV - 0.5;
	paper *= 1.0 - dot(q, q) * 0.55;
	vec2 g = abs(fract(p / 60.0 - 0.5) - 0.5) * 60.0;
	if (min(g.x, g.y) < 0.7) paper *= 0.96;

	// nearest settlement (distance minus its radius)
	float s1 = 1e9;
	int i1 = -1;
	for (int i = 0; i < 64; i++) {
		if (i >= count) break;
		float s = distance(p, pts[i]) - rads[i];
		if (s < s1) { s1 = s; i1 = i; }
	}
	if (i1 >= 0 && s1 < 0.0 && owners[i1] >= 0.0) {
		float o1 = owners[i1];
		float s2 = 1e9;
		for (int i = 0; i < 64; i++) {
			if (i >= count) break;
			if (abs(owners[i] - o1) < 0.5) continue;
			s2 = min(s2, distance(p, pts[i]) - rads[i]);
		}
		vec3 col = cols[i1].rgb;
		float wob = (fbm(p * 0.15) - 0.5) * 2.0;
		paper = mix(paper, col, 0.13);
		if (fract((p.x + p.y) / 10.0) < 0.16) paper = mix(paper, col, 0.32);
		float edge = min((s2 - s1) * 0.5, -s1);
		if (edge < 2.6 + wob) paper = mix(paper, col * 0.85, 0.95);
	}
	COLOR = vec4(paper, 1.0);
}
