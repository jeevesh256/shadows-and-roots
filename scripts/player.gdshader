shader_type canvas_item;

uniform vec4 aura_color = vec4(0.3, 1.0, 0.3, 1.0);  // Aura's glow color
uniform float aura_strength = 0.5;  // Aura intensity
uniform float outline_width = 3.0;  // Aura thickness
uniform float pulse_speed = 1.0;  // Speed of pulsing effect
uniform float time = 0.0;  // Time for animation

void fragment() {
    vec4 sprite_color = texture(TEXTURE, UV);  // Base sprite texture

    // Calculate the pulsating effect
    float pulse = 0.5 + 0.5 * sin(time * pulse_speed);

    // Create the aura effect
    vec4 aura_effect = aura_color * pulse * aura_strength;

    // Combine sprite and aura colors
    COLOR = sprite_color + aura_effect;

    // Preserve the sprite's transparency
    COLOR.a *= sprite_color.a;
}