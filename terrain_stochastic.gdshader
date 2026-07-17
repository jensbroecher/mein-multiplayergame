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
    // World UV: project onto the dominant plane from the surface normal.
    // Plain world_pos.xz stretches badly on vertical faces (ramp end-caps / landings).
    vec2 base_uv;
    if (use_world_uv) {
        vec3 an = abs(normalize(world_nrm));
        if (an.y >= an.x && an.y >= an.z) {
            base_uv = world_pos.xz;
        } else if (an.x >= an.z) {
            base_uv = world_pos.zy;
        } else {
            base_uv = world_pos.xy;
        }
    } else {
        base_uv = UV;
    }
    vec2 uv = base_uv * (uv_scale * 0.1) * uv_scale_v2;
    vec2 dx = dFdx(uv);
    vec2 dy = dFdy(uv);
    vec3 color = stochastic_sample(albedo_texture, uv, dx, dy);
    ALBEDO = color * albedo.rgb;
    ROUGHNESS = smoothness;
    SPECULAR = 0.0;
    
    if (use_normal_map) {
        NORMAL_MAP = stochastic_sample_normal(normal_texture, uv, dx, dy);
        NORMAL_MAP_DEPTH = normal_scale;
    }
}
