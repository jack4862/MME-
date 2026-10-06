int count = 1200;
float Height = 100;
float WidthX = 250;
float WidthZ = 250;
float ParticleSize = 1.8;
float Aspect = 0.25;
float FadeLength = 300;
float luminosity = 1.5;
float speed = 30;

texture2D Tex1 <
    string ResourceName = "fluorescent.png";
    int MipLevels = 0;
>;
sampler Tex1Samp = sampler_state {
    texture = <Tex1>;
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
};
texture2D rndtex <
    string ResourceName = "random256x256.bmp";
>;
sampler rnd = sampler_state {
    texture = <rndtex>;
    MINFILTER = NONE;
    MAGFILTER = NONE;
};

#define RNDTEX_WIDTH  256
#define RNDTEX_HEIGHT 256
float ftime : TIME <bool SyncInEditMode = false;>;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

// transform
float4x4 WorldMatrix : World;
float4x4 ViewProjMatrix : ViewProjection;
float4x4 ViewTransMatrix : ViewTranspose;
float4x4 WorldViewProjMatrix    : WORLDVIEWPROJECTION;
float4x4 WorldViewMatrixInverse : WORLDVIEWINVERSE;
static float scaling = length(WorldMatrix._11_12_13) * 0.1;
float3   CameraPosition     : POSITION  < string Object = "Camera"; >;
static float3x3 WorldRotMatrix = {
    normalize(WorldMatrix[0].xyz),
    normalize(WorldMatrix[1].xyz),
    normalize(WorldMatrix[2].xyz),
};

struct VS_OUTPUT
{
    float4 Pos        : POSITION;
    float2 Tex        : TEXCOORD0;
    float  Alpha      : COLOR0;
};

float4 getRandom(float rindex)
{
    float2 tpos = float2(rindex % RNDTEX_WIDTH, trunc(rindex / RNDTEX_WIDTH));
    tpos += float2(0.5,0.5);
    tpos /= float2(RNDTEX_WIDTH, RNDTEX_HEIGHT);
    return tex2Dlod(rnd, float4(tpos,0,1));
}

VS_OUTPUT Mask_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out;
    Out.Alpha = 1;
    float index = Pos.z;
    Pos.z = 0;

    // fluorescent position and animation
    float4 base_pos = getRandom(index);
    base_pos.xz -= 0.5;
    if(Pos.y>0){
        base_pos.x = base_pos.x - (cos(ftime * speed *   (1-base_pos.y*0.6) + base_pos.y*100) / 200);
        base_pos.z = base_pos.z - (sin(ftime * speed *   (1-base_pos.y*0.6) + base_pos.y*100) / 200);
        base_pos.y = base_pos.y + (sin(ftime * speed*2 * (1-base_pos.y*0.6) + base_pos.y*100) / 15);
    } 
    base_pos.y = base_pos.y/20;
    base_pos.xyz *= float3(WidthX, Height, WidthZ);

    // Y axis billboard
    float3 Axis = float3(0, 1, 0);
    base_pos.xyz = mul( base_pos.xyz, WorldRotMatrix );
    Axis = mul( Axis, WorldRotMatrix );
    float3 WorldPos = WorldMatrix[3].xyz + base_pos.xyz * scaling;
    float3 Eye = normalize(WorldPos - CameraPosition);
    float3 Side = normalize(cross(Axis,Eye));
    Out.Pos = float4(WorldPos, 1);
    Out.Pos.xyz += (Pos.y * Axis + Pos.x * Side * Aspect) * ParticleSize * 10 * scaling;

    Out.Pos.z -= (index >= count) * 100000;
    Out.Pos = mul( Out.Pos, ViewProjMatrix );
    Out.Alpha *= 0.5 + 0.5 * (1 - saturate((Out.Pos.z - 50) / FadeLength));
    Out.Tex = Tex;
    return Out;
}

float4 Mask_PS( VS_OUTPUT input ) : COLOR0
{
    float4 color = tex2D( Tex1Samp, input.Tex );
    color.r *= luminosity;
    color.g *= luminosity;
    color.b *= luminosity;
    color.a *= AcsTr;
    return color;
}

technique MainTec {
    pass DrawObject {
        ZENABLE = TRUE;
        ZWRITEENABLE = TRUE;
        CULLMODE = NONE;
        ALPHABLENDENABLE = TRUE;
        SRCBLEND=SRCALPHA;
        DESTBLEND=INVSRCALPHA;

        VertexShader = compile vs_3_0 Mask_VS();
        PixelShader  = compile ps_3_0 Mask_PS();
    }
}
