shader_type canvas_item;

// The swipe between screens (ScreenTransition.gd): a navy panel sweeps in across the screen from the
// left on a slant, feathered along its edge, with a teal line at the leading edge. Held covered, it
// then sweeps away the same direction, an orange line along its trailing edge, and fades out as it
// goes. It is the colour of the loading screen, so the one hands over to the other unseen.

// How far the panel's leading edge has swept across: 0 = nothing covered, 1 = everything.
uniform float cover : hint_range(0.0, 1.0) = 0.0;
// How far its trailing edge has: 0 = still covering, 1 = all uncovered.
uniform float release : hint_range(0.0, 1.0) = 0.0;
// The panel's overall fade as it leaves.
uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform vec4 base_color : source_color = vec4(0.04, 0.05, 0.08, 1.0);
uniform vec4 lead_color : source_color = vec4(0.15, 0.75, 0.92, 1.0);
uniform vec4 trail_color : source_color = vec4(1.0, 0.55, 0.16, 1.0);
// How far the edge leans (in screen widths over screen heights) and how wide its feather is.
uniform float slant = 0.35;
uniform float feather = 0.24;

const float LINE_W = 0.007;

void fragment() {
	// Position across the sweep: 0 along the left edge, 1 at the far corner, leaning with y.
	float d = (UV.x + UV.y * slant) / (1.0 + slant);

	float lead = cover * (1.0 + feather) - feather;
	float trail = release * (1.0 + feather) - feather;
	float m_in = 1.0 - smoothstep(lead, lead + feather, d);
	float m_out = smoothstep(trail, trail + feather, d);
	float a = m_in * m_out * (1.0 - fade);

	// The lines ride the middle of each feather, only while their edge is on the move.
	float sweeping_in = step(0.001, cover) * (1.0 - step(0.999, cover));
	float sweeping_out = step(0.001, release) * (1.0 - step(0.999, release));
	float line_in = (1.0 - smoothstep(0.0, LINE_W, abs(d - (lead + feather * 0.5)))) * sweeping_in;
	float line_out = (1.0 - smoothstep(0.0, LINE_W, abs(d - (trail + feather * 0.5)))) * sweeping_out;

	// A little lighter where the panel is thin, so the feather reads as a glow rather than a smudge.
	vec3 col = base_color.rgb * (0.9 + 0.35 * (1.0 - a));
	col = mix(col, lead_color.rgb, line_in);
	col = mix(col, trail_color.rgb, line_out);
	COLOR = vec4(col, max(a, max(line_in, line_out) * (1.0 - fade)));
}
