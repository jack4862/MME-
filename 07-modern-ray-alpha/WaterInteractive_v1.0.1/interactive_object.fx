float4x4 u_worldMatrix  : WORLD;
float4x4 u_waterWorldMatrix: CONTROLOBJECT < string Name = "(OffscreenOwner)"; string item="Bone";>;

const float2 c_interactiveSize = float2(23.21363, 23.21363) * 2 * 4;

float4x4 lookAt(float3 eye, float3 target, float3 up) {
    float3 zAxis = normalize(target - eye);
    float3 xAxis = normalize(cross(up, zAxis));
    float3 yAxis = cross(zAxis, xAxis);
    return float4x4(
        xAxis.x,         yAxis.x,           zAxis.x,          0,
        xAxis.y,         yAxis.y,           zAxis.y,          0,
        xAxis.z,         yAxis.z,           zAxis.z,          0,
        -dot(xAxis, eye), -dot(yAxis, eye), -dot(zAxis, eye), 1
    );
}

float4x4 orthoProj(float2 size, float zNear, float zFar) {
    float4x4 mat = 0;

    mat[0][0] = 2.0 / size.x;
    mat[0][1] = 0.0;
    mat[0][2] = 0.0;
    mat[0][3] = 0.0;

    mat[1][0] = 0.0;
    mat[1][1] = 2.0 / size.y;
    mat[1][2] = 0.0;
    mat[1][3] = 0.0;

    mat[2][0] = 0.0;
    mat[2][1] = 0.0;
    mat[2][2] = 1.0 / (zFar - zNear);
    mat[2][3] = -zNear / (zFar - zNear);

    mat[3][0] = 0.0;
    mat[3][1] = 0.0;
    mat[3][2] = 0.0;
    mat[3][3] = 1.0;

    return mat;
}

struct Attributes {
    float4 positionOS : SV_POSITION;
};

struct Varyings {
    float4 positionCS : SV_POSITION;
    float  depth      : TEXCOORD0;
};

Varyings mainVS(Attributes input) {
    float3 eye = u_waterWorldMatrix[3].xyz;
    float3 target = u_waterWorldMatrix[3].xyz - normalize(u_waterWorldMatrix[1].xyz) * 1000;
    float3 up = normalize(u_waterWorldMatrix[2].xyz);
    float4x4 viewMatrix = lookAt(eye, target, up);

    float zNear = 0;
    float zFar = 1000;
    float4x4 projMatrix = orthoProj(c_interactiveSize, zNear, zFar);

    float4x4 mvp = mul(mul(u_worldMatrix, viewMatrix), projMatrix);
    float4 positionCS = mul(input.positionOS, mvp);

    float3 positionWS = mul(input.positionOS, u_worldMatrix).xyz;
    float depth = dot(normalize(u_waterWorldMatrix[1].xyz), u_waterWorldMatrix[3].xyz - positionWS);

    Varyings output = (Varyings)0;
    output.positionCS = positionCS;
    output.depth = depth;
    
    return output;
}

float4 mainPS(Varyings input) : COLOR0 {
	return float4(input.depth.xxx, 1);
}

technique MainTec < string MMDPass = "object"; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 mainVS();
        PixelShader  = compile ps_3_0 mainPS();
    }
}
technique MainTecBS  < string MMDPass = "object_ss"; > {
    pass DrawObject {
        VertexShader = compile vs_3_0 mainVS();
        PixelShader  = compile ps_3_0 mainPS();
    }
}
technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTech < string MMDPass = "shadow";  > {}
technique ZplotTec < string MMDPass = "zplot"; > {}