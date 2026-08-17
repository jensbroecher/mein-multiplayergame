shader_type spatial;
render_mode cull_back;

// --- Splatmap Settings ---
uniform sampler2D splatmap_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool use_world_splatmap = true;
uniform vec2 world_bounds_origin = vec2(-1000.0, -1000.0);
uniform vec2 world_bounds_size = vec2(2000.0, 2000.0);
uniform bool use_stochastic = true;

// --- Layer 0 (Base - e.g. Sand / Grass) ---
uniform sampler2D tex_base : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_base : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float uv_scale_base = 20.0;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.95;
uniform bool use_normal_base = false;
uniform sampler2D normal_base : hint_normal, filter_linear_mipmap_anisotropic;
uniform float normal_scale_base : hint_range(-16.0, 16.0) = 1.0;
uniform bool use_triplanar_base = true;

// --- Layer 1 (Red Channel - e.g. Rock / Cliff) ---
uniform sampler2D tex_layer1 : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_layer1 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float uv_scale_layer1 = 15.0;
uniform float roughness_layer1 : hint_range(0.0, 1.0) = 0.85;
uniform bool use_normal_layer1 = false;
uniform sampler2D normal_layer1 : hint_normal, filter_linear_mipmap_anisotropic;
uniform float normal_scale_layer1 : hint_range(-16.0, 16.0) = 1.0;
uniform bool use_triplanar_layer1 = true;

// --- Layer 2 (Green Channel - e.g. Dirt / Path) ---
uniform sampler2D tex_layer2 : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_layer2 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float uv_scale_layer2 = 20.0;
uniform float roughness_layer2 : hint_range(0.0, 1.0) = 0.90;
uniform bool use_normal_layer2 = false;
uniform sampler2D normal_layer2 : hint_normal, filter_linear_mipmap_anisotropic;
uniform float normal_scale_layer2 : hint_range(-16.0, 16.0) = 1.0;
uniform bool use_triplanar_layer2 = false;

// --- Layer 3 (Blue Channel - e.g. Cobblestone / Gravel) ---
uniform sampler2D tex_layer3 : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_layer3 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float uv_scale_layer3 = 20.0;
uniform float roughness_layer3 : hint_range(0.0, 1.0) = 0.90;
uniform bool use_normal_layer3 = false;
uniform sampler2D normal_layer3 : hint_normal, filter_linear_mipmap_anisotropic;
uniform float normal_scale_layer3 : hint_range(-16.0, 16.0) = 1.0;
uniform bool use_triplanar_layer3 = false;

// --- Edge Fade (Level Border Fog) ---
uniform bool enable_edge_fade = true;
uniform float edge_fade_start = 550.0;
uniform float edge_fade_end = 960.0;
uniform vec4 edge_fade_color : source_color = vec4(0.65, 0.75, 0.85, 1.0);

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// 2D Hash function
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

// Stochastic sampler to avoid repetitive grid tiling
vec3 sample_stochastic(sampler2D tex, vec2 uv, vec2 dx, vec2 dy) {
    vec2 p = floor(uv);
    vec2 f = fract(uv);
    vec3 res = vec3(0.0);
    float weight_sum = 0.0;

    for (int y = 0; y <= 1; y++) {
        for (int x = 0; x <= 1; x++) {
            vec2 offset = vec2(float(x), float(y));
            vec2 cell = p + offset;
            vec2 rand = hash2(cell);

            #ifdef GL_ES
            vec2 sampled_uv = f + rand.y;
            vec2 sampled_dx = dx;
            vec2 sampled_dy = dy;
            #else
            float angle = rand.x * 6.2831853;
            mat2 rot = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
            vec2 sampled_uv = rot * (f - vec2(0.5)) + vec2(0.5) + rand.y;
            vec2 sampled_dx = rot * dx;
            vec2 sampled_dy = rot * dy;
            #endif

            float w = pow(1.0 - smoothstep(0.0, 1.414, length(f - offset)), 2.0);
            res += textureGrad(tex, sampled_uv, sampled_dx, sampled_dy).rgb * w;
            weight_sum += w;
        }
    }
    return res / max(weight_sum, 0.0001);
}

// Stochastic normal map sampler
vec3 sample_stochastic_normal(sampler2D tex, vec2 uv, vec2 dx, vec2 dy) {
    vec2 p = floor(uv);
    vec2 f = fract(uv);
    vec3 res = vec3(0.0);
    float weight_sum = 0.0;

    for (int y = 0; y <= 1; y++) {
        for (int x = 0; x <= 1; x++) {
            vec2 offset = vec2(float(x), float(y));
            vec2 cell = p + offset;
            vec2 rand = hash2(cell);

            #ifdef GL_ES
            vec2 sampled_uv = f + rand.y;
            vec3 raw_normal = textureGrad(tex, sampled_uv, dx, dy).rgb * 2.0 - 1.0;
            vec3 rotated_normal = raw_normal;
            #else
            float angle = rand.x * 6.2831853;
            mat2 rot = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
            vec2 sampled_uv = rot * (f - vec2(0.5)) + vec2(0.5) + rand.y;
            vec2 sampled_dx = rot * dx;
            vec2 sampled_dy = rot * dy;
            vec3 raw_normal = textureGrad(tex, sampled_uv, sampled_dx, sampled_dy).rgb * 2.0 - 1.0;
            vec2 rotated_xy = rot * raw_normal.xy;
            vec3 rotated_normal = vec3(rotated_xy, raw_normal.z);
            #endif

            float w = pow(1.0 - smoothstep(0.0, 1.414, length(f - offset)), 2.0);
            res += rotated_normal * w;
            weight_sum += w;
        }
    }
    return (res / max(weight_sum, 0.0001)) * 0.5 + 0.5;
}

// Sample texture with optional stochastic / triplanar mapping
vec3 sample_layer(sampler2D tex, float uv_scale, bool is_triplanar, vec3 n_weight, vec2 mesh_uv) {
    if (is_triplanar) {
        vec2 scale_v = vec2(uv_scale * 0.01);
        vec2 uv_x = vec2(world_pos.z, world_pos.y) * scale_v;
        vec2 uv_y = vec2(world_pos.x, world_pos.z) * scale_v;
        vec2 uv_z = vec2(world_pos.x, world_pos.y) * scale_v;

        vec3 col_x, col_y, col_z;
        if (use_stochastic) {
            col_x = sample_stochastic(tex, uv_x, dFdx(uv_x), dFdy(uv_x));
            col_y = sample_stochastic(tex, uv_y, dFdx(uv_y), dFdy(uv_y));
            col_z = sample_stochastic(tex, uv_z, dFdx(uv_z), dFdy(uv_z));
        } else {
            col_x = texture(tex, uv_x).rgb;
            col_y = texture(tex, uv_y).rgb;
            col_z = texture(tex, uv_z).rgb;
        }
        return col_x * n_weight.x + col_y * n_weight.y + col_z * n_weight.z;
    } else {
        vec2 uv = (use_world_splatmap ? world_pos.xz : mesh_uv) * (uv_scale * 0.01);
        if (use_stochastic) {
            return sample_stochastic(tex, uv, dFdx(uv), dFdy(uv));
        } else {
            return texture(tex, uv).rgb;
        }
    }
}

// Sample normal map with optional stochastic / triplanar mapping
vec3 sample_layer_normal(sampler2D tex, float uv_scale, bool is_triplanar, vec3 n_weight, vec2 mesh_uv) {
    if (is_triplanar) {
        vec2 scale_v = vec2(uv_scale * 0.01);
        vec2 uv_x = vec2(world_pos.z, world_pos.y) * scale_v;
        vec2 uv_y = vec2(world_pos.x, world_pos.z) * scale_v;
        vec2 uv_z = vec2(world_pos.x, world_pos.y) * scale_v;

        vec3 n_x = sample_stochastic_normal(tex, uv_x, dFdx(uv_x), dFdy(uv_x));
        vec3 n_y = sample_stochastic_normal(tex, uv_y, dFdx(uv_y), dFdy(uv_y));
        vec3 n_z = sample_stochastic_normal(tex, uv_z, dFdx(uv_z), dFdy(uv_z));
        return n_x * n_weight.x + n_y * n_weight.y + n_z * n_weight.z;
    } else {
        vec2 uv = (use_world_splatmap ? world_pos.xz : mesh_uv) * (uv_scale * 0.01);
        return sample_stochastic_normal(tex, uv, dFdx(uv), dFdy(uv));
    }
}

void fragment() {
    // Normal weights for triplanar mapping
    vec3 geom_nrm = normalize(world_nrm);
    vec3 n_abs = abs(geom_nrm);
    vec3 n_weight = pow(n_abs, vec3(4.0));
    float total_w = n_weight.x + n_weight.y + n_weight.z;
    n_weight /= max(total_w, 0.0001);

    // 1. Calculate Splatmap UV
    vec2 splat_uv;
    if (use_world_splatmap) {
        splat_uv = (world_pos.xz - world_bounds_origin) / max(world_bounds_size, vec2(0.001));
    } else {
        splat_uv = UV;
    }
    
    // Sample Splatmap (RGBA)
    vec4 splat = texture(splatmap_texture, splat_uv);
    float w1 = splat.r;
    float w2 = splat.g;
    float w3 = splat.b;
    float w0 = clamp(1.0 - (w1 + w2 + w3), 0.0, 1.0);
    
    // Normalize layer weights
    float sum_weights = w0 + w1 + w2 + w3;
    if (sum_weights > 0.0001) {
        w0 /= sum_weights;
        w1 /= sum_weights;
        w2 /= sum_weights;
        w3 /= sum_weights;
    } else {
        w0 = 1.0;
        w1 = 0.0;
        w2 = 0.0;
        w3 = 0.0;
    }

    // 2. Sample layer colors
    vec3 col0 = sample_layer(tex_base, uv_scale_base, use_triplanar_base, n_weight, UV) * albedo_base.rgb;
    vec3 final_color = col0 * w0;
    float final_roughness = roughness_base * w0;

    if (w1 > 0.001) {
        vec3 col1 = sample_layer(tex_layer1, uv_scale_layer1, use_triplanar_layer1, n_weight, UV) * albedo_layer1.rgb;
        final_color += col1 * w1;
        final_roughness += roughness_layer1 * w1;
    }
    if (w2 > 0.001) {
        vec3 col2 = sample_layer(tex_layer2, uv_scale_layer2, use_triplanar_layer2, n_weight, UV) * albedo_layer2.rgb;
        final_color += col2 * w2;
        final_roughness += roughness_layer2 * w2;
    }
    if (w3 > 0.001) {
        vec3 col3 = sample_layer(tex_layer3, uv_scale_layer3, use_triplanar_layer3, n_weight, UV) * albedo_layer3.rgb;
        final_color += col3 * w3;
        final_roughness += roughness_layer3 * w3;
    }

    // 3. Edge Fade (Fog)
    if (enable_edge_fade) {
        float d_xz = length(world_pos.xz);
        float fade_t = clamp((d_xz - edge_fade_start) / max(edge_fade_end - edge_fade_start, 0.001), 0.0, 1.0);
        fade_t = fade_t * fade_t * (3.0 - 2.0 * fade_t);
        final_color = mix(final_color, edge_fade_color.rgb, fade_t);
        final_roughness = mix(final_roughness, 0.98, fade_t);
    }

    ALBEDO = final_color;
    ROUGHNESS = clamp(final_roughness, 0.0, 1.0);
    SPECULAR = 0.05;

    // 4. Normal Maps
    vec3 blended_normal = vec3(0.5, 0.5, 1.0);
    float normal_depth = 1.0;
    bool has_normal = false;

    if (use_normal_base && w0 > 0.01) {
        vec3 norm0 = sample_layer_normal(normal_base, uv_scale_base, use_triplanar_base, n_weight, UV);
        blended_normal = norm0 * w0;
        normal_depth = normal_scale_base * w0;
        has_normal = true;
    }
    if (use_normal_layer1 && w1 > 0.01) {
        vec3 norm1 = sample_layer_normal(normal_layer1, uv_scale_layer1, use_triplanar_layer1, n_weight, UV);
        blended_normal += norm1 * w1;
        normal_depth += normal_scale_layer1 * w1;
        has_normal = true;
    }
    if (use_normal_layer2 && w2 > 0.01) {
        vec3 norm2 = sample_layer_normal(normal_layer2, uv_scale_layer2, use_triplanar_layer2, n_weight, UV);
        blended_normal += norm2 * w2;
        normal_depth += normal_scale_layer2 * w2;
        has_normal = true;
    }
    if (use_normal_layer3 && w3 > 0.01) {
        vec3 norm3 = sample_layer_normal(normal_layer3, uv_scale_layer3, use_triplanar_layer3, n_weight, UV);
        blended_normal += norm3 * w3;
        normal_depth += normal_scale_layer3 * w3;
        has_normal = true;
    }

    if (has_normal) {
        NORMAL_MAP = blended_normal;
        NORMAL_MAP_DEPTH = normal_depth;
    }
}
