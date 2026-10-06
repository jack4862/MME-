// GL_map_02.fx
// 


// 操作設定値
//

#ifdef MIKUMIKUMOVING
float Tr : CONTROLOBJECT <string name="(OffscreenOwner)"; string item="Tr";>;
float scaling0 : CONTROLOBJECT < string name = "(OffscreenOwner)"; >;
float3 CenterPos: CONTROLOBJECT < string name = "(OffscreenOwner)"; >;
float4x4 CenterRot0: CONTROLOBJECT < string Name = "(OffscreenOwner)"; >;
static float4x4 CenterRot = CenterRot0/10 ;
shared static float morph_on_alpha = 0.0 ;
shared float morph_mini = 0.0 ;
#endif

#ifndef MIKUMIKUMOVING
#define	CONTROLLERNAME "(OffscreenOwner)"
float4x4 CenterRot : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "センター"; >;
float3 CenterPos : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "センター"; >;
float morph_on_alpha : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "透明材質へ加算"; >;
float morph_mini : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "縮小"; >;
#endif


// Parameters/Define
//

float cut_alpha = 0.05 ;		// 透過閾値(0へ近似)
float block_alpha = 0.95 ;		// 遮光閾値(1へ近似)
static float ImageSize = 96.0*(1-morph_mini) ;


// from MMD
//
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 ViewMatrix				: VIEW;
float4x4 ProjMatrix				: PROJECTION;
float4x4 WorldViewMatrix		: WORLDVIEW;
float4x4 ViewProjMatrix				: VIEWPROJECTION;



float4	MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float4	EdgeColor         : EDGECOLOR;
float	EdgeWidth			: EDGEWIDTH;
float4	GroundShadowColor : GROUNDSHADOWCOLOR;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

bool	use_texture;
bool	use_spheremap;
bool	use_subtexture; 
bool	use_toon;
bool	opadd;
bool	spadd;    // スフィアマップ加算合成フラグ

sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

static float3 SnowNormal = normalize(mul( float3(0,1,0) , (float3x3)CenterRot )) ;


// Texture
//
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
	MINFILTER = POINT;
	MAGFILTER = POINT;
    MIPFILTER = NONE;
    ADDRESSU  = WRAP;
    ADDRESSV  = WRAP;
};
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
    texture = <ObjectSphereMap>;
    MINFILTER = POINT;
    MAGFILTER = POINT;
    MIPFILTER = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


// Shader Struct
//
struct BufferShadow_OUTPUT {
    float4 Pos      : POSITION;     // 射影変換座標
//    float4 ZCalcTex : TEXCOORD0;    // Z値
    float2 Tex      : TEXCOORD1;    // テクスチャ
    float3 Normal   : TEXCOORD2;    // 法線
    float3 Eye      : TEXCOORD3;    // カメラとの相対位置
    float2 SpTex    : TEXCOORD4;	 // スフィアマップテクスチャ座標
	float4 WPos		: TEXCOORD5;	// 変換済み座標
	float4 VPos		: TEXCOORD6;	// 変換済み座標
    float4 Color    : COLOR0;       // ディフューズ色
};


// VertexShader
//
#ifdef MIKUMIKUMOVING

BufferShadow_OUTPUT BufferShadow_VS(MMM_SKINNING_INPUT IN)
{
	bool useTexture	= use_texture;
	bool useSphereMap = use_spheremap;
	bool useToon = use_toon;

	BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

	//================================================================================
	//MikuMikuMoving独自のスキニング関数(MMM_SkinnedPositionNormal)。座標と法線を取得する。
	//================================================================================
	MMM_SKINNING_OUTPUT SkinOut = MMM_SkinnedPositionNormal(IN.Pos, IN.Normal, IN.BlendWeight, IN.BlendIndices, IN.SdefC, IN.SdefR0, IN.SdefR1);

	Out.Eye = CameraPosition - mul( SkinOut.Position, WorldMatrix ).xyz;
	Out.Normal = normalize( mul( SkinOut.Normal, (float3x3)WorldMatrix ) );

	if (MMM_IsDinamicProjection)
	{
		float4x4 wvpmat = mul(mul(WorldMatrix, ViewMatrix), MMM_DynamicFov(ProjMatrix, length(Out.Eye)));
		Out.Pos = mul( SkinOut.Position, wvpmat );
	}
	else
	{
		Out.Pos = mul( SkinOut.Position, WorldViewProjMatrix );
	}
    Out.VPos = mul( SkinOut.Position, WorldViewMatrix );
    Out.WPos = mul( SkinOut.Position, WorldMatrix );

	float3 wPos = Out.WPos.xyz ;
	wPos = mul( wPos - CenterPos , transpose((float3x3)CenterRot )) ;

	Out.Pos.x = wPos.x/ImageSize ;			// -1< x/w < +1
	Out.Pos.y = wPos.y/ImageSize ;			// -1< y/w < +1
	Out.Pos.z = wPos.z/1024 ;				// 0< z/w < 1
	Out.Pos.w = 1  ;

	Out.Tex = IN.Tex;
	float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
	Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
	Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;

	return Out;
}

#else

BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0 ){
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

	Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
    Out.VPos = mul( Pos, WorldViewMatrix ) ;
	Out.WPos.xyz = mul( Pos, WorldMatrix );

	float3 wPos = Out.WPos.xyz ;
	wPos = mul( wPos - CenterPos , transpose((float3x3)CenterRot )) ;

	Out.Pos.x = wPos.x/ImageSize ;			// -1< x/w < +1
	Out.Pos.y = wPos.y/ImageSize ;			// -1< y/w < +1
	Out.Pos.z = wPos.z/1024 ;				// 0< z/w < 1
	Out.Pos.w = 1  ;

    Out.Tex = Tex;
	float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
	Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
	Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;

    return Out;
}
#endif


// PixelShader
//
float4 BufferShadow_PS(BufferShadow_OUTPUT IN) : COLOR
{
	float4 Color = 0 ;
	float alpha = MaterialDiffuse.a ;


    if ( use_texture ) {
		alpha *= tex2D( ObjTexSampler, IN.Tex ).a ;
	}
    if ( use_spheremap ) {
        alpha *= tex2D(ObjSphareSampler,IN.SpTex).a;
    }
    if( alpha < block_alpha ){
		clip(-1) ;
    }


	float3 tmpPos = mul( IN.WPos - CenterPos , transpose((float3x3)CenterRot)) ;

	Color.r = tmpPos.z/(abs(tmpPos.z)+8) ;
	Color.a = 1 ;

	return Color ;
}


// technique
//
technique MainTec_ns < string MMDPass = "object";> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS();
        PixelShader  = compile ps_3_0 BufferShadow_PS();
		CULLMODE = NONE ;
//		ZENABLE = TRUE;
//		ZWRITEENABLE = TRUE;
		AlphaBlendEnable = false;
//		AlphaTestEnable = false;

	}
}

technique MainTec_ss  < string MMDPass = "object_ss";> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS();
        PixelShader  = compile ps_3_0 BufferShadow_PS();
		CULLMODE = NONE ;
//		ZENABLE = TRUE;
//		ZWRITEENABLE = TRUE;
		AlphaBlendEnable = false;
//		AlphaTestEnable = false;
	}
}


technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }

