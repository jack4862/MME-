

float m_size : CONTROLOBJECT < string name = "(self)";string item = "閾値";>;
float m_scale : CONTROLOBJECT < string name = "(self)";string item = "大きさ";>;
float m_alpha : CONTROLOBJECT < string name = "(self)";string item = "強さ";>;
float m_gause : CONTROLOBJECT < string name = "(self)";string item = "BG_ボケ";>;

float m_r : CONTROLOBJECT < string name = "(self)";string item = "BG_R";>;
float m_g : CONTROLOBJECT < string name = "(self)";string item = "BG_G";>;
float m_b : CONTROLOBJECT < string name = "(self)";string item = "BG_B";>;

float m_rr : CONTROLOBJECT < string name = "(self)";string item = "回転R";>;
float m_rg : CONTROLOBJECT < string name = "(self)";string item = "回転G";>;
float m_rb : CONTROLOBJECT < string name = "(self)";string item = "回転B";>;

static float3 size = m_size/2;
static float scale = 1+m_scale*500;
static float gause = m_gause*10;
static float alpha = m_alpha;

static float rr = m_rr+0.5;
static float rg = m_rg+0.5;
static float rb = m_rb+0.5;

float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

// レンダリングターゲットのクリア値
static float4 BGColor = float4(m_r,m_g,m_b,0);
float4 ClearColor = float4(0.5,0.5,0.5,0);
float4 ClearColor2 = float4(0,0,0,1);
float ClearDepth  = 1.0;

//パターンテクスチャ
texture PatternTex
<
   string ResourceName = "mask.png";
>;
sampler PatternSamp = sampler_state {
    texture = <PatternTex>;
    AddressU  = WRAP;
    AddressV = WRAP;
    Filter = LINEAR;
};
// オリジナルの描画結果を記録するためのレンダーターゲット
texture2D ScnMap : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp = sampler_state {
    texture = <ScnMap>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
// X方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap2 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp2 = sampler_state {
    texture = <ScnMap2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

// Y方向のぼかし結果を記録するためのレンダーターゲット
texture2D ScnMap3 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0,1.0};
    int MipLevels = 1;
    string Format = "A8R8G8B8" ;
>;
sampler2D ScnSamp3 = sampler_state {
    texture = <ScnMap3>;
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
struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_passBBBB( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}


float2 GetMaskTex(float2 basetex,float rad)
{	
	float2 tex;
	tex.x = basetex.x * cos(rad) - basetex.y * sin(rad);
	tex.y = basetex.x * sin(rad) + basetex.y * cos(rad);
	return tex;
}
float GetCalcCol(float2 Tex,float2 mTex,float rad)
{
	float2 calcTex = floor(mTex*scale)/scale;
	float2 ct2;
	ct2.x = calcTex.x * cos(rad) - calcTex.y * sin(rad);
	ct2.y = calcTex.x * sin(rad) + calcTex.y * cos(rad);
	ct2.y /= ViewportSize.y/ViewportSize.x;
	
	
	float4 col = tex2D(ScnSamp,ct2);
	col = lerp(BGColor,col,col.a);
	//col = lerp(tex2D(ScnSamp3,ct2),col,col.a);
	
	return length(col.rgb)/1.8;
}
float time : TIME;
float4 PS_passBBBB(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;

	Color = tex2D( ScnSamp, Tex );

	float2 work = Tex;
	work.y *= ViewportSize.y/ViewportSize.x;
	
	
	
	float2 masktexR = GetMaskTex(work,rr);
	float2 masktexG = GetMaskTex(work,rg);
	float2 masktexB = GetMaskTex(work,rb);
	
	
	float3 mask;
	size.r /= 1-GetCalcCol(Tex,masktexR,-rr);
	size.g /= 1-GetCalcCol(Tex,masktexG,-rg);
	size.b /= 1-GetCalcCol(Tex,masktexB,-rb);
	
	
	mask.r = smoothstep(size.r,size.r+size.r*0.1+0.001,tex2D( PatternSamp, masktexR*scale));
	mask.g = smoothstep(size.g,size.g+size.g*0.1+0.001,tex2D( PatternSamp, masktexG*scale));
	mask.b = smoothstep(size.b,size.b+size.b*0.1+0.001,tex2D( PatternSamp, masktexB*scale));
	
	mask *= min(1.0,Color.a + tex2D(ScnSamp3,Tex).r);
	
	Color.rgb = lerp(BGColor,Color,Color.a);
	Color.rgb *= lerp(1-mask,1,alpha);
	Color.a = 1;
	//Color.a = saturate(mask.r+mask.g+mask.b);
	return Color;
}
//ガウスぼかし
////////////////////////////////////////////////////////////////////////////////////////////////

// ぼかし処理の重み係数：
//    ガウス関数 exp( -x^2/(2*d^2) ) を d=5, x=0～7 について計算したのち、
//    (WT_7 + WT_6 + … + WT_1 + WT_0 + WT_1 + … + WT_7) が 1 になるように正規化したもの
#define  WT_0  0.0920246
#define  WT_1  0.0902024
#define  WT_2  0.0849494
#define  WT_3  0.0768654
#define  WT_4  0.0668236
#define  WT_5  0.0558158
#define  WT_6  0.0447932
#define  WT_7  0.0345379


static float2 SampStep = (float2(gause,gause)/ViewportSize);


VS_OUTPUT VS_passX( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(0, ViewportOffset.y);
    
    return Out;
}

float4 PS_passX( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;
	
	Color  = WT_0 *   tex2D( ScnSamp, Tex );
	Color += WT_1 * ( tex2D( ScnSamp, Tex+float2(SampStep.x  ,0) ) + tex2D( ScnSamp, Tex-float2(SampStep.x  ,0) ) );
	Color += WT_2 * ( tex2D( ScnSamp, Tex+float2(SampStep.x*2,0) ) + tex2D( ScnSamp, Tex-float2(SampStep.x*2,0) ) );
	Color += WT_3 * ( tex2D( ScnSamp, Tex+float2(SampStep.x*3,0) ) + tex2D( ScnSamp, Tex-float2(SampStep.x*3,0) ) );
	Color += WT_4 * ( tex2D( ScnSamp, Tex+float2(SampStep.x*4,0) ) + tex2D( ScnSamp, Tex-float2(SampStep.x*4,0) ) );
	Color += WT_5 * ( tex2D( ScnSamp, Tex+float2(SampStep.x*5,0) ) + tex2D( ScnSamp, Tex-float2(SampStep.x*5,0) ) );
	Color += WT_6 * ( tex2D( ScnSamp, Tex+float2(SampStep.x*6,0) ) + tex2D( ScnSamp, Tex-float2(SampStep.x*6,0) ) );
	Color += WT_7 * ( tex2D( ScnSamp, Tex+float2(SampStep.x*7,0) ) + tex2D( ScnSamp, Tex-float2(SampStep.x*7,0) ) );
	
	Color.rgb = 1;
    return Color;
}

float4 PS_passX2( float2 Tex: TEXCOORD0 ) : COLOR {   
    float4 Color;
	
	Color  = WT_0 *   tex2D( ScnSamp3, Tex );
	Color += WT_1 * ( tex2D( ScnSamp3, Tex+float2(SampStep.x  ,0) ) + tex2D( ScnSamp3, Tex-float2(SampStep.x  ,0) ) );
	Color += WT_2 * ( tex2D( ScnSamp3, Tex+float2(SampStep.x*2,0) ) + tex2D( ScnSamp3, Tex-float2(SampStep.x*2,0) ) );
	Color += WT_3 * ( tex2D( ScnSamp3, Tex+float2(SampStep.x*3,0) ) + tex2D( ScnSamp3, Tex-float2(SampStep.x*3,0) ) );
	Color += WT_4 * ( tex2D( ScnSamp3, Tex+float2(SampStep.x*4,0) ) + tex2D( ScnSamp3, Tex-float2(SampStep.x*4,0) ) );
	Color += WT_5 * ( tex2D( ScnSamp3, Tex+float2(SampStep.x*5,0) ) + tex2D( ScnSamp3, Tex-float2(SampStep.x*5,0) ) );
	Color += WT_6 * ( tex2D( ScnSamp3, Tex+float2(SampStep.x*6,0) ) + tex2D( ScnSamp3, Tex-float2(SampStep.x*6,0) ) );
	Color += WT_7 * ( tex2D( ScnSamp3, Tex+float2(SampStep.x*7,0) ) + tex2D( ScnSamp3, Tex-float2(SampStep.x*7,0) ) );
	
    return Color;
}
////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし

VS_OUTPUT VS_passY( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(ViewportOffset.x, 0);
    
    return Out;
}

float4 PS_passY(float2 Tex: TEXCOORD0) : COLOR
{   
    float4 Color;
	
	Color  = WT_0 *   tex2D( ScnSamp2, Tex );
	Color += WT_1 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y  ) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y  ) ) );
	Color += WT_2 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*2) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*2) ) );
	Color += WT_3 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*3) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*3) ) );
	Color += WT_4 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*4) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*4) ) );
	Color += WT_5 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*5) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*5) ) );
	Color += WT_6 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*6) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*6) ) );
	Color += WT_7 * ( tex2D( ScnSamp2, Tex+float2(0,SampStep.y*7) ) + tex2D( ScnSamp2, Tex-float2(0,SampStep.y*7) ) );
	
	
    return Color;
}
////////////////////////////////////////////////////////////////////////////////////////////////

technique Gaussian <
    string Script = 
        
        "RenderColorTarget0=ScnMap;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "ScriptExternal=Color;"
	    
	    
        "RenderColorTarget0=ScnMap2;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor2;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=Gaussian_X;"
        "RenderColorTarget0=ScnMap3;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=Gaussian_Y;"
	    
	    "RenderColorTarget0=ScnMap2;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor2;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=Gaussian_X2;"
        "RenderColorTarget0=ScnMap3;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=Gaussian_Y;"
	    	    
	    "RenderColorTarget0=ScnMap2;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor2;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=Gaussian_X2;"
        "RenderColorTarget0=ScnMap3;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=Gaussian_Y;"
	    
	    	    
	    "RenderColorTarget0=ScnMap2;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor2;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=Gaussian_X2;"
        "RenderColorTarget0=ScnMap3;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=Gaussian_Y;"
	    	    
	    "RenderColorTarget0=ScnMap2;"
	    "RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColor2;"
		"ClearSetDepth=ClearDepth;"
		"Clear=Color;"
		"Clear=Depth;"
	    "Pass=Gaussian_X2;"
        "RenderColorTarget0=ScnMap3;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=Gaussian_Y;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=BBBB;"
    ;
> {

    pass BBBB < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_3_0 VS_passBBBB();
        PixelShader  = compile ps_3_0 PS_passBBBB();
    }
    pass Gaussian_X < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passX();
        PixelShader  = compile ps_2_0 PS_passX();
    }
    pass Gaussian_X2 < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passX();
        PixelShader  = compile ps_2_0 PS_passX2();
    }
    pass Gaussian_Y < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_2_0 VS_passY();
        PixelShader  = compile ps_2_0 PS_passY();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
