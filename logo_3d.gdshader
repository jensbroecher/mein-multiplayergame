shader_type spatial;

// logo_3d.gdshader: the RC VIBE GP logo's one material (LogoBuilder.gd builds the meshes, regenerate_logo.gd
// the scene). The three tiers take their colour from different places, so none of the source JPEG's noise
// is in it:
//   rim   (UV2.x = 0)  the amber outline: a gradient by height, row 0 of logo_gradients.png
//   body  (UV2.x = 1)  the navy: a gradient by height, row 1
//   faces (UV2.x = 2)  the letters' colours, logo_faces.png (blurred without crossing an edge)
// UV is the vertex's place in the picture, so a lookup is the same whatever the tier or the letter's pivot.
// UV2.y is how far up a wall from where it meets the tier below (0 to 1): the foot is darker, which stands
// in for the occlusion there. A clearcoat over everything is what makes it look like glossy moulded plastic.

uniform sampler2D faces_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D gradients_tex : source_color, filter_linear, repeat_disable;
// The logo's top and bottom row, in UV.y, and the picture's width over its height.
uniform vec2 y_range = vec2(0.23, 0.83);
uniform float aspect = 1.835;

uniform float rim_rough : hint_range(0.0, 1.0) = 0.28;
uniform float body_rough : hint_range(0.0, 1.0) = 0.16;
uniform float face_rough : hint_range(0.0, 1.0) = 0.12;
uniform float clearcoat_amount : hint_range(0.0, 1.0) = 1.0;
uniform float clearcoat_rough : hint_range(0.0, 1.0) = 0.05;
// How the colour is shared between being lit (ALBEDO) and being given off (EMISSION): the picture is a flat
// sticker, and lit as plastic alone the navy goes black and the pale colours burn out under a key light.
// With `glow` of it self-lit the logo keeps its palette in any light, and the light and the clearcoat's
// reflections shape it. The gains set each tier's brightness (the navy is darker in the picture than it
// can afford to be here).
uniform float glow : hint_range(0.0, 1.0) = 0.45;
uniform float rim_gain = 0.85;
uniform float body_gain = 1.5;
uniform float face_gain = 1.0;
uniform float foot_dark : hint_range(0.0, 1.0) = 0.55;
// 0 = black, 1 = shown: the logo's fade in, per mesh so the tiers and the letters can arrive one at a time.
instance uniform float fade : hint_range(0.0, 1.0) = 1.0;

// A bright band sweeping across at a slant: its place from 0 (before the logo) to 1 (past it), under 0 or
// over 1 for none. `sheen_range` is the sweep coordinate (u * aspect + v * sheen_slant) at its two ends.
uniform float sheen = -1.0;
uniform float sheen_width = 0.045;
uniform float sheen_slant = 0.35;
uniform vec2 sheen_range = vec2(0.26, 1.95);
uniform vec3 sheen_color : source_color = vec3(1.0, 0.93, 0.80);
uniform float sheen_strength = 1.2;

void fragment() {
	int tier = int(UV2.x + 0.5);
	float t = clamp((UV.y - y_range.x) / (y_range.y - y_range.x), 0.0, 1.0);
	vec3 col;
	float rough;
	if (tier == 0) {
		col = texture(gradients_tex, vec2(t, 0.25)).rgb * rim_gain;
		rough = rim_rough;
	} else if (tier == 1) {
		col = texture(gradients_tex, vec2(t, 0.75)).rgb * body_gain;
		rough = body_rough;
	} else {
		col = texture(faces_tex, UV).rgb * face_gain;
		rough = face_rough;
	}
	float foot = mix(foot_dark, 1.0, smoothstep(0.0, 1.0, UV2.y));
	col *= foot * fade;
	ALBEDO = col * (1.0 - glow);
	ROUGHNESS = rough;
	METALLIC = 0.0;
	SPECULAR = 0.55;
	CLEARCOAT = clearcoat_amount;
	CLEARCOAT_ROUGHNESS = clearcoat_rough;
	vec3 glint = vec3(0.0);
	if (sheen >= 0.0 && sheen <= 1.0) {
		float s = ((UV.x * aspect + UV.y * sheen_slant) - sheen_range.x) / (sheen_range.y - sheen_range.x);
		float d = (s - sheen) / sheen_width;
		glint = sheen_color * exp(-d * d) * sheen_strength * (tier == 2 ? 1.0 : 0.55) * foot * fade;
	}
	EMISSION = col * glow + glint;
}
