#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D mask;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float videoRatio;
    float screenRatio;
};

void main() {
    vec4 src = texture(source, qt_TexCoord0);
    vec2 uv = qt_TexCoord0;

    vec2 scale = vec2(1.0);
    if (screenRatio > videoRatio) {
        scale.x = screenRatio / videoRatio;
    } else {
        scale.y = videoRatio / screenRatio;
    }

    uv = (uv - 0.5) * scale + 0.5;

    vec4 m;
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        m = texture(mask, vec2(0.01, 0.01));
    } else {
        m = texture(mask, uv);
    }

    float maskAlpha = 1.0 - m.r;
    fragColor = src * maskAlpha * qt_Opacity;
}
