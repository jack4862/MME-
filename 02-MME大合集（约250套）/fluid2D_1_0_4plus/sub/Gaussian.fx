//----水面用ブラー

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


struct VS_OUTPUT_Gaussian {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};
struct PS_OUTPUT2_Gaussian {
	float4 Col0 : COLOR0;
	float4 Col1 : COLOR0;	
};
////////////////////////////////////////////////////////////////////////////////////////////////
// X方向ぼかし

VS_OUTPUT_Gaussian VS_passX( float4 Pos : POSITION, float2 Tex : TEXCOORD0 ) {
    VS_OUTPUT_Gaussian Out = (VS_OUTPUT_Gaussian)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + float2(0, ViewportOffset.y);
    
    return Out;
}

float4 GausX(sampler2D samp,float2 Tex,float2 SampStep)
{
    float4 Color;
	Color  = WT_0 *   tex2D( samp, Tex );
	Color += WT_1 * ( tex2D( samp, Tex+float2(SampStep.x  ,0) ) + tex2D( samp, Tex-float2(SampStep.x  ,0) ) );
	Color += WT_2 * ( tex2D( samp, Tex+float2(SampStep.x*2,0) ) + tex2D( samp, Tex-float2(SampStep.x*2,0) ) );
	Color += WT_3 * ( tex2D( samp, Tex+float2(SampStep.x*3,0) ) + tex2D( samp, Tex-float2(SampStep.x*3,0) ) );
	Color += WT_4 * ( tex2D( samp, Tex+float2(SampStep.x*4,0) ) + tex2D( samp, Tex-float2(SampStep.x*4,0) ) );
	Color += WT_5 * ( tex2D( samp, Tex+float2(SampStep.x*5,0) ) + tex2D( samp, Tex-float2(SampStep.x*5,0) ) );
	Color += WT_6 * ( tex2D( samp, Tex+float2(SampStep.x*6,0) ) + tex2D( samp, Tex-float2(SampStep.x*6,0) ) );
	Color += WT_7 * ( tex2D( samp, Tex+float2(SampStep.x*7,0) ) + tex2D( samp, Tex-float2(SampStep.x*7,0) ) );

    return Color;
}
float4 GausY(sampler2D samp,float2 Tex,float2 SampStep)
{
    float4 Color;
	
	Color  = WT_0 *   tex2D( samp, Tex );
	Color += WT_1 * ( tex2D( samp, Tex+float2(0,SampStep.y  ) ) + tex2D( samp, Tex-float2(0,SampStep.y  ) ) );
	Color += WT_2 * ( tex2D( samp, Tex+float2(0,SampStep.y*2) ) + tex2D( samp, Tex-float2(0,SampStep.y*2) ) );
	Color += WT_3 * ( tex2D( samp, Tex+float2(0,SampStep.y*3) ) + tex2D( samp, Tex-float2(0,SampStep.y*3) ) );
	Color += WT_4 * ( tex2D( samp, Tex+float2(0,SampStep.y*4) ) + tex2D( samp, Tex-float2(0,SampStep.y*4) ) );
	Color += WT_5 * ( tex2D( samp, Tex+float2(0,SampStep.y*5) ) + tex2D( samp, Tex-float2(0,SampStep.y*5) ) );
	Color += WT_6 * ( tex2D( samp, Tex+float2(0,SampStep.y*6) ) + tex2D( samp, Tex-float2(0,SampStep.y*6) ) );
	Color += WT_7 * ( tex2D( samp, Tex+float2(0,SampStep.y*7) ) + tex2D( samp, Tex-float2(0,SampStep.y*7) ) );

    return Color;
}


float4 PS_passX( float2 Tex: TEXCOORD0,uniform sampler2D samp,uniform float step ) : COLOR {  
	float2 SampStep = (float2(step,step)/ViewportSize); 
    float4 Color = GausX(samp,Tex,SampStep);

    return Color;
}
PS_OUTPUT2_Gaussian PS_passX2( float2 Tex: TEXCOORD0,uniform sampler2D samp,uniform sampler2D samp2,uniform float step ) : COLOR {  
	PS_OUTPUT2_Gaussian Out = (PS_OUTPUT2_Gaussian)0;
	
	float2 SampStep = (float2(step,step)/ViewportSize); 
    Out.Col0 = GausX(samp,Tex,SampStep);
    Out.Col1 = GausX(samp2,Tex,SampStep);
    return Out;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// Y方向ぼかし

VS_OUTPUT_Gaussian VS_passY( float4 Pos : POSITION, float2 Tex : TEXCOORD0 ){
    VS_OUTPUT_Gaussian Out = (VS_OUTPUT_Gaussian)0; 
    
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    
    return Out;
}

float4 PS_passY(float2 Tex: TEXCOORD0,uniform sampler2D samp,uniform float step ) : COLOR
{   
	float2 SampStep = (float2(step,step)/ViewportSize); 
    float4 Color = GausY(samp,Tex,SampStep);

    return Color;
}
PS_OUTPUT2_Gaussian PS_passY2(float2 Tex: TEXCOORD0,uniform sampler2D samp,uniform sampler2D samp2,uniform float step ) : COLOR
{   
	PS_OUTPUT2_Gaussian Out = (PS_OUTPUT2_Gaussian)0;
	
	float2 SampStep = (float2(step,step)/ViewportSize); 
    Out.Col0 = GausY(samp,Tex,SampStep);
    Out.Col1 = GausY(samp2,Tex,SampStep);
    return Out;
}