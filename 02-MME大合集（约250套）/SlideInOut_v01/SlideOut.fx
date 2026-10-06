////////////////////////////////////////////////////////////////////////////////////////////////
//
//  SlideOut.fx v0.1
//  作成: データP
//
////////////////////////////////////////////////////////////////////////////////////////////////

// ポストエフェクト宣言
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

float4x4 WorldMatrix : CONTROLOBJECT <string name="(self)";>;
float Tr : CONTROLOBJECT <string name="(self)"; string item="Tr";>;
float Si : CONTROLOBJECT <string name="(self)"; string item="Si";>;
float2 ViewportSize : VIEWPORTPIXELSIZE;
static const float2 ViewportOffset = float2(0.5,0.5)/ViewportSize;
static const float2 XY = WorldMatrix._41_42;

// キャプチャ映像
texture CurrentPictureTex : RENDERCOLORTARGET <>;
texture PrevPictureTex : RENDERCOLORTARGET <>;
texture DepthBuffer : RENDERDEPTHSTENCILTARGET <>;

sampler CurrentPicture = sampler_state {
	texture = <CurrentPictureTex>;
    MINFILTER = POINT;
    MAGFILTER = POINT;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

sampler PrevPicture = sampler_state {
	texture = <PrevPictureTex>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
	AddressU  = BORDER;
	AddressV = BORDER;
	BorderColor = float4(0,0,0,0);
};



/////////////////////////////
// コピー用のシェーダ
struct CopyToPrev_DATA {
   float4 Pos: POSITION;
   float2 Tex: TEXCOORD0;
};

CopyToPrev_DATA CopyToPrevVS(float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){ 
	CopyToPrev_DATA Out;
	Out.Pos = Pos;
	Out.Pos.z = Tr==1 ? Pos.z : -1;
	Out.Tex = Tex+ViewportOffset;
	return Out;
}
float4 CopyToPrevPS(float2 Tex: TEXCOORD0) : COLOR {
	return float4(tex2D(CurrentPicture,Tex).rgb,1);
}

struct Mix_DATA {
   float4 Pos: POSITION;
   float2 Tex: TEXCOORD0;
   float2 PrevTex: TEXCOORD1;
};

Mix_DATA SlideOutVS(float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){ 
	Mix_DATA Out;
	Out.Pos = Pos;
	Out.Tex = Tex+ViewportOffset;

	float2 cur =  (-XY*(1-Tr) + float2(Tex.x*2-1, 1-Tex.y*2))/lerp(Si*0.1+0.00001, 1, Tr);
	Out.PrevTex = float2(cur.x*0.5+0.5, 0.5-0.5*cur.y)+ViewportOffset;
	return Out;
}
float4 SlideOutPS(float2 Tex: TEXCOORD0, float2 PrevTex: TEXCOORD1) : COLOR {
	float4 prev = tex2D(PrevPicture,PrevTex);
	float4 cur = tex2D(CurrentPicture,Tex);
	float2 sat = saturate(PrevTex);
	return (sat.x!=PrevTex.x || sat.y!=PrevTex.y) ? cur : prev;
}

float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1;

technique CrossFadeTec <
	string Script =
		"RenderColorTarget=CurrentPictureTex;"
		"RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
		"ScriptExternal=Color;"
		"RenderColorTarget=PrevPictureTex;"
		"Clear=Depth;"
		"Pass=CopyToPrev;"
		"RenderColorTarget=;"
		"RenderDepthStencilTarget=;"
		"Clear=Color;"
		"Clear=Depth;"
		"Pass=SlideOut;"
	;
>{
	pass CopyToPrev < string Script = "Draw=Buffer;"; >{
		VertexShader = compile vs_2_0 CopyToPrevVS();
		PixelShader  = compile ps_2_0 CopyToPrevPS();
	}
	pass SlideOut < string Script = "Draw=Buffer;"; >{
		VertexShader = compile vs_2_0 SlideOutVS();
		PixelShader  = compile ps_2_0 SlideOutPS();
	}
};
