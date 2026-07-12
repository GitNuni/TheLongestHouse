shader_type canvas_item;

// Full-screen bodycam treatment: grain, scanlines, vignette, slight barrel
// distortion and chromatic fringing — plus two possession/glitch channels
// the game drives from GDScript:
//   static_amount — signal-loss noise (teleports, damage, death)
//   possession   — red drift when the player is not entirely themselves

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float grain_amount : hint_range(0.0, 1.0) = 0.12;
uniform float static_amount : hint_range(0.0, 1.0) = 0.0;
uniform float possession : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 cc = uv - 0.5;

	// Cheap lens curvature — bodycams are wide and slightly fish-eyed.
	uv = uv + cc * dot(cc, cc) * 0.07;

	// Horizontal band tearing during signal loss.
	if (static_amount > 0.001) {
		float band = hash(vec2(floor(uv.y * 60.0), floor(TIME * 40.0)));
		uv.x += (band - 0.5) * 0.25 * static_amount;
	}

	// Possession: the image itself refuses to sit still.
	uv.x += sin(uv.y * 30.0 + TIME * 3.0) * 0.004 * possession;

	float ca = 0.0012 + 0.004 * possession + 0.005 * static_amount;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(ca, 0.0)).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - vec2(ca, 0.0)).b;

	// Animated grain — the one honest texture in the whole game.
	float g = hash(uv * vec2(1920.0, 1080.0) + vec2(TIME * 61.0, TIME * 83.0));
	col += (g - 0.5) * grain_amount;
	col = mix(col, vec3(g), static_amount * 0.85);

	// Scanlines + vignette.
	col *= 1.0 - 0.07 * sin(uv.y * 800.0);
	float vig = smoothstep(0.95, 0.35, length(cc));
	col *= mix(0.55, 1.0, vig);

	// Possession grade: everything warm dies except red.
	col = mix(col, vec3(col.r * 1.15, col.g * 0.22, col.b * 0.22), possession * 0.7);

	COLOR = vec4(col, 1.0);
}
