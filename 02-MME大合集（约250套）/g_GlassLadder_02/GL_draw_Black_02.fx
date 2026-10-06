// GL_draw_Black_02.fx
// 


// 操作設定値
//

// Parameters/Define
//
float cut_alpha = 0.05 ;		// 透過閾値(0へ近似)
float block_alpha = 0.95 ;		// 遮光閾値(1へ近似)

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

	Out.Tex = IN.Tex;

	float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
	Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
	Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;

	return Out;
}

#else

BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0 ){
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    Out.VPos = mul( Pos, WorldViewMatrix ) ;
    Out.WPos = mul( Pos, WorldMatrix );
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

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
	float4 Color = 0  ;

	float alpha = MaterialDiffuse.a  ;

    if ( use_texture ) {
		alpha *= tex2D( ObjTexSampler, IN.Tex ).a ;
	}
    if ( use_spheremap ) {
        alpha *= tex2D(ObjSphareSampler,IN.SpTex).a;
    }
    if( alpha < cut_alpha ){
		clip(-1) ;
    }


	return float4(0,0,0,0) ;
}


// technique
//
technique MainTec_ns < string MMDPass = "object";> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS();
        PixelShader  = compile ps_3_0 BufferShadow_PS();
//		CULLMODE = NONE ;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
    }
}

technique MainTec_ss  < string MMDPass = "object_ss";> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS();
        PixelShader  = compile ps_3_0 BufferShadow_PS();
//		CULLMODE = NONE ;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
   }
}


technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }

