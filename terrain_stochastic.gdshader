shader_type spatial;

uniform sampler2D albedo_texture : source_color;
uniform float uv_scale = 40.0;
uniform float smoothness : hint_range(0.0, 1.0) = 1.0;

// Hash function for random offsets/rotations
vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

// Samples a texture stochastically to break tiling
vec3 stochastic_sample(sampler2D tex, vec2 uv) {
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
            
            // Random rotation and offset
            float angle = rand.x * 6.2831;
            mat2 rot = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle)));
            vec2 sampled_uv = rot * f + rand.y;
            
            // Weight based on distance to grid center
            float w = pow(1.0 - smoothstep(0.0, 1.414, length(f - offset)), 4.0);
            
            res += texture(tex, sampled_uv).rgb * w;
            weight_sum += w;
        }
    }
    
    return res / weight_sum;
}

void fragment() {
    vec3 color = stochastic_sample(albedo_texture, UV);
    ALBEDO = color;
    ROUGHNESS = smoothness;
    SPECULAR = 0.0;
}
