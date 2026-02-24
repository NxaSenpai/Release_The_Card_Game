/*
    Glitch Effect Shader by Yui Kinomoto @arlez80
    MIT License
*/

shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float shake_power = 0.03;
uniform float shake_rate : hint_range(0.0, 1.0) = 0.0;
uniform float shake_speed = 5.0;
uniform float shake_block_size = 30.5;
uniform float shake_color_rate : hint_range(0.0, 1.0) = 0.01;

float random(float seed)
{
    return fract(543.2543 * sin(dot(vec2(seed, seed), vec2(3525.46, -54.3415))));
}

void fragment()
{
    float enable_shift = float(
        random(trunc(TIME * shake_speed)) < shake_rate
    );

    // Horizontal block shift
    vec2 fixed_uv = SCREEN_UV;
    fixed_uv.x += (
        random(
            (trunc(SCREEN_UV.y * shake_block_size) / shake_block_size)
            + TIME
        ) - 0.5
    ) * shake_power * enable_shift;

    // Vertical micro-shift for extra aggression
    fixed_uv.y += (
        random(
            (trunc(SCREEN_UV.x * shake_block_size * 0.5) / (shake_block_size * 0.5))
            + TIME * 1.3
        ) - 0.5
    ) * shake_power * 0.3 * enable_shift;

    vec4 pixel_color = textureLod(SCREEN_TEXTURE, fixed_uv, 0.0);

    // RGB split - wider separation
    pixel_color.r = mix(
        pixel_color.r,
        textureLod(SCREEN_TEXTURE, fixed_uv + vec2(shake_color_rate, 0.0), 0.0).r,
        enable_shift
    );
    pixel_color.g = mix(
        pixel_color.g,
        textureLod(SCREEN_TEXTURE, fixed_uv + vec2(-shake_color_rate * 0.5, shake_color_rate * 0.3), 0.0).g,
        enable_shift * 0.6
    );
    pixel_color.b = mix(
        pixel_color.b,
        textureLod(SCREEN_TEXTURE, fixed_uv + vec2(-shake_color_rate, 0.0), 0.0).b,
        enable_shift
    );

    // Scanline darkening on glitch frames
    float scanline = sin(SCREEN_UV.y * 400.0) * 0.04 * enable_shift;
    pixel_color.rgb -= scanline;

    COLOR = pixel_color;
}