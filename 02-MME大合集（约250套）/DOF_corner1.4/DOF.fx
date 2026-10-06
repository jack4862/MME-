////////////////////////////////////////////////////////////////////////////////////////////////
//
//	名前:被写界深度
//	種類:ポストエフェクト
//	対応:MMEver0.2x
//	作成:kion
//	説明:
//		被写界深度
//
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ操作用オブジェクト
float4x4 Matrix : CONTROLOBJECT < string name = "(self)"; >;				// 行列
float3 Rxyz : CONTROLOBJECT < string name = "(self)"; string item="Rxyz";>;	// 角度
float Scale : CONTROLOBJECT < string name = "(self)"; string item = "Si";>;	// スケール
float Tr : CONTROLOBJECT < string name = "(self)"; string item = "Tr";>;	// 透過度
float3 CameraPosition: POSITION < string Object = "Camera"; >;// カメラ座標
static float3 FocusPos = Matrix._41_42_43;
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメーター //
// ピント位置の調整(0で固定、1でDOF.xの位置、2で自動調整(デフォルト))
#define AUTO_SETTING		2

// ぼけ具合(サンプリング半径)
// 大きすぎると破たんします。→サンプリング数を大きくするべし
static float BlurR = Rxyz.x*57.0;	// Rxの値を使用
// サンプリング数(1～26)
// 大きくすると、ぼけ方が綺麗になるがGPU負荷増大
#define SAMP_NUM	12

// その他
// 被写界深度の手前側と奥側の距離の比(奥/手前)
// ぼけ具合にも影響。大きくすると手前側が大きくボケる
float DOF_DepthRatio = 2.0;
// ぼけの線形変化範囲(DOF_Depthに対しての割合)
// 境界がはっきりし過ぎるときはこれを大きくする
float DOF_LerpRatio = 0.5;


// ぼかす回数(1～3)
// 増やすと綺麗になるが負荷増大
#define PASS	1


////////////////////////////////////////////////////////////////////////////////////////////////
//	これより下はわかる人だけ
////////////////////////////////////////////////////////////////////////////////////////////////

// アクセサリ位置で自動的に範囲を指定
#if AUTO_SETTING==2
// 焦点距離(ピント位置)
static float FocusDistace = distance(FocusPos, CameraPosition);
// 被写界深度の距離(ピント位置からこの範囲はぼけない)
static float DOF_Depth = FocusDistace*Tr;
#endif
// アクセサリ位置で指定する場合
#if AUTO_SETTING==1
// 焦点距離(ピント位置)
static float FocusDistace = distance(FocusPos, CameraPosition);
// 被写界深度の距離(ピント位置からこの範囲はぼけない)
static float DOF_Depth = Scale*0.1;
#endif
// 固定する場合
#if AUTO_SETTING==0
// 焦点距離(ピント位置)
static float FocusDistace = Scale*0.1;//distance(FocusPos, CameraPosition);
// 被写界深度の距離(ピント位置からこの範囲はぼけない)
static float DOF_Depth = FocusDistace*Tr;
#endif

////////////////////////////////////////////////////////////////////////////////////////////////
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "scene";
    string ScriptOrder = "postprocess";
> = 0.8;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

// 変数計算
#define PI2	6.28318530718	// 2π
// サンプリング係数計算
float2 SampCoord[SAMP_NUM];
int CalcSampCoord(float r){
	int num = SAMP_NUM;
	for(int i=0;i<num;i++){
		SampCoord[i].x = r * sin(i/(float)num*PI2)/ViewportSize.x;
		SampCoord[i].y = r * cos(i/(float)num*PI2)/ViewportSize.y;
	}
	return 1;
}
static int CalcSampFlag = CalcSampCoord(BlurR);
// その他係数
static float Fnear=DOF_Depth, Ffar=Fnear*DOF_DepthRatio;
static float Near = FocusDistace-Fnear, Far = FocusDistace+Ffar;
static float NL=Fnear*DOF_LerpRatio, FL=Ffar*DOF_LerpRatio;

////////////////////////////////////////////////////////////////////////////////////////////////
// レンダリングターゲットのクリア値
float4 ClearColorBlack = {0,0,0,1}, ClearColorWhite = {1,1,1,1};
float ClearDepth  = 1.0;

// レンダーターゲット
// オリジナル
texture2D texOut : RENDERCOLORTARGET <
	float2 ViewportRatio = {1.0, 1.0};	int MipLevels = 1;
	string Format = "A8R8G8B8";
>;
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
	float2 ViewportRatio = {1.0, 1.0};	string Format = "D24S8";
>;
// サンプラー
sampler2D smpOut = sampler_state {
	texture = <texOut>;
	MinFilter = LINEAR; MagFilter=LINEAR; MipFilter = LINEAR;
	AddressU = CLAMP; AddressV = CLAMP;
};
// 深度
texture texWDepth: OFFSCREENRENDERTARGET <
    string Description = "W Depth For DOF.fx";
	float2 ViewportRatio = {1.0, 1.0};
    float4 ClearColor = { 0.0, 0, 0, 1 };
    float ClearDepth = 1.0;
    string Format = "R32F" ;
    bool AntiAlias = false;
    string DefaultEffect = 
        "self = hide;"
        "* = CamDepth.fx";
>;
// サンプラー
sampler2D smpWDepth = sampler_state {
    texture = <texWDepth>;
    MinFilter = POINT; MagFilter = POINT; MipFilter = NONE;
    AddressU  = CLAMP; AddressV = CLAMP;
};

#if PASS>=2
// ぼかし用
texture2D texTmp : RENDERCOLORTARGET <
	float2 ViewportRatio = {1.0, 1.0};	int MipLevels = 1;
	string Format = "A8R8G8B8";
>;
// サンプラー
sampler2D smpTmp = sampler_state {
	texture = <texTmp>;
	MinFilter = LINEAR; MagFilter=LINEAR; MipFilter = LINEAR;
	AddressU = CLAMP; AddressV = CLAMP;
};
#endif

////////////////////////////////////////////////////////////////////////////////////////////////
// 被写界深度
// 頂点出力
struct VS_OUTPUT {
    float4 Pos			: POSITION;
	float2 Tex			: TEXCOORD0;
};
VS_OUTPUT VS_DOF( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
    VS_OUTPUT Out = (VS_OUTPUT)0; 
    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;
    return Out;
}
float4  PS_DOF( VS_OUTPUT In , uniform sampler2D smp) : COLOR{   
	float4 Color = tex2D(smp,In.Tex);	// 色
	float d = tex2D(smpWDepth,In.Tex).r;// 深度
	float4 LColor=(float4)0;

	// 被写界深度範囲内
	if(Near<d && d<Far) return Color;
	// 範囲外
	else{
		// ぼかす
		for(int i=0;i<SAMP_NUM;i++){
			float sr;
			// サンプリング点の深度
			float sd = tex2D(smpWDepth,In.Tex+SampCoord[i]).r;
			if(sd<Far)	// 手前
				sr=saturate((Near-sd)/NL)*DOF_DepthRatio;
			else		// 奥
				sr=saturate((sd-Far)/FL);
			// サンプリングする色
			float4 AColor=tex2D(smp,In.Tex+sr*SampCoord[i]);
			// 輪郭周辺のボケを回避(効果は薄い)
			//sd = tex2D(smpWDepth,In.Tex+sr*SampCoord[i]).r;
			// サンプリング点の深度が被写界深度外の場合
			//if(sd<Near || Far<sd) AColor=tex2D(smp,In.Tex+sr*SampCoord[i]);
			//else AColor=tex2D(smp,In.Tex);
			Color+=AColor;
		}
		Color/=(SAMP_NUM+1);
		Color.a=1;
		return saturate(Color);
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique DOF<
    string Script = 
		// オリジナル画像出力
		"RenderColorTarget0=texOut; RenderDepthStencilTarget=DepthBuffer;"
		"ClearSetColor=ClearColorWhite; ClearSetDepth=ClearDepth; Clear=Color; Clear=Depth;"
			"ScriptExternal=Color;"
#if PASS==1
		"RenderColorTarget0=; RenderDepthStencilTarget=;"
			"Pass=DOF1;"
#endif
#if PASS==2
		// 被写界深度
		"RenderColorTarget0=texTmp;"
			"Pass=DOF1;"
		// 画面に出力
		"RenderColorTarget0=; RenderDepthStencilTarget=;"
			"Pass=DOF2;"
#endif
#if PASS==3
		// 被写界深度
		"RenderColorTarget0=texTmp;"
			"Pass=DOF1;"
		"RenderColorTarget0=texOut;"
			"Pass=DOF2;"
		// 画面に出力
		"RenderColorTarget0=; RenderDepthStencilTarget=;"
			"Pass=DOF1;"
#endif
    ;
> {
	pass DOF1 < string Script= "Draw=Buffer;"; >
	{
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS_DOF();
		PixelShader  = compile ps_3_0 PS_DOF(smpOut);
	}
#if PASS>=2
	pass DOF2 < string Script= "Draw=Buffer;"; >
	{
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 VS_DOF();
		PixelShader  = compile ps_3_0 PS_DOF(smpTmp);
	}
#endif
}