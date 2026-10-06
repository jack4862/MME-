float ThicknessRate0 = 5;  // リムライト基準太さ

//リムライトマスク初期ズレ
#define DEFAULT float3(0.5, -0.5, -0.5)



// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////

// PMDパラメータ

float3 CTRXYZ : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "ﾘﾑﾗｲﾄ XYZ"; >;

float RimWidthCtr1 : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "幅太く"; >;
float RimWidthCtr2 : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "幅細く"; >;

float Xplus  : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "X+"; >;
float Xminus : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "X-"; >;
float Yplus  : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "Y+"; >;
float Yminus : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "Y-"; >;
float Zplus  : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "Z+"; >;
float Zminus : CONTROLOBJECT < string name = "RimShilouhetteCTR.pmx"; string item = "Z-"; >;




static float ThicknessRate = ThicknessRate0 + RimWidthCtr1 * 10 - RimWidthCtr2 * 5;


float EdgeThick1 : CONTROLOBJECT < string name = "MaskController.pmx"; string item = "エッジ細"; >;
float EdgeThick2 : CONTROLOBJECT < string name = "MaskController.pmx"; string item = "エッジ太"; >;
static float EdgeThickness0 = (1.0f - EdgeThick1) * (2.0 * EdgeThick2 + 1.0f) * ThicknessRate;

#ifdef MIKUMIKUMOVING
float3 AcsXYZ0 : CONTROLOBJECT < string name = "PostRimLightShillouhette.x"; string item = "XYZ"; >;
float Si : CONTROLOBJECT < string name = "PostRimLightShillouhette.x"; string item = "Si"; >;
#else
float3 AcsXYZ0 : CONTROLOBJECT < string name = "(OffscreenOwner)"; string item = "XYZ"; >;
float Si : CONTROLOBJECT < string name = "(OffscreenOwner)"; string item = "Si"; >;
#endif

static float3 AcsXYZ = AcsXYZ0 + CTRXYZ + float3(Xplus-Xminus, Yplus-Yminus, Zplus-Zminus);

static float EdgeThickness = EdgeThickness0 * -0.5 * Si/10;



float4x4 WorldViewProjMatrix : WORLDVIEWPROJECTION;
float4x4 WorldMatrix         : WORLD;
float4x4 ProjMatrix               : PROJECTION;


float4x4 ViewProjMatrix           : VIEWPROJECTION;
float3 CameraPosition : POSITION  < string Object = "Camera"; >;

float4 MaterialDiffuse : DIFFUSE < string Object = "Geometry"; >;
bool use_texture;
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state
{
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

struct VS_OUTPUT
{
    float4 Pos        : POSITION;
    float2 Tex        : TEXCOORD1;
};

#ifdef MIKUMIKUMOVING
VS_OUTPUT Basic_VS(MMM_SKINNING_INPUT IN)
{
    MMM_SKINNING_OUTPUT SkinOut = MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);
    float4 Pos = SkinOut.Position;
    float3 Normal = SkinOut.Normal;
    float2 Tex = IN.Tex;
    
    
#else
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
#endif
    VS_OUTPUT Out = (VS_OUTPUT)0;

	
	// カメラとの距離
    float len =  length( CameraPosition - Pos.xyz );

    // 頂点を法線方向に押し出す
    if(ProjMatrix._44 < 0.5f){
        
        Pos.xyz += Normal * ( EdgeThickness * pow( len, 0.9f ) * 0.0015f * pow(2.4142f / ProjMatrix._22, 0.7f) ); 
        Pos.xyz += AcsXYZ.xyz/10 + DEFAULT/10;
        
    }else{
        // パースペクティブoff
        Pos.xyz += Normal * ( EdgeThickness * 0.0025f / ProjMatrix._11 );
        Pos.xyz += AcsXYZ.xyz/10 + DEFAULT/10;;
        
        
    }
	
    
    //Pos = mul( Pos, ViewProjMatrix );
    
    
    //Out.Pos = mul( Pos, WorldMatrix );
    
    
    Out.Pos = mul( Pos, WorldViewProjMatrix);
    
    Out.Tex = Tex;
    
    return Out;
}

float4 Basic_PS( VS_OUTPUT IN ) : COLOR0
{
    float4 Color = float4(1,1,1,1);
    
    Color.a = MaterialDiffuse.a;
    
    if ( use_texture )Color.a *= tex2D( ObjTexSampler, IN.Tex ).a;
    
    
    return Color;
}

technique Mask < string MMDPass = "object"; >
{
    pass P
    { 
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader = compile ps_2_0 Basic_PS(); 
    }
}

technique MaskSS < string MMDPass = "object_ss"; >
{
    pass P
    { 
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader = compile ps_2_0 Basic_PS(); 
    }
}

technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }
