////////////////////////////////////////////////////////////////////////////////////////////////
//
//  LargeBlur.fx v0.1
//  データP
//  でかい範囲のブラー
////////////////////////////////////////////////////////////////////////////////////////////////

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

// コントロール
float Tr : CONTROLOBJECT <string name="(self)"; string item="Tr";>;
float Si : CONTROLOBJECT <string name="(self)"; string item="Si";>;
static const float Siz = Si*0.1;
static const float MipSize = log2(Siz);

// 処理用テクスチャ
texture OrgScreen : RENDERCOLORTARGET <
	string Format = "D3DFMT_A8R8G8B8";
	float2 ViewPortRatio = {1,1};
	int MipLevels = 0;
>;
sampler OrgSampler = sampler_state {
	texture = <OrgScreen>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = MIRROR;
	AddressV  = MIRROR;
};
texture OrgSizeDepth : RENDERDEPTHSTENCILTARGET <
	float2 ViewPortRatio = {1.0,1.0};
	string Format = "D24S8";
>;

texture BlurTemp : RENDERCOLORTARGET <
	string Format = "D3DFMT_A8R8G8B8";
	float2 ViewPortRatio = {1,1};
>;
sampler BlurTempSampler = sampler_state {
	texture = <BlurTemp>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	AddressU  = MIRROR;
	AddressV  = MIRROR;
};

///////////////////////////////////////////////////////////////
// 汎用VS
struct CopyData {
	float4 Pos : POSITION;
	float2 Tex : TEXCOORD0;
};
float2 ViewportSize : VIEWPORTPIXELSIZE;
static const float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
static const float2 PixelSize = (float2(1,1)/(ViewportSize));

///////////////////////////////////////////////////////////////////
// ガウスブラー サイズ15
struct BLUR_DATA {
	float4 Pos:POSITION;
	float2 Tex:TEXCOORD0;
	float4 T1:TEXCOORD1;
	float4 T2:TEXCOORD2;
	float4 T3:TEXCOORD3;
	float4 T4:TEXCOORD4;
	float4 T5:TEXCOORD5;
	float4 T6:TEXCOORD6;
	float4 T7:TEXCOORD7;
};
BLUR_DATA BlurVS(float4 Pos:POSITION, float2 Tex:TEXCOORD0, uniform float2 dir){
	float blurStep = Siz*0.5*PixelSize;

	BLUR_DATA o;
	o.Pos = Pos;
	o.Tex = Tex + ViewportOffset;
	o.T1.xy = o.Tex + 1*blurStep*dir;
	o.T1.zw = o.Tex - 1*blurStep*dir;
	o.T2.xy = o.Tex + 2*blurStep*dir;
	o.T2.zw = o.Tex - 2*blurStep*dir;
	o.T3.xy = o.Tex + 3*blurStep*dir;
	o.T3.zw = o.Tex - 3*blurStep*dir;
	o.T4.xy = o.Tex + 4*blurStep*dir;
	o.T4.zw = o.Tex - 4*blurStep*dir;
	o.T5.xy = o.Tex + 5*blurStep*dir;
	o.T5.zw = o.Tex - 5*blurStep*dir;
	o.T6.xy = o.Tex + 6*blurStep*dir;
	o.T6.zw = o.Tex - 6*blurStep*dir;
	o.T7.xy = o.Tex + 7*blurStep*dir;
	o.T7.zw = o.Tex - 7*blurStep*dir;

	return o;
}

#define	WT_0	0.0920246
#define	WT_1	0.0902024
#define	WT_2	0.0849494
#define	WT_3	0.0768654
#define	WT_4	0.0668236
#define	WT_5	0.0558158
#define	WT_6	0.0447932
#define WT_7	0.0345379

float4 BlurLodPS(float2 Tex:TEXCOORD0, float4 T1:TEXCOORD1, float4 T2:TEXCOORD2, float4 T3:TEXCOORD3, float4 T4:TEXCOORD4, float4 T5:TEXCOORD5, float4 T6:TEXCOORD6, float4 T7:TEXCOORD7, uniform sampler map):COLOR{
	float4 r= WT_0 * tex2Dlod(map, float4(Tex,0,MipSize))
			+ WT_1 * tex2Dlod(map, float4(T1.xy,0,MipSize))
			+ WT_1 * tex2Dlod(map, float4(T1.zw,0,MipSize))
			+ WT_2 * tex2Dlod(map, float4(T2.xy,0,MipSize))
			+ WT_2 * tex2Dlod(map, float4(T2.zw,0,MipSize))
			+ WT_3 * tex2Dlod(map, float4(T3.xy,0,MipSize))
			+ WT_3 * tex2Dlod(map, float4(T3.zw,0,MipSize))
			+ WT_4 * tex2Dlod(map, float4(T4.xy,0,MipSize))
			+ WT_4 * tex2Dlod(map, float4(T4.zw,0,MipSize))
			+ WT_5 * tex2Dlod(map, float4(T5.xy,0,MipSize))
			+ WT_5 * tex2Dlod(map, float4(T5.zw,0,MipSize))
			+ WT_6 * tex2Dlod(map, float4(T6.xy,0,MipSize))
			+ WT_6 * tex2Dlod(map, float4(T6.zw,0,MipSize))
			+ WT_7 * tex2Dlod(map, float4(T7.xy,0,MipSize))
			+ WT_7 * tex2Dlod(map, float4(T7.zw,0,MipSize));
	return r;
}
float4 BlurPS(float2 Tex:TEXCOORD0, float4 T1:TEXCOORD1, float4 T2:TEXCOORD2, float4 T3:TEXCOORD3, float4 T4:TEXCOORD4, float4 T5:TEXCOORD5, float4 T6:TEXCOORD6, float4 T7:TEXCOORD7, uniform sampler map):COLOR{
	float4 r= WT_0 * tex2D(map, Tex)
			+ WT_1 * tex2D(map, T1.xy)
			+ WT_1 * tex2D(map, T1.zw)
			+ WT_2 * tex2D(map, T2.xy)
			+ WT_2 * tex2D(map, T2.zw)
			+ WT_3 * tex2D(map, T3.xy)
			+ WT_3 * tex2D(map, T3.zw)
			+ WT_4 * tex2D(map, T4.xy)
			+ WT_4 * tex2D(map, T4.zw)
			+ WT_5 * tex2D(map, T5.xy)
			+ WT_5 * tex2D(map, T5.zw)
			+ WT_6 * tex2D(map, T6.xy)
			+ WT_6 * tex2D(map, T6.zw)
			+ WT_7 * tex2D(map, T7.xy)
			+ WT_7 * tex2D(map, T7.zw);
	return lerp(tex2D(OrgSampler,Tex),r,Tr);
}

float4 ClearColor = {0,0,0,0};
float ClearDepth=1;
technique EqualizeTec <
	string Script = 
		"RenderColorTarget=OrgScreen;"
		"RenderDepthStencilTarget=OrgSizeDepth;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"

		"RenderColorTarget=BlurTemp;"
		"RenderDepthStencilTarget=OrgSizeDepth;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=BlurX;"

		"RenderColorTarget=;"
		"RenderDepthStencilTarget=;"
		"Pass=BlurY;"
	;
	>{
	pass BlurX < string Script= "Draw=Buffer;"; >{
		AlphaBlendEnable=false;
		VertexShader = compile vs_3_0 BlurVS(float2(1,0));
		PixelShader  = compile ps_3_0 BlurLodPS(OrgSampler);
	}
	pass BlurY < string Script= "Draw=Buffer;"; >{
		AlphaBlendEnable=false;
		VertexShader = compile vs_2_0 BlurVS(float2(0,1));
		PixelShader  = compile ps_2_0 BlurPS(BlurTempSampler);
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////
