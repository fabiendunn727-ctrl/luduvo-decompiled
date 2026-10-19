#include <metal_stdlib>
using namespace metal;

// Minimal fullscreen pass used by the iOS client shell.
// The full engine renderer (NVRHI/Vulkan) replaces this once the native
// engine library is available for iOS.

struct RasterizerData {
    float4 position [[position]];
    float4 color;
};

vertex RasterizerData ldv_shell_vertex(uint vertexID [[vertex_id]]) {
    // Fullscreen triangle.
    float2 positions[3] = {
        float2(-1.0, -3.0),
        float2(-1.0,  1.0),
        float2( 3.0,  1.0)
    };

    RasterizerData out;
    out.position = float4(positions[vertexID], 0.0, 1.0);

    // Vertical gradient from the Luduvo accent purple to deep violet.
    float t = (positions[vertexID].y + 1.0) * 0.5;
    out.color = float4(mix(float3(0.486, 0.302, 1.0), float3(0.129, 0.055, 0.243), t), 1.0);
    return out;
}

fragment float4 ldv_shell_fragment(RasterizerData in [[stage_in]]) {
    return in.color;
}
