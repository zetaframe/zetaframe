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

layout(location = 0) in vec3 fragColor;

layout(location = 0) out vec4 outColor;

void main() {
    outColor = vec4(fragColor, 1.0);
}