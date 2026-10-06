////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Croquis.fx v0.12
//  データP
//
////////////////////////////////////////////////////////////////////////////////////////////////

#define HalfDistance 50

#define MapTimes 2

float4 FrontColor <
	string UIName = "線の色";
	string UIWidget = "Color";
	bool UIVisible =  true;
	float3 UIDefault = float4(0, 0, 0, 1);
> = float4( 0 , 0 , 0 , 1 );

float4 BackColor <
	string UIName = "地の色";
	string UIWidget = "Color";
	bool UIVisible =  true;
	float3 UIDefault = float4(1, 1, 1, 1);
> = float4( 1 , 1 , 1 , 1 );

float4 ClearColor = float4(0,0,0,0);

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

float Tr : CONTROLOBJECT <string name="(self)"; string item="Tr";>;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

// 法線マップ
texture CM_NormalMap : OFFSCREENRENDERTARGET <
	string Description = "NormalMap";
	string Format = "D3DFMT_A8R8G8B8";
	float2 ViewPortRatio = {MapTimes,MapTimes};
	float4 ClearColor = {0,0,1,0};
	float ClearDepth = 1.0;
	bool AntiAlias = false;
	int Miplevels = 1;
	string DefaultEffect =
	    "self=hide;"
	    "*=NormalDraw.fx;";
>;
sampler NormalMapSampler = sampler_state {
	texture = <CM_NormalMap>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

// 深度マップ
texture CM_DepthMap : OFFSCREENRENDERTARGET <
	string Description = "DepthMap";
	string Format = "D3DFMT_R32F";
	float2 ViewPortRatio = {MapTimes,MapTimes};
	float4 ClearColor = {1,0,1,0};
	float ClearDepth = 1.0;
	bool AntiAlias = false;
	int Miplevels = 1;
	string DefaultEffect =
		"self=hide;"
	    "*=DepthDraw.fx;";
>;
sampler DepthMapSampler = sampler_state {
	texture = <CM_DepthMap>;
	MinFilter = POINT;
	MagFilter = POINT;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

// エッジを作った後の処理用
texture EdgeMap : RENDERCOLORTARGET <
	string Format = "D3DFMT_A8R8G8B8";
	float2 ViewPortRatio = {MapTimes,MapTimes};
>;
texture2D EdgeDepth : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {MapTimes,MapTimes};
	string Format = "D24S8";
>;
sampler EdgeMapSampler = sampler_state {
	texture = <EdgeMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

texture ColorMap : RENDERCOLORTARGET <
	string Format = "D3DFMT_A8R8G8B8";
	float2 ViewPortRatio = {1,1};
>;
sampler ColorMapSampler = sampler_state {
	texture = <ColorMap>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

texture OrgSizeDepth : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;

///////////////////////////////////////////////////////////////
// 汎用VS
struct CopyData {
	float4 Pos : POSITION;
	float2 Tex : TEXCOORD0;
};
struct Copy2Data {
	float4 Pos : POSITION;
	float2 Tex0 : TEXCOORD0;
	float2 Tex1 : TEXCOORD1;
};
float2 ViewportSize : VIEWPORTPIXELSIZE;
static const float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static const float2 EdgeMapOffset = (float2(0.5,0.5)/(ViewportSize*MapTimes));
static const float2 PixelSize = (float2(1,1)/(ViewportSize));
static const float2 MapPixelSize = (float2(1,1)/(ViewportSize*MapTimes));

CopyData CopyVS(float4 Pos : POSITION, float2 Tex : TEXCOORD0, uniform float2 Offset){
	CopyData o;
	o.Pos = Pos;
	o.Tex = Tex + Offset;
	return o;
}

Copy2Data Copy2VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0, uniform float2 Offset0, uniform float2 Offset1){
	Copy2Data o;
	o.Pos = Pos;
	o.Tex0 = Tex + Offset0;
	o.Tex1 = Tex + Offset1;
	return o;
}


///////////////////////////////////////////////////////////////
// エッジを作る
float DepthFromPoint(float2 xy){
	float depth = tex2D(DepthMapSampler, xy).r;
	return depth;
}
float3 NormalFromPoint(float2 xy){
	float3 n=tex2D(NormalMapSampler, xy);
	return normalize(2*n.xyz-float3(1,1,1));
}

float3 ColorFromPoint(float2 xy){
	float3 c=tex2D(ColorMapSampler, xy).rgb;
	return c;
}

float ddEdge(float2 xy){
	float3 oN=NormalFromPoint(xy);
	float oZ=DepthFromPoint(xy);
	float3 oC=ColorFromPoint(xy);

	float3 dN1=NormalFromPoint(xy + float2(-1,0)*MapPixelSize);
	float3 dN2=NormalFromPoint(xy + float2(0,-1)*MapPixelSize);
	float3 dN3=NormalFromPoint(xy + float2(-1,1)*MapPixelSize);
	float3 dN4=NormalFromPoint(xy + float2(-1,-1)*MapPixelSize);

	float dZ1=DepthFromPoint(xy + float2(-1,0)*MapPixelSize);
	float dZ2=DepthFromPoint(xy + float2(0,-1)*MapPixelSize);
	float dZ3=DepthFromPoint(xy + float2(-1,1)*MapPixelSize);
	float dZ4=DepthFromPoint(xy + float2(-1,-1)*MapPixelSize);

	float3 dC1=ColorFromPoint(xy + float2(-1,0)*PixelSize);
	float3 dC2=ColorFromPoint(xy + float2(0,-1)*PixelSize);
	float3 dC3=ColorFromPoint(xy + float2(-1,1)*PixelSize);
	float3 dC4=ColorFromPoint(xy + float2(-1,-1)*PixelSize);

	float ddN = dot(oN-dN1,oN-dN1) + dot(oN-dN2,oN-dN2) + 0.7*dot(oN-dN3,oN-dN3) + 0.7*dot(oN-dN4,oN-dN4);
	float4 ddZZ = float4(oZ-dZ1, oZ-dZ2, 0.7*(oZ-dZ3), 0.7*(oZ-dZ4));
	float ddZ = dot(ddZZ,ddZZ);
	float ddC = dot(oC-dC1,oC-dC1) + dot(oC-dC2,oC-dC2) + 0.7*dot(oC-dC3,oC-dC3) + 0.7*dot(oC-dC4,oC-dC4);

	return saturate(max(0,ddN-0.5)*2 + max(0,ddZ-0.0001)*7000 + max(0, ddC-0.02)*30);
}

float4 EdgePS(float2 Tex: TEXCOORD0):COLOR{
	return  float4((1.0-ddEdge(Tex))*float3(1,1,1),1);
}

float4 MixPS(float2 Tex:TEXCOORD0, float2 MapTex:TEXCOORD1):COLOR{
	float e0=   0.25*tex2D(EdgeMapSampler,MapTex)
				+ 0.125*(tex2D(EdgeMapSampler,MapTex + float2(0,-1)*MapPixelSize)
						+ tex2D(EdgeMapSampler,MapTex + float2(0,1)*MapPixelSize)
						+ tex2D(EdgeMapSampler,MapTex + float2(1,0)*MapPixelSize)
						+ tex2D(EdgeMapSampler,MapTex + float2(-1,0)*MapPixelSize) )
				+ 0.0625*(tex2D(EdgeMapSampler,MapTex + float2(-1,-1)*MapPixelSize)
						+ tex2D(EdgeMapSampler,MapTex + float2(1,1)*MapPixelSize)
						+ tex2D(EdgeMapSampler,MapTex + float2(1,-1)*MapPixelSize)
						+ tex2D(EdgeMapSampler,MapTex + float2(-1,1)*MapPixelSize) );
	float4 color = lerp(FrontColor,BackColor,e0);
	float t = Tr*color.a;
	color.a=1;
	return lerp(tex2D(ColorMapSampler,Tex), color ,t);
}

float ClearDepth=1;
technique ComicEdgeTec <
	string Script = 
		"RenderColorTarget=ColorMap;"
		"RenderDepthStencilTarget=OrgSizeDepth;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"

		"RenderColorTarget=EdgeMap;"
		"RenderDepthStencilTarget=EdgeDepth;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=DrawEdge;"

		"RenderColorTarget=;"
		"RenderDepthStencilTarget=;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=DrawMix;"
	;
	>{
	pass DrawEdge < string Script= "Draw=Buffer;"; >{
		AlphaBlendEnable=false;
		AlphaTestEnable=false;
		ZWriteEnable=false;
		VertexShader = compile vs_3_0 CopyVS(EdgeMapOffset);
		PixelShader  = compile ps_3_0 EdgePS();
	}
	pass DrawMix < string Script= "Draw=Buffer;"; >{
		AlphaBlendEnable=false;
		AlphaTestEnable=false;
		ZWriteEnable=false;
		VertexShader = compile vs_3_0 Copy2VS(ViewportOffset, EdgeMapOffset);
		PixelShader  = compile ps_3_0 MixPS();
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////
