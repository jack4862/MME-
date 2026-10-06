////////////////////////////////////////////////////////////////////////////////////////////////
//
//  FinderMonitorB.fx v0.12b
//  データP
//  FinderMonitorをベースに、XYで操作できるように改変
//
////////////////////////////////////////////////////////////////////////////////////////////////

#define DefaultSize (1.0/3.0)

// 座法変換行列
float4x4 VMatrix : VIEW;
float4x4 PMatrix : PROJECTION;

float3 FinderCenter : CONTROLOBJECT <string name="(self)"; string item="XYZ";>;
float scaling : CONTROLOBJECT <string name = "(self)"; >;
float alpha : CONTROLOBJECT <string name = "(self)"; string item="Tr";>;


// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

#define VMatrix_Offset 0
#define PMatrix_Offset 4
#define MemorySize 8
shared texture FinderMemory : RENDERCOLORTARGET <
	int Width=MemorySize;
	int Height=1;
    bool AntiAlias = false;
	int MipLevels = 1;
	string Format = "D3DFMT_A32B32G32R32F";
>;

float4 FinderArray[MemorySize] : TEXTUREVALUE <
	string TextureName = "FinderMemory";
>;

sampler2D FinderMemSampler = sampler_state {
	texture = <FinderMemory>;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};


texture2D MemoryDepth : RENDERDEPTHSTENCILTARGET <
	int Width=MemorySize;
	int Height=1;
    string Format = "D24S8";
>;

texture FinderTex : OFFSCREENRENDERTARGET <
	string Description = "FinderMonitor";
	float4 ClearColor = { 1, 1, 1, 1 };
	float ClearDepth = 1.0;
	bool AntiAlias = true;
	int Miplevels = 0;
	string DefaultEffect = 
	"self = hide;"
	"*=FinderDrawB.fx;";
>;
sampler2D FinderSampler = sampler_state {
	texture = <FinderTex>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge";>{}
technique ShadowTec < string MMDPass = "shadow"; > {}
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {}

/////////////////////////////////////////////////////////////////////////////
// MemoryRecording
// +0～+3 VMatrix
// +4～+7 PMatrix
struct Rec_Out {
	float4 Pos: POSITION;
	float Index: TEXCOORD0;
};
float4 LMouseDown : LEFTMOUSEDOWN;
float4 RMouseDown : RIGHTMOUSEDOWN;
static const bool ReqRecord = (LMouseDown.z * RMouseDown.z)!=0;

Rec_Out Rec_VS(float4 Pos:POSITION, float2 Tex:TEXCOORD0){
	Rec_Out o;
	o.Pos = Pos;
	o.Index = Tex.x + 0.5/MemorySize;
	return o;
}

float4 Rec_PS(Rec_Out In):COLOR{
	clip(ReqRecord - 1.0);
	int idx=(int)floor(In.Index*MemorySize);
	return idx<PMatrix_Offset ? VMatrix[(idx-VMatrix_Offset)] : PMatrix[idx-PMatrix_Offset];
}

///////////////////////////////////////////////////////////////////////////////////////////////
// FinderDraw
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 FrameSize = (float2(1,1)/ViewportSize);
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

struct Finder_Out {
	float4 Pos: POSITION;
	float2 Tex: TEXCOORD0;
};
Finder_Out Finder_VS(float4 Pos:POSITION, float2 Tex:TEXCOORD0){
	Finder_Out o;
	o.Pos=float4(Pos.xy*scaling*0.1*DefaultSize + FinderCenter.xy,0,1);
	o.Tex=Tex+ViewportOffset;
	return o;
}

float4 Finder_PS(float2 Tex:TEXCOORD0) : COLOR0 {
	return float4(tex2D(FinderSampler,Tex).rgb,alpha);
}

///////////////////////////////////////////////////////////////////////////////////////////////
// FrameDraw
struct Frame_Out {
	float4 Pos: POSITION;
	float2 Rate: TEXCOORD0;
};
Frame_Out Frame_VS(float4 Pos:POSITION, float2 Tex:TEXCOORD0) {
	Frame_Out o;
	o.Pos=float4(Pos.xy*scaling*0.1*DefaultSize + Pos.xy*FrameSize + FinderCenter.xy,0,1);
	o.Rate=Pos.xy + Pos.xy*FrameSize/(scaling*0.1*DefaultSize);
	return o;
}

float4 Frame_PS(Frame_Out In) : COLOR0 {
	if(In.Rate.x<=1.0 && In.Rate.x>=-1.0 && In.Rate.y<=1.0 && In.Rate.y>=-1.0){
		discard;
	}
	return float4(0.2,0.2,0.2,alpha);
}
technique FinderTec <
	string MMDPass = "object";
	string Script = 
		"RenderColorTarget=FinderMemory;"
			"RenderDepthStencilTarget=MemoryDepth;"
			"Pass=DrawMemory;"
		"RenderColorTarget=;"
			"RenderDepthStencilTarget=;"
			"Pass=DrawFrame;"
			"Pass=DrawFinder;"
	;
	>{
	pass DrawMemory < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable=false;
		ZEnable = false;
	    AlphaTestEnable = false;
		VertexShader = compile vs_2_0 Rec_VS();
		PixelShader  = compile ps_2_0 Rec_PS();
	}
	pass DrawFinder {
		VertexShader = compile vs_2_0 Finder_VS();
		PixelShader  = compile ps_2_0 Finder_PS();
	}
	pass DrawFrame {
	    FillMode = WIREFRAME;
		VertexShader = compile vs_2_0 Frame_VS();
		PixelShader  = compile ps_2_0 Frame_PS();
	}
}

technique FinderSSTec <
	string MMDPass = "object_SS";
	string Script = 
		"RenderColorTarget=FinderMemory;"
			"RenderDepthStencilTarget=MemoryDepth;"
			"Pass=DrawMemory;"
		"RenderColorTarget=;"
			"RenderDepthStencilTarget=;"
			"Pass=DrawFrame;"
			"Pass=DrawFinder;"
	;
	>{
	pass DrawMemory < string Script= "Draw=Buffer;"; > {
		AlphaBlendEnable=false;
		ZEnable = false;
	    AlphaTestEnable = false;
		VertexShader = compile vs_2_0 Rec_VS();
		PixelShader  = compile ps_2_0 Rec_PS();
	}
	pass DrawFinder {
		VertexShader = compile vs_2_0 Finder_VS();
		PixelShader  = compile ps_2_0 Finder_PS();
	}
	pass DrawFrame {
	    FillMode = WIREFRAME;
		VertexShader = compile vs_2_0 Frame_VS();
		PixelShader  = compile ps_2_0 Frame_PS();
	}
}


///////////////////////////////////////////////////////////////////////////////////////////////
