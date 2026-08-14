shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float uv_scale = 40.0;
uniform vec2 uv_scale_v2 = vec2(1.0, 1.0);
uniform float smoothness : hint_range(0.0, 1.0) = 1.0;
uniform bool use_world_uv = false;

uniform bool use_normal_map = false;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform float normal_scale : hint_range(-16.0, 16.0) = 1.0;

uniform bool use_slope_cliff_rock = false;
uniform sampler2D cliff_texture : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 cliff_albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float cliff_uv_scale : hint_range(0.005, 0.5) = 0.04;
uniform float cliff_slope_threshold : hint_range(0.0, 1.0) = 0.65;
uniform float cliff_blend_sharpness : hint_range(0.01, 0.5) = 0.15;
uniform bool use_cliff_normal = false;
uniform sampler2D cliff_normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform float cliff_normal_scale : hint_range(-16.0, 16.0) = 1.0;

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    // Used when use_world_uv picks a projection plane (road end-caps are vertical).
    world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Hash function for random offsets/rotations
vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

// Samples a texture stochastically to break tiling
vec3 stochastic_sample(sampler2D tex, vec2 uv, vec2 dx, vec2 dy) {
    // Grid cell coordinates
    vec2 p = floor(uv);
    vec2 f = fract(uv);
    
    vec3 res = vec3(0.0);
    float weight_sum = 0.0;
    
    // Sample from 4 neighboring grid cells
    for (int y = 0; y <= 1; y++) {
        for (int x = 0; x <= 1; x++) {
            vec2 offset = vec2(float(x), float(y));
            vec2 cell = p + offset;
            vec2 rand = hash(cell);
            
            #ifdef GL_ES
            // Workaround for compiler bugs in WebGL/OpenGL ES with dynamic rotation matrices in loops
            vec2 sampled_uv = f + rand.y;
            #else
            // Random rotation and offset
            float angle = rand.x * 6.2831;
            mat2 rot = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
            vec2 sampled_uv = rot * (f - vec2(0.5)) + vec2(0.5) + rand.y;
            #endif
            
            // Weight based on distance to grid center
            float w = pow(1.0 - smoothstep(0.0, 1.414, length(f - offset)), 2.0);
            
            #ifdef GL_ES
            vec2 sampled_dx = dx;
            vec2 sampled_dy = dy;
            #else
            // Rotate derivatives to match cell rotation
            vec2 sampled_dx = rot * dx;
            vec2 sampled_dy = rot * dy;
            #endif
            
            res += textureGrad(tex, sampled_uv, sampled_dx, sampled_dy).rgb * w;
            weight_sum += w;
        }
    }
    
    return res / weight_sum;
}

// Samples a normal map stochastically and rotates the tangent-space normals
vec3 stochastic_sample_normal(sampler2D tex, vec2 uv, vec2 dx, vec2 dy) {
    vec2 p = floor(uv);
    vec2 f = fract(uv);
    vec3 res = vec3(0.0);
    float weight_sum = 0.0;
    
    for (int y = 0; y <= 1; y++) {
        for (int x = 0; x <= 1; x++) {
            vec2 offset = vec2(float(x), float(y));
            vec2 cell = p + offset;
            vec2 rand = hash(cell);
            
            #ifdef GL_ES
            vec2 sampled_uv = f + rand.y;
            #else
            float angle = rand.x * 6.2831;
            mat2 rot = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
            vec2 sampled_uv = rot * (f - vec2(0.5)) + vec2(0.5) + rand.y;
            #endif
            
            float w = pow(1.0 - smoothstep(0.0, 1.414, length(f - offset)), 2.0);
            
            #ifdef GL_ES
            vec2 sampled_dx = dx;
            vec2 sampled_dy = dy;
            vec3 raw_normal = textureGrad(tex, sampled_uv, sampled_dx, sampled_dy).rgb * 2.0 - 1.0;
            vec3 rotated_normal = raw_normal;
            #else
            vec2 sampled_dx = rot * dx;
            vec2 sampled_dy = rot * dy;
            vec3 raw_normal = textureGrad(tex, sampled_uv, sampled_dx, sampled_dy).rgb * 2.0 - 1.0;
            // Rotate tangent space normal directions to align with UV rotation
            vec2 rotated_xy = rot * raw_normal.xy;
            vec3 rotated_normal = vec3(rotated_xy, raw_normal.z);
            #endif
            
            res += rotated_normal * w;
            weight_sum += w;
        }
    }
    
    return (res / weight_sum) * 0.5 + 0.5;
}

void fragment() {
    vec3 geom_nrm = normalize(world_nrm);
    vec3 n_abs = abs(geom_nrm);
    vec3 n_weight = pow(n_abs, vec3(4.0));
    float total_w = n_weight.x + n_weight.y + n_weight.z;
    n_weight /= max(total_w, 0.0001);
    
    vec3 color;
    if (use_world_uv) {
        // Seamless world-space triplanar projection for base texture (sand / grass)
        vec2 scale_v = (uv_scale * 0.1) * uv_scale_v2;
        vec2 uv_bx = vec2(world_pos.z, -world_pos.y) * scale_v;
        vec2 uv_by = world_pos.xz * scale_v;
        vec2 uv_bz = vec2(-world_pos.x, -world_pos.y) * scale_v;
        
        vec3 col_x = stochastic_sample(albedo_texture, uv_bx, dFdx(uv_bx), dFdy(uv_bx));
        vec3 col_y = stochastic_sample(albedo_texture, uv_by, dFdx(uv_by), dFdy(uv_by));
        vec3 col_z = stochastic_sample(albedo_texture, uv_bz, dFdx(uv_bz), dFdy(uv_bz));
        
        color = (col_x * n_weight.x + col_y * n_weight.y + col_z * n_weight.z) * albedo.rgb;
    } else {
        vec2 uv = UV * (uv_scale * 0.1) * uv_scale_v2;
        color = stochastic_sample(albedo_texture, uv, dFdx(uv), dFdy(uv)) * albedo.rgb;
    }
    
    float rock_weight = 0.0;
    if (use_slope_cliff_rock) {
        // High-quality seamless triplanar rock projection
        vec2 uv_rx = vec2(world_pos.z, world_pos.y) * cliff_uv_scale;
        vec2 uv_ry = vec2(world_pos.x, world_pos.z) * cliff_uv_scale;
        vec2 uv_rz = vec2(world_pos.x, world_pos.y) * cliff_uv_scale;
        
        vec3 rock_x = texture(cliff_texture, uv_rx).rgb;
        vec3 rock_y = texture(cliff_texture, uv_ry).rgb;
        vec3 rock_z = texture(cliff_texture, uv_rz).rgb;
        
        // Subtle natural horizontal sandstone strata banding
        float strata = 0.96 + 0.04 * sin(world_pos.y * 0.8 + sin(world_pos.y * 0.25) * 1.5);
        vec3 rock_color = (rock_x * n_weight.x + rock_y * n_weight.y + rock_z * n_weight.z) * cliff_albedo.rgb * strata;
        
        // Slope factor: 0 on flat ground (geom_nrm.y == 1), 1 on vertical cliff (geom_nrm.y == 0)
        float slope = 1.0 - clamp(geom_nrm.y, 0.0, 1.0);
        rock_weight = smoothstep(cliff_slope_threshold - cliff_blend_sharpness, cliff_slope_threshold + cliff_blend_sharpness, slope);
        color = mix(color, rock_color, rock_weight);
    }
    
    ALBEDO = color;
    ROUGHNESS = smoothness;
    SPECULAR = 0.05;
    
    if (use_slope_cliff_rock && use_cliff_normal && rock_weight > 0.01) {
        // True triplanar normal map reconstruction in world space
        vec2 uv_rx = vec2(world_pos.z, world_pos.y) * cliff_uv_scale;
        vec2 uv_ry = vec2(world_pos.x, world_pos.z) * cliff_uv_scale;
        vec2 uv_rz = vec2(world_pos.x, world_pos.y) * cliff_uv_scale;
        
        vec3 raw_nx = texture(cliff_normal_texture, uv_rx).rgb * 2.0 - 1.0;
        vec3 raw_ny = texture(cliff_normal_texture, uv_ry).rgb * 2.0 - 1.0;
        vec3 raw_nz = texture(cliff_normal_texture, uv_rz).rgb * 2.0 - 1.0;
        
        // Transform tangent normal samples to world-space per projection plane
        vec3 wn_x = vec3(raw_nx.z * sign(geom_nrm.x), raw_nx.y, raw_nx.x * sign(geom_nrm.x));
        vec3 wn_y = vec3(raw_ny.x, raw_ny.z * sign(geom_nrm.y), raw_ny.y * sign(geom_nrm.y));
        vec3 wn_z = vec3(raw_nz.x * sign(geom_nrm.z), raw_nz.y, raw_nz.z * sign(geom_nrm.z));
        
        vec3 tri_norm_world = normalize(wn_x * n_weight.x + wn_y * n_weight.y + wn_z * n_weight.z);
        vec3 final_world_norm = normalize(mix(geom_nrm, tri_norm_world, clamp(cliff_normal_scale * rock_weight, 0.0, 0.75)));
        
        // Output in View Space to NORMAL (bypasses broken/degenerate tangent space on vertical triangles)
        NORMAL = normalize((VIEW_MATRIX * vec4(final_world_norm, 0.0)).xyz);
    } else if (use_normal_map) {
        vec2 uv = (use_world_uv ? world_pos.xz : UV) * (uv_scale * 0.1) * uv_scale_v2;
        NORMAL_MAP = stochastic_sample_normal(normal_texture, uv, dFdx(uv), dFdy(uv));
        NORMAL_MAP_DEPTH = normal_scale;
    }
}
