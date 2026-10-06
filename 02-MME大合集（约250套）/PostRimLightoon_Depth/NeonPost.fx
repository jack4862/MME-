//色
float3 ToonColSet = float3(0.3,0.3,0.3);

//線太さ
float LineSizeSet = 3.0;

//閾値
float ThresholdSet = 6.0;


// 深度の最大値
#define FAR_DEPTH 5000

float3 XYZ : CONTROLOBJECT < string name = "(self)"; string item = "XYZ"; >;
float3 Rxyz : CONTROLOBJECT < string name = "(self)"; string item = "Rxyz"; >;
float Si : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float Tr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

float4x4 ProjMatrix         : PROJECTION;


static float AccLineSize = Rxyz.x;

static float3 ToonCol = ToonColSet + XYZ/10;
static float LineSize = LineSizeSet + AccLineSize;
static float Threshold = ThresholdSet + Rxyz.y;




float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;

static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;

//フォグ用Z深度用RT
texture NeonPost_DepthRT: OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for NeonPost.fx";
    float4 ClearColor = { 1, 0, 0, 1 };
    string Format="D3DFMT_R32F";
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    
    string DefaultEffect = 
        "self = hide;"
        "* = DrawZ.fx;";
>;
sampler DepthSamp = sampler_state
{
   Texture = (NeonPost_DepthRT);
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   FILTER = NONE;
};

struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};

static float2 SampStep = (float2(LineSize,LineSize)/ViewportSize);
	

static float2 test[8] = 
		{
			{0,1},{0,-1},
			{1,0},{1,1},{1,-1},
			{-1,0},{-1,1},{-1,-1},
		};

VS_OUTPUT VS_passNeon( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
    VS_OUTPUT Out = (VS_OUTPUT)0;

    Out.Pos = Pos; 
    Out.Tex = Tex + float2(ViewportOffset.x, 0);

    return Out;
}


float4 PS_passNeon(float2 Tex: TEXCOORD0) : COLOR
{   

		
	float4 col = tex2D(DepthSamp,Tex);
	col.r *= FAR_DEPTH;
	
	
	//周囲８ピクセルとの深度の差異を保存する変数
	float sabun = 0;
	for(int i=0;i<8;i++)
	{
		float4 w = tex2D(DepthSamp,Tex + test[i]*SampStep/(col.r/10)* ProjMatrix._22/4 );	
		w.r *= FAR_DEPTH;	
		//Zの差分を加算
		sabun += (w.r - col.r);
	}
	if( sabun < Threshold )
	{
		sabun = 0;
	}else{
		//sabun = 1;
	}
	sabun *= 0.25;
	sabun = saturate(sabun);
	col = float4(sabun,sabun,sabun,1);
	col.rgb *= ToonCol * Tr * Si/10;
	col.a = 1;
	return col;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique NeonPost <
    string Script = 
	    "ScriptExternal=Color;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=NeonPost;"
    ;
> {

    pass NeonPost < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        SRCBLEND = ONE;
        DESTBLEND = ONE;
        VertexShader = compile vs_3_0 VS_passNeon();
        PixelShader  = compile ps_3_0 PS_passNeon();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////
