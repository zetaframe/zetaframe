#version 450
#extension GL_ARB_separate_shader_objects : enable

layout(binding = 0, set = 0) uniform GlobalData {
    mat4 proj;
} global;

layout(binding = 0, set = 1) uniform MaterialData {
    vec3 color;
} material;

layout(binding = 0, set = 2) uniform MeshData {
    vec3 pos;
} mesh;

layout(location = 0) in vec2 inPosition;
layout(location = 1) in vec3 inColor;

layout(location = 0) out vec3 fragColor;

void main() {
    gl_Position = vec4(inPosition, 0.0, 1.0);
    fragColor = inColor;
}