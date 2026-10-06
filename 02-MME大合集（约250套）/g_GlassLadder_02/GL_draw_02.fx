// GL_draw_02.fx
// 

// 操作設定値
//

// #define NO_SHAFT				// 光条有無
#define SHAFT_LOOP 63.0			// 標本数 31 - 200 ?
#define BlackShaft 1.0			// 光条遮蔽強調	0 - 32 ?

#ifdef MIKUMIKUMOVING

shared float morph_weak_shaft ;
shared float morph_weak_floor ;
shared float morph_Umirror ;
shared float morph_Vmirror ;
shared float morph_Glass_ON ;
shared float morph_BackGlass_OFF ;
shared float morph_on_alpha ;
shared float morph_transient ;
shared float morph_mini = 0.0 ;

float Tr : CONTROLOBJECT <string name="(OffscreenOwner)"; string item="Tr";>;
float scaling0 : CONTROLOBJECT < string name = "(OffscreenOwner)"; >;
float3 CenterPos: CONTROLOBJECT < string name = "(OffscreenOwner)"; >;
float4x4 CenterRot0: CONTROLOBJECT < string Name = "(OffscreenOwner)"; >;
static float4x4 CenterRot = CenterRot0/10 ;


#endif


#ifndef MIKUMIKUMOVING
#define	CONTROLLERNAME "(OffscreenOwner)"
float4x4 CenterRot : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "センター"; >;
float3 CenterPos : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "センター"; >;
float morph_weak_floor : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "写像弱"; >;
float morph_Umirror : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "左右縮小反転"; >;
float morph_Vmirror : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "上下縮小反転"; >;
float morph_on_alpha : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "透過材質へ加算"; >;
float morph_mini : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "縮小"; >;
float morph_weak_shaft : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "光条弱"; >;
float morph_transient : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "ゆらぎ"; >;
float morph_Glass_ON : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "Glass_ON"; >;
float morph_BackGlass_OFF : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "Glass裏OFF"; >;
#endif

static float3 GlassNormal = normalize(mul( float3(0,0,-1) , (float3x3)CenterRot )) ;


// Parameters/Define
//
float cut_alpha = 0.05 ;		// 透過閾値(0へ近似)
float block_alpha = 0.95 ;		// 遮光閾値(1へ近似)
static float ImageSize = 96.0*(1-morph_mini) ;

// from MMD
//
float ftime : TIME <bool SyncInEditMode=true;>;

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


// Glass Image
texture MaskTexture01 < string ResourceName ="GL_image_01.png"; > ;
// texture MaskTexture01 < string ResourceName ="stained_glass_light01.png"; > ;	// for NOB-san's Image
sampler MaskTexSampler01 = sampler_state {
    texture = <MaskTexture01>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
	AddressU  = Border ;
	AddressV = Border ;
	BorderColor = float4 ( 0,0,0,0 ) ;
};

shared texture GL2mapRT: OFFSCREENRENDERTARGET ;
sampler SSmapSampler = sampler_state {
    texture = <GL2mapRT>;
    AddressU  = CLAMP;
    AddressV = CLAMP;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
//    Filter = NONE;
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
	float4 Color = 0 , GlassColor = 0 ;
	float s_len=0 , t_len=0 , c_len=0 , ss_count=0 ;

	float alpha = MaterialDiffuse.a  ;

	float3 NNormal = normalize(IN.Normal);
	float3 NEye = normalize( CameraPosition-IN.WPos);
	float3 NLight = normalize(LightDirection); 

    if ( use_texture ) {
		alpha *= tex2D( ObjTexSampler, IN.Tex ).a ;
	}
    if ( use_spheremap ) {
        alpha *= tex2D(ObjSphareSampler,IN.SpTex).a;
    }
    if( alpha < cut_alpha ){
		clip(-1) ;
    }

	float3 SSmapPos = mul( IN.WPos - CenterPos , transpose((float3x3)CenterRot )).xyz ;
	float2 SSmapTex = float2( (1+SSmapPos.x/ImageSize)/2+1.0/2048  , (1-SSmapPos.y/ImageSize)/2+1.0/2048 );
	float2 scaleUV = float2(0.5-morph_Umirror,0.5-morph_Vmirror) ;
	scaleUV = float2(scaleUV.x==0?1024:1/scaleUV.x , scaleUV.y==0?1024:1/scaleUV.y)/ImageSize/2 ;

	if( abs(SSmapPos.x)>ImageSize || abs(SSmapPos.y)>ImageSize || SSmapPos.z < 0  ){
		//
	}else{
		s_len = tex2D(SSmapSampler, float2(SSmapTex) ) ;
		t_len = SSmapPos.z/(abs(SSmapPos.z)+8)+0.00 ;
		ss_count += s_len - t_len > -0.0001 ? 4:0 ;

		ss_count += tex2D(SSmapSampler, float2(SSmapTex)+float2(1.0,0.0)/1024 ).r - t_len >-0.0001 ? 1:0 ;
		ss_count += tex2D(SSmapSampler, float2(SSmapTex)+float2(0.0,1.0)/1024 ).r - t_len >-0.0001 ? 1:0 ;
		ss_count += tex2D(SSmapSampler, float2(SSmapTex)-float2(1.0,0.0)/1024 ).r - t_len >-0.0001 ? 1:0 ;
		ss_count += tex2D(SSmapSampler, float2(SSmapTex)-float2(0.0,1.0)/1024 ).r - t_len >-0.0001 ? 1:0 ;
		ss_count = saturate(ss_count/4) ;

		GlassColor = tex2D(MaskTexSampler01, float2((1+SSmapPos.x*scaleUV.x)/2,(1-SSmapPos.y*scaleUV.y)/2 ) );

		if( ss_count > 0.0 ){
			Color.rgb += GlassColor.rgb*GlassColor.a*ss_count*(1-morph_weak_floor) ;
			Color.rgb *= alpha>block_alpha ? saturate(dot(NNormal,GlassNormal )*2.0+0.2) : alpha*(1+morph_on_alpha*2) ;
			Color.rgb *= dot(NNormal,NEye)>0 ? 1 : (1-alpha) ;
		}
	}
	Color.a = alpha ;



#ifndef NO_SHAFT 

	float3 CameraMapPos = mul( CameraPosition - CenterPos , transpose((float3x3)CenterRot )).xyz ;
	float4 RayAmount = 0 ;
	float3 mapPosLX=0 , mapPosMX=0 , mapPosLY=0, mapPosMY=0 , mapPosZ0=0 ;
	float3 RayMapPos = 0 ,startPos=0 , endPos=0 ;
	float2 RayTex = 0 ;
	float3 EyeVec = normalize(CameraMapPos - SSmapPos) ;

	c_len = length(CameraMapPos - SSmapPos) ;

	if( (SSmapPos.x>ImageSize && CameraMapPos.x>ImageSize ) || ( SSmapPos.x<-ImageSize && CameraMapPos.x<-ImageSize ) ){
		return Color ;
	}
	if( (SSmapPos.y>ImageSize && CameraMapPos.y>ImageSize ) || ( SSmapPos.y<-ImageSize && CameraMapPos.y<-ImageSize ) ){
		return Color ;
	}

	EyeVec.x = abs(EyeVec.x) < 1.0/65536 ? 1.0/65536 : EyeVec.x ;
	EyeVec.y = abs(EyeVec.y) < 1.0/65536 ? 1.0/65536 : EyeVec.y ;
	EyeVec.z = abs(EyeVec.z) < 1.0/65536 ? 1.0/65536 : EyeVec.z ;

	mapPosLX = SSmapPos - EyeVec *( SSmapPos.x - ImageSize )/(EyeVec.x) ;
	mapPosMX = SSmapPos - EyeVec *( SSmapPos.x + ImageSize )/(EyeVec.x) ;
	mapPosZ0 = SSmapPos - EyeVec *( SSmapPos.z )/(EyeVec.z) ;

	if( abs(mapPosLX.y) > ImageSize ){
		mapPosLX -= EyeVec *( mapPosLX.y - ImageSize*sign(mapPosLX.y) )/EyeVec.y ;
	}
	if( abs(mapPosMX.y) > ImageSize ){
		mapPosMX -= EyeVec *( mapPosMX.y - ImageSize*sign(mapPosMX.y) )/EyeVec.y ;
	}
	if( abs(mapPosZ0.x) < ImageSize && abs(mapPosZ0.y) < ImageSize && ((0>SSmapPos.z && 0<CameraMapPos.z)||(0<SSmapPos.z && 0>CameraMapPos.z)) ){
		GlassColor = tex2D(MaskTexSampler01, float2((1+mapPosZ0.x*scaleUV.x)/2,(1-mapPosZ0.y*scaleUV.y)/2 ) ) ;
		Color.rgb += GlassColor.rgb * GlassColor.a * morph_Glass_ON ;
	}

	startPos = mapPosLX + (mapPosMX-mapPosLX)/(SHAFT_LOOP+1.0)*frac(ftime*morph_transient/4) ;
	endPos = mapPosMX + (mapPosMX-mapPosLX)/(SHAFT_LOOP+1.0)*frac(ftime*morph_transient/4) ;

	[loop]
    for(float i = 1.0 ; i <= SHAFT_LOOP ; i++){
		RayMapPos = lerp( startPos , endPos , i /(SHAFT_LOOP+1.0) )  ;
		if( dot(RayMapPos-SSmapPos,RayMapPos-CameraMapPos)<0 ){
			RayTex = float2( (1+RayMapPos.x/ImageSize)/2+1/2048 , (1-RayMapPos.y/ImageSize)/2+1/2048 );
			s_len = tex2D(SSmapSampler, float2(RayTex) ) ;
			t_len = RayMapPos.z/(abs(RayMapPos.z)+8)+0.00 ;
			GlassColor = tex2D(MaskTexSampler01, float2((1+RayMapPos.x*scaleUV.x)/2,(1-RayMapPos.y*scaleUV.y)/2 ) );
			if( s_len - t_len > 0.0 ){
				RayAmount += (RayMapPos.z<0 && morph_BackGlass_OFF>0)? 0.0 : GlassColor*GlassColor.a  ;
			}else{
				RayAmount -= GlassColor*GlassColor.a*BlackShaft ;
			}
		}
	}

	RayAmount.rgb *= 1-morph_weak_shaft ;
	Color.rgb = saturate(Color + RayAmount*length(startPos-endPos)/128/(SHAFT_LOOP+1.0) ) ; //

#endif

	return Color ;
}


// technique
//
technique MainTec_ns < string MMDPass = "object";> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS();
        PixelShader  = compile ps_3_0 BufferShadow_PS();
//		CULLMODE = NONE ;
//		AlphaBlendEnable = false;
//		AlphaTestEnable = false;
    }
}

technique MainTec_ss  < string MMDPass = "object_ss";> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS();
        PixelShader  = compile ps_3_0 BufferShadow_PS();
//		CULLMODE = NONE ;
//		AlphaBlendEnable = false;
//		AlphaTestEnable = false;
   }
}


technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }

