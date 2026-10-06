//	g_GlassLadder_02.fx
//

// Parameters
//
float cut_alpha = 0.05 ;		// ìßâﬂËáíl(0Ç÷ãﬂéó)
float block_alpha = 0.95 ;		// é’åıËáíl(1Ç÷ãﬂéó)

// d=2
#define  WT_00  0.20416
#define  WT_01  0.18017
#define  WT_02  0.12383
#define  WT_03  0.06628
#define  WT_04  0.02763

/*
#define  WT_00  0.0920246
#define  WT_01  0.0902024
#define  WT_02  0.0849494
#define  WT_03  0.0768654
#define  WT_04  0.0668236
#define  WT_05  0.0558158
#define  WT_06  0.0447932
#define  WT_07  0.0345379
*/

// Declarations
//
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);


// ëÄçÏê›íËíl
//
#ifdef MIKUMIKUMOVING
float Tr : CONTROLOBJECT <string name="(self)"; string item="Tr";>;
float scaling0 : CONTROLOBJECT < string name = "(self)"; >;
float3 CenterPos: CONTROLOBJECT < string name = "(self)"; >;
float4x4 CenterRot: CONTROLOBJECT < string Name = "(self)"; >;

float morph_strong <
   string UIName = "åıã≠";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = -1.0;
   float UIMax =  1.0;
> = 0.0;
float morph_weak <
   string UIName = "åıé„";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = -1.0;
   float UIMax =  1.0;
> = 0.0;
float morph_r <
   string UIName = "ê‘";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = -1.0;
   float UIMax =  1.0;
> = 0.0;
float morph_g <
   string UIName = "óŒ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = -1.0;
   float UIMax =  1.0;
> = 0.0;
float morph_b <
   string UIName = "ê¬";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = -1.0;
   float UIMax =  1.0;
> = 0.0;
float morph_lerp <
   string UIName = "åıÇÃÇ›";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin =  0.0;
   float UIMax =  1.0;
> = 0.0;
float morph_post_blur <
   string UIName = "åıÇ⁄Ç©Çµ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin =  0.0;
   float UIMax =  1.0;
> = 0.0;

shared float morph_weak_shaft <
   string UIName = "åıèé„";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = -1.0;
   float UIMax =  1.0;
> = 0.0;
shared float morph_weak_floor <
   string UIName = "é ëúé„";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = -1.0;
   float UIMax =  1.0;
> = 0.0;
shared float morph_mini <
   string UIName = "èkè¨";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin =  0.0;
   float UIMax =  1.0;
> = 0.0;
shared float morph_Umirror <
   string UIName = "ç∂âEèkè¨îΩì]";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin =  0.0;
   float UIMax =  1.0;
> = 0.0;
shared float morph_Vmirror <
   string UIName = "è„â∫èkè¨îΩì]";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin =  0.0;
   float UIMax =  1.0;
> = 0.0;
shared float morph_Glass_ON <
   string UIName = "Glass_ON";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin =  0.0;
   float UIMax =  1.0;
> = 0.0;
shared float morph_BackGlass_OFF <
   string UIName = "Glassó†OFF";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin =  0.0;
   float UIMax =  1.0;
> = 0.0;
shared float morph_on_alpha <
   string UIName = "ìßâﬂçﬁéøÇ÷â¡éZ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = -1.0;
   float UIMax =  1.0;
> = 0.0;
shared float morph_transient <
   string UIName = "Ç‰ÇÁÇ¨";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = -1.0;
   float UIMax =  1.0;
> = 0.0;

#endif

#ifndef MIKUMIKUMOVING
#define	CONTROLLERNAME "(self)"
float4x4 CenterRot : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "ÉZÉìÉ^Å["; >;
float3 CenterPos : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "ÉZÉìÉ^Å["; >;
float morph_r : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "ê‘"; >;
float morph_g : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "óŒ"; >;
float morph_b : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "ê¬"; >;
float morph_strong : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "åıã≠"; >;
float morph_weak : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "åıé„"; >;
float morph_lerp : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "åıÇÃÇ›"; >;
float morph_post_blur : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "åıÇ⁄Ç©Çµ"; >;
float morph_on_alpha : CONTROLOBJECT < string name = CONTROLLERNAME; string item = "ìßñæçﬁéøÇ÷â¡éZ"; >;
#endif


// ViewPort
//
float2 ViewportSize : VIEWPORTPIXELSIZE;
static const float2 ViewportOffset = float2(0.5,0.5)/ViewportSize;
static const float2 pixStep = float2(1.0,1.0)/ViewportSize ; 
static const float2 BlurStep = float2(1.0,1.0)/float2(1.0,ViewportSize.y/ViewportSize.x)/1920*(1+morph_post_blur) ; 


// ViewPort Texture
//
texture OrgScreen : RENDERCOLORTARGET <
	string Format = "A8R8G8B8";
	float2 ViewPortRatio = {1,1};
>;
sampler OrgSampler = sampler_state {
	texture = <OrgScreen>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU  = CLAMP;
	AddressV  = CLAMP;
};

texture OrgSizeDepth : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;

#ifdef MIKUMIKUMOVING
shared texture GL2mapRT: OFFSCREENRENDERTARGET <
    string Description = "GL_map";
    float4 ClearColor = { 1, 1, 1 ,0 };
    float ClearDepth = 1.0;
//	string Format = "D3DFMT_A32B32G32R32F";
    string Format = "D3DFMT_R32F" ;
    int Width  = 1024*1.0 ;
    int Height = 1024*1.0 ;
    bool AntiAlias = false;
    int MipLevels = 1;		// none
    string DefaultEffect = 
        "self = hide;"
        "* = GL_map_02.fx;";
>;
sampler SSmapSampler = sampler_state {
    texture = <GL2mapRT>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
	AddressU  = Border ;
	AddressV = Border ;
	BorderColor = float4 ( 0,0,0,0 ) ;
};
#endif

texture GLdrawRT : OFFSCREENRENDERTARGET <
	string Description = "GL_draw";
	string Format = "A8R8G8B8";
	float2 ViewPortRatio = {1,1};
	float4 ClearColor = { 0, 0, 0, 0 };
	float ClearDepth = 1.0;
	bool AntiAlias = true;
//	bool AntiAlias = false;
	int Miplevels = 1;
	string DefaultEffect =
		"self = hide;"
        "* = GL_draw_02.fx;";
>;
sampler GlassSampler = sampler_state {
	texture = <GLdrawRT>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU  = Border ;
	AddressV = Border ;
	BorderColor = float4 ( 0,0,0,0 ) ;
};

#ifndef MIKUMIKUMOVING
shared texture GL2mapRT: OFFSCREENRENDERTARGET <
    string Description = "GL_map";
    float4 ClearColor = { 1, 1, 1 ,0 };
    float ClearDepth = 1.0;
//	string Format = "D3DFMT_A32B32G32R32F";
    string Format = "D3DFMT_R32F" ;
    int Width  = 1024*1.0 ;
    int Height = 1024*1.0 ;
    bool AntiAlias = false;
    int MipLevels = 1;		// none
    string DefaultEffect = 
        "self = hide;"
        "* = GL_map_02.fx;";
>;
sampler SSmapSampler = sampler_state {
    texture = <GL2mapRT>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
	AddressU  = Border ;
	AddressV = Border ;
	BorderColor = float4 ( 0,0,0,0 ) ;
};
#endif

texture2D ScnMap01 : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	int MipLevels = 1;
	 string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp01 = sampler_state {
    texture = <ScnMap01>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    string Format = "D24S8";
>;


// Shader
//
struct VS_OUTPUT {
   float4 Pos: POSITION;
   float2 Tex: TEXCOORD0;
};

VS_OUTPUT CopyVS(float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){ 
	VS_OUTPUT Out;
	Out.Pos = Pos;
	Out.Tex = Tex + ViewportOffset;
	return Out;
}

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color=0;

	Color += WT_00 * tex2D( GlassSampler, Tex );
	Color += WT_01 * ( tex2D( GlassSampler, Tex+float2(BlurStep.x   ,0) ) + tex2D( GlassSampler, Tex-float2(BlurStep.x   ,0) ) );
	Color += WT_02 * ( tex2D( GlassSampler, Tex+float2(BlurStep.x* 2,0) ) + tex2D( GlassSampler, Tex-float2(BlurStep.x* 2,0) ) );
	Color += WT_03 * ( tex2D( GlassSampler, Tex+float2(BlurStep.x* 3,0) ) + tex2D( GlassSampler, Tex-float2(BlurStep.x* 3,0) ) );
	Color += WT_04 * ( tex2D( GlassSampler, Tex+float2(BlurStep.x* 4,0) ) + tex2D( GlassSampler, Tex-float2(BlurStep.x* 4,0) ) );

	return Color ;
}

float4 MixGlassPS(float2 Tex: TEXCOORD0) : COLOR {
	float4 orgPix = tex2D(OrgSampler, Tex);
	float4 GlassMap = tex2D(SSmapSampler,float2(Tex.x,Tex.y)) ;
	float4 GlassPix = 0 ;
	float4 Color = orgPix ;
	float4 result = orgPix ;
	float4 addColor = 0 ;

	Color = WT_00 * tex2D( ScnSamp01, Tex );
	Color += WT_01 * ( tex2D( ScnSamp01, Tex+float2(0,BlurStep.y   ) ) + tex2D( ScnSamp01, Tex-float2(0,BlurStep.y   ) ) );
	Color += WT_02 * ( tex2D( ScnSamp01, Tex+float2(0,BlurStep.y* 2) ) + tex2D( ScnSamp01, Tex-float2(0,BlurStep.y*2) ) );
	Color += WT_03 * ( tex2D( ScnSamp01, Tex+float2(0,BlurStep.y* 3) ) + tex2D( ScnSamp01, Tex-float2(0,BlurStep.y*3) ) );
	Color += WT_04 * ( tex2D( ScnSamp01, Tex+float2(0,BlurStep.y* 4) ) + tex2D( ScnSamp01, Tex-float2(0,BlurStep.y*4) ) );
	GlassPix  = Color ;

	GlassPix.rgb = GlassPix.rgb * GlassPix.a * float3(morph_r+1,morph_g+1,morph_b+1) ;
	Color.rgb = orgPix.rgb * (1-morph_lerp) ;
	Color.rgb = Color.rgb + GlassPix.rgb*(1-morph_weak+morph_strong) ;
//	result.rgb += GlassMap.rgb ;
	result.rgb = Color.rgb ;

	return saturate(result) ;
}


// technique
//
float ClearDepth  = 1.0 ;
float4 ClearColor = {0.0,0.0,0.0,0.0} ;
//float4 ClearColor = {1.0,1.0,1.0,1.0} ;

technique PostEffectTec <
	string Script =
		"RenderColorTarget=OrgScreen;"
		"RenderDepthStencilTarget=OrgSizeDepth;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"

        "RenderColorTarget0=ScnMap01;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=Gaussian_X;"

		"RenderColorTarget=;"
		"RenderDepthStencilTarget=;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=MixGlass;"
	;
>{
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 CopyVS();
        PixelShader  = compile ps_3_0 PS_passX();
    }
	pass MixGlass < string Script = "Draw=Buffer;"; >{
		AlphaBlendEnable = false;
		AlphaTestEnable  = false;
		VertexShader = compile vs_3_0 CopyVS();
		PixelShader  = compile ps_3_0 MixGlassPS();
	}
};

