//水面下オブジェクト用シェーダ
//MRT0：法線
shared texture UnderNormal: RENDERCOLORTARGET;
//MRT1：座標
shared texture UnderPos: RENDERCOLORTARGET;
//深度ステンシル
shared texture UnderDepthBuffer : RENDERDEPTHSTENCILTARGET;



//テクスチャ名
#define TEXNAME "../Texture/NormalBase.png"

//テクスチャ分割数
#define TEXSPLIT 1

// ソートを有効にするなら1
// 必要なかったり比較してみたいときは0
#define SORT_ENABLE 1

// パーティクルの最大表示数、最大で65536
// 4096,16384を超えるとソート処理の関係で段階的に重くなるので注意
#define PARTICLE_COUNT 65536

//生成制限速度
float MinSpd = 0.0f;
//最大回転速度
float RotationSpdMax = 10;

// 色(テクスチャの色に乗算)
float4 ParticleColor = float4(1,1,1,1);



// 加算色(RGB)
//左：生成時
//右：寿命時
float3 AddColorByLife[2] = { float3(0,0,0),float3(0,0,0)};
//色変化速度
float AddColorPower = 20;
//法線＆視点による加算の抑制
float AddColorEyeAddjust = 1;

//パーティクル出易さ
float CoefProbable = 0.002;

//発射速度最大値
float ShotSpd = 0.025;
//発射速度ランダム減算値
float RndSpd = 0.025;

//発射時ランダム角度(1.0で360度発射)
float ShotRand = 1;
//ランダム発射角度ゆらぎ量
float RndShotYuragi = 0.5;
//ランダム発射角度ゆらぎ速度
float RndShotYuragiSpd = 10;

//生成箇所ランダム量XYZ
float3 PosRand = float3(0,0,0);

//寿命最大値
float Life = 10;

//寿命ランダム減算値
float RndLife = 0.1;

//重力
float3 Grv = float3(0,-0.025,0);

//反射時の減衰
float3 CollisionDrag = float3(1,1,1)*0.1;
//反射時の寿命減衰（0で無効 1.0で即消滅)
float CollisionLifeDown = 0;

//球接触時のランダム角度変更量
float CollisionRandSp = 0.25;

//板接触時のランダム角度偏向量
float CollisionRandPl = 0.25;

//スクリーン接触時のランダム角度偏向量
float CollisionRandSS = 0.1;

//よりそい度
float Attract = 1;

//張り付き時、速度減少力
float StickDownSpd = 0.9;
//張り付き時、重力方向へのしたたり度（0で動かない）
float StickFallSpd = 0;
//張り付き時、したたり力減少力
float StickFallLife = 2;

//空気抵抗
float AirDrag = 0.92;

//ランダムゆらぎ量
float RndYuragi = 0;

//太さ基準値
float Scale = 1;
//大きさランダム減算値
float RandScale = 0.5;

float ScaleByLife[3] = {0,1,0.8};

//大きさ変化速度
float ScalePower = 16;

//点滅量(0で点滅しない。1が最大）
float Flick = 0;
//点滅速度
float FlickSpd = 1.0;

// 当たり判定
#define SSBOUNCE	1		// 当たり判定を有効にする
float BounceFactor = 0;		// 衝突時の跳ね返り率。0～1
float FrictionFactor = 1.0;		// 衝突時の減速率。1で減速しない。
float IgnoreDpethOffset = 10;		// 表面よりこれ以上後のパーティクルは衝突を無視する


// (風等の)空間の流速場を定義する関数
// 粒子位置ParticlePosにおける空気の流れを記述します。
// 戻り値が0以外の時はオブジェクトが動かなくても粒子を放出します。
// 速度抵抗係数がResistFactor>0でないと粒子の動きに影響を与えません。
float3 VelocityField(float3 ParticlePos)
{
   float3 vel = float3( 0.0, 0.0, 0.0 );
   return vel;
}

float NowScaleByLife(float t)
{
	float ret = 0;
	if(t > 0.5)
	{
		ret = lerp(ScaleByLife[1],ScaleByLife[0],(t-0.5)*2);
	}else{
		ret = lerp(ScaleByLife[2],ScaleByLife[1],t*2);
	}
	return ret;
}

//================================================================================================//
#include "../function/rotate.fxsub"
// パラメータ宣言

#if(PARTICLE_COUNT>65536)
	#error パーティクルの上限をオーバーしています！
#elif(PARTICLE_COUNT>16384)
	#define TEX_SIZE 256
#elif(PARTICLE_COUNT>4096)
	#define TEX_SIZE 128
#else
	#define TEX_SIZE 64
#endif

int count = PARTICLE_COUNT;


float3 LightAmbient : AMBIENT < string Object = "Light"; >;
float3 CameraPosition	: POSITION  < string Object = "Camera"; >;
float3 LightDirection	: DIRECTION < string Object = "Light"; >;


//------------------------------------------------------------------------------------------------//
// カメラのパラメータ

// 座法変換行列
float4x4 ViewMatrix		: VIEW;
float4x4 WorldViewMatrix		: WORLDVIEW;
float4x4 WVP		: WORLDVIEWPROJECTION;
float4x4 ViewProjMatrix				: VIEWPROJECTION;
float4x4 ProjMatrix				: PROJECTION;
float4x4 WorldMatrix : WORLD;
float4x4 LightViewProjMatrix : VIEWPROJECTION < string Object = "Light"; >;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

//------------------------------------------------------------------------------------------------//
// テクスチャとサンプラ

texture BaseTex< string ResourceName = TEXNAME; >;
sampler BaseSamp = sampler_state {
	texture = <BaseTex>;
	MINFILTER = ANISOTROPIC;
	MAGFILTER = ANISOTROPIC;
	MIPFILTER = LINEAR;
	MAXANISOTROPY = 16;
	AddressU = WRAP;
	AddressV = WRAP;
};

//乱数テクスチャ
texture2D rndtex < string ResourceName = "../function/random512x512.bmp"; >;
sampler rnd = sampler_state {
	texture = <rndtex>;
	FILTER = NONE;
};
sampler rnd_linear = sampler_state {
	texture = <rndtex>;
	FILTER = LINEAR;
};

//乱数テクスチャサイズ
#define RNDTEX_WIDTH  512
#define RNDTEX_HEIGHT 512

float Random(float p)
{
    return frac(sin(dot(normalize(float2(p,p*13.456)), float2(12.9898,78.233))) * 43758.5453);
}

//乱数取得
float4 getRandom(float rindex)
{
	float2 tpos = float2(rindex % RNDTEX_WIDTH, trunc(rindex / RNDTEX_WIDTH));
	tpos += float2(0.5,0.5);
	tpos /= float2(RNDTEX_WIDTH, RNDTEX_HEIGHT);
	return tex2Dlod(rnd, float4(tpos,0,1));
}
float4 getRandom_calc(float rindex)
{
	return float4(Random(rindex*123.456),Random(rindex*234.567),Random(rindex*345.678),Random(rindex*456.789));
}
float4 getRandomLinear(float rindex)
{
	float2 tpos = float2(rindex % RNDTEX_WIDTH, trunc(rindex / RNDTEX_WIDTH));
	tpos += float2(0.5,0.5);
	tpos /= float2(RNDTEX_WIDTH, RNDTEX_HEIGHT);
	return tex2Dlod(rnd_linear, float4(tpos,0,1));
}
//ソフトパーティクルエンジン用深度テクスチャ
shared texture2D SPE_DepthTex : RENDERCOLORTARGET;
sampler2D SPE_DepthSamp = sampler_state {
	texture = <SPE_DepthTex>;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = NONE;
	AddressU  = CLAMP;
	AddressV = CLAMP;
};
// パーティクル座標を保存するテクスチャ
shared texture2D ParticlePosTex_SB1 : RENDERCOLORTARGET;
sampler2D ParticlePosSamp = sampler_state {
	texture = <ParticlePosTex_SB1>;
	Filter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};
// パーティクル速度と寿命を保存するテクスチャ
shared texture2D ParticleVecTex_SB1 : RENDERCOLORTARGET;
sampler2D ParticleVecSamp = sampler_state {
	texture = <ParticleVecTex_SB1>;
	Filter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};
// 接触率と目標角度
shared texture2D ParticleNormTex_SB1 : RENDERCOLORTARGET;
sampler2D ParticleNormSamp = sampler_state {
	texture = <ParticleNormTex_SB1>;
	Filter = NONE;
	AddressU = CLAMP; AddressV = CLAMP;
};

bool     parthf;   // パースペクティブフラグ
#define SKII1    1500
#define SKII2    8000
#define Toon     3

// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);

//------------------------------------------------------------------------------------------------//
// ソフトパーティクルエンジンのパラメータ

//ソフトパーティクルエンジン使用フラグ
bool use_spe : CONTROLOBJECT < string name = "SoftParticleEngine.x"; >;


//------------------------------------------------------------------------------------------------//
// バイトニックソートに関するパラメータ


//------------------------------------------------------------------------------------------------//
// その他のパラメータ・関数

float time : TIME; //経過時間
float elapsed_time : ELAPSEDTIME;
static float Dt = (elapsed_time < 0.2f) ? clamp(elapsed_time, 0.001f, 1.0f/15.0f) : 1.0f/30.0f;

float Tr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float Si : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;

float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "sceneorobject";
	string ScriptOrder = "standard";
> = 0.8;

float RndScale(int id)
{
	float4 rnd = getRandom_calc(id);
	
	return rnd.r;
}

// パーティクルの座標と透明度を決定
float4 EffectPosColor(int id)
{
	float3 Pos;

	float index = id;

	// ランダム配置
	float4 base_pos = getRandom(index) - 0.5;

	// 透明度を計算
	float alpha = 1;
	
	return float4(base_pos.xyz,alpha);
}

// テクスチャ座標からインデックスを求める
int TexToIndex(float2 tex, int size, float offset){
	int index = (int)round(tex.x*size-offset)+(int)round(tex.y*size-offset)*size;
	return index;
}

// インデックスからテクスチャ座標を求める
float2 IndexToTex(int index, int size, float offset){
	float2 tex;
	tex.x = (index%size+offset)/size;
	tex.y = (index/size+offset)/size;
	return tex;
}



//------------------------------------------------------------------------------------------------//
// パーティクル本体の描画

/* 頂点シェーダー用構造体 */
struct PTCL_VS_OUTPUT
{
	float4 Pos		: POSITION;		// 射影変換座標
	float2 Tex		: TEXCOORD0;	// テクスチャ
	float indexF	: TEXCOORD1;	// パーティクルのインデックス
	float Alpha		: TEXCOORD2;	// パーティクルの透明度
	float4 VPos		: TEXCOORD3;	// ビュー座標
	float3 Normal	: TEXCOORD4;
	float4 ScrPos	: TEXCOORD5;	// スクリーン座標
	float3 WPos		: TEXCOORD6;
	float4 pPos		: TEXCOORD7;
	float4 pVec	 	: TEXCOORD8;
	float4 ZCalcTex : TEXCOORD9;
};

float4x4 ViewMatrixInverse        : VIEWINVERSE;
static float3x3 BillboardMatrix = {
    normalize(ViewMatrixInverse[0].xyz),
    normalize(ViewMatrixInverse[1].xyz),
    normalize(ViewMatrixInverse[2].xyz),
};
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;

/* 頂点シェーダー */
PTCL_VS_OUTPUT PtclMain_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
	// 初期化
	PTCL_VS_OUTPUT Out = (PTCL_VS_OUTPUT)0;
	
	// Z値をもとにしたインデックス
	int indexZ = int(round(Pos.z));
	
	// ソート後のインデックスを取得
	int index = indexZ;//(int)round(tex2Dlod(SortSamp, float4(IndexToTex(indexZ,TEX_SIZE,0.5),0,1)).g);
	
	// パーティクルのビュー座標と透明度を取得して移動
	float2 PtclTex = IndexToTex(index,TEX_SIZE,0.5);
	float4 PtclData = tex2Dlod(ParticlePosSamp,float4(PtclTex,0,1));
	float4 VecData = tex2Dlod(ParticleVecSamp,float4(PtclTex,0,1));
	float4 NormData = tex2Dlod(ParticleNormSamp,float4(PtclTex,0,1));
	
	Out.Pos = float4(Pos.xy,0,1);
	
	Out.Normal = float3(Pos.xy,-1);
	Out.Normal = normalize(Out.Normal);
	
	float3 PtclPos = PtclData.rgb;
	float fLife = saturate(VecData.a / Life);
	float PtclAlpha = 1 * (1-pow(1-fLife,4));
	
	
	float3 Prev = PtclPos - VecData.xyz*2;
	float3 Now = PtclPos;
	
	//カメラベクトル
	float3 Eye = CameraPosition - lerp(Prev,Now,0.5);
	
	Scale -= RandScale * getRandom_calc(index*1.234).x;
	float FixScale = Scale * NowScaleByLife(pow(saturate(VecData.a/Life),ScalePower));
	
	float4 rndR = getRandom_calc(index*123.456);
		
	//ビルボード処理
	Out.Pos.xy *= FixScale;
		
	float3 posbase = Out.Pos.xyz;
	float3 normbase = Out.Normal.xyz;
	float Sc = (RndScale(index));
	if(Sc > 0.995) Sc *= 1.5;
	/*
	//Out.Pos.xy *= Sc*Si;
	// パーティクルに回転を与える
	float rot_z = rndR.x*2*3.1415;
	float3x3 RotationZ = {
		{cos(rot_z), sin(rot_z), 0},
		{-sin(rot_z), cos(rot_z), 0},
		{0, 0, 1},
	};
	float3x3 RevRotationZ = {
		{cos(-rot_z), sin(-rot_z), 0},
		{-sin(-rot_z), cos(-rot_z), 0},
		{0, 0, 1},
	};
	
	Out.Pos.xyz = mul( Out.Pos.xyz, RotationZ );
	Out.Normal.xyz = mul( Out.Normal, RotationZ);
	*/
	/*
	Out.Pos.xyz = RotY_vec(Out.Pos.xyz,rndR.y*2*3.1415 + time*rndR.z*RotationSpdMax);
	Out.Normal.xyz = RotY_vec(Out.Normal.xyz,rndR.y*2*3.1415);
	
	Out.Pos.xyz = RotX_vec(Out.Pos.xyz,rndR.z*2*3.1415 + time*rndR.x*RotationSpdMax);
	Out.Normal.xyz = RotX_vec(Out.Normal.xyz,rndR.z*2*3.1415);
	*/
	
	Out.Pos.xyz = mul( Out.Pos, BillboardMatrix);
	Out.Normal.xyz = mul( Out.Normal, BillboardMatrix);
		
	float3x3 ColTargetMatrix = {
	    normalize(float3(1,0,0)),
	    normalize(getRandom_calc(index*123.456).xyz),
	    normalize(-NormData.xyz),
	};
	ColTargetMatrix[0] = cross(ColTargetMatrix[1],ColTargetMatrix[2]);
	ColTargetMatrix[1] = cross(ColTargetMatrix[0],ColTargetMatrix[2]);
	
	
	Out.Pos.xyz = lerp(Out.Pos.xyz,mul( posbase, ColTargetMatrix),NormData.a);
	Out.Normal.xyz = lerp(Out.Normal.xyz,mul( normbase, ColTargetMatrix),NormData.a);
	
	Out.Pos.xyz += NormData.xyz*NormData.a*0.05;
	Out.Pos.xyz += Now;

	
	Out.WPos = Out.Pos.xyz;
	
	
	// ビュー座標をコピー
	Out.VPos = mul(Out.Pos,ViewMatrix);
	// 射影変換を行う(座標はワールドビュー変換済みであるため)
	Out.ZCalcTex = mul( Out.Pos, LightViewProjMatrix );
	Out.Pos = mul( Out.Pos, ViewProjMatrix );
	// スクリーン座標をコピー
	Out.ScrPos = Out.Pos;
	
	// テクスチャ座標
	Out.Tex = Tex;
	
	Out.indexF = (float)index;
	Out.Alpha = PtclAlpha;
	Out.pPos = PtclData;
	Out.pVec = VecData;
	
	// 最大表示数を超えた分は非表示にする
	Out.Pos.z += (indexZ > count) ? 2 : 0;
	//Out.Pos.z += (NormData.a < 0.5) ? 2 : 0;
	//Out.Pos = mul(Pos,WorldViewProjMatrix);
	return Out;
}
float3x3 compute_tangent_frame(float3 Normal, float3 View, float2 UV)
{
  float3 dp1 = ddx(View);
  float3 dp2 = ddy(View);
  float2 duv1 = ddx(UV);
  float2 duv2 = ddy(UV);

  float3x3 M = float3x3(dp1, dp2, cross(dp1, dp2));
  float2x3 inverseM = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
  float3 Tangent = mul(float2(duv1.x, duv2.x), inverseM);
  float3 Binormal = mul(float2(duv1.y, duv2.y), inverseM);

  return float3x3(normalize(Tangent), normalize(Binormal), Normal);
}
struct PS_OUTPUT {
	float4 Normal : COLOR0;
	float4 Pos : COLOR1;
};

/* ピクセルシェーダー */
float4 PtclMain_PS( PTCL_VS_OUTPUT IN) : COLOR0
{
	float3 BaseColor = float3(0.25,0.25,0.25);
	float3 AddColor1 = float3(1,0.5,0)*2;
	float3 AddColor2 = float3(0.8,0,1)*2;
	
	int index = (int)round(IN.indexF);
	
	float2 tex = IN.Tex*(1.0/TEXSPLIT);
	
	tex.x += (index%TEXSPLIT)*(1.0/TEXSPLIT);
	tex.y += ((index/TEXSPLIT)%TEXSPLIT)*(1.0/TEXSPLIT);
	
	float4 Color = tex2D( BaseSamp, tex );
	float3 Eye = CameraPosition - IN.WPos;
	
	float3x3 tangentFrame = compute_tangent_frame(IN.Normal, -normalize(Eye), IN.Tex);
	float4 NormalColor = Color*2;	
	NormalColor = NormalColor.rgba;
	NormalColor.a = 1;
	
	float3 normal = normalize(mul(NormalColor - 1.0f, tangentFrame));
	
	
	float2 ScTex = IN.ScrPos.xyz/IN.ScrPos.w;
	ScTex = ScTex*float2(0.5,-0.5)+float2(0.5,0.5);
	Color.rgb = 1;
	Color.a *= saturate(IN.Alpha);
	float4 LastColor;
	
	LastColor.rgb = Color.rgb;
	LastColor.a = Color.a * ParticleColor.a;
	
	//----光源計算
	LastColor.rgb *= LightAmbient+0.7;
	
	float nd = saturate(dot(normal,-LightDirection)*0.25+0.75);
	
	//TOON//
	//nd = saturate(dot(normal,-LightDirection));
	//nd = smoothstep(0.4,0.41,nd);
	//nd = saturate(nd+0.5);
	
	LastColor.rgb *= nd;
	LastColor.rgb *= ParticleColor;
	
	//LastColor.a = smoothstep(0,0.1,LastColor.a);
	
	float fLife = (IN.pVec.a/Life);
	
	float ed = saturate(dot(normal,normalize(Eye)));
	
	LastColor.rgb += lerp(AddColorByLife[1],AddColorByLife[0],pow(fLife,AddColorPower))*saturate(lerp(1,ed,AddColorEyeAddjust));
	LastColor.r = 1;
	float3 HalfVector = normalize( normalize(Eye) + -LightDirection );
    float3 Specular = pow( max(0,dot( HalfVector, normalize(normal) )), 4 );
	LastColor.g = Specular;
	LastColor.b = nd;
	LastColor.rgb *= saturate(LastColor.a);	
	
	
	if(use_spe)
	{
		// カメラからの距離!!
		float dep = length(IN.VPos);
		float scrdep = tex2D(SPE_DepthSamp,ScTex).r;
		
		dep = length(dep-scrdep);
		dep = smoothstep(0,Si*0.1,dep);
		LastColor.a *= dep;
	}
	
	if(IN.indexF == 0) Color = 0;
	
	return LastColor;
}

//------------------------------------------------------------------------------------------------//
// テクニックとパス

float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;

technique MainTec < string MMDPass = "object";
	string Script = 
		// パーティクルの表示
		"RenderColorTarget0=;"
		"RenderColorTarget1=;"
		"RenderDepthStencilTarget0=;"
		"Pass=DrawParticle;"
		;
 > {
	pass DrawParticle{
		CULLMODE = NONE;
		AlphaBlendEnable	= true;
		AlphaTestEnable		= true;
		ZEnable				= true;
		ZWriteEnable		= true;
		VertexShader = compile vs_3_0 PtclMain_VS();
		PixelShader  = compile ps_3_0 PtclMain_PS();
	}
}

technique ZplotTec < string MMDPass = "zplot"; > {}
technique EdgeTec < string MMDPass = "edge"; > {}
technique ShadowTec < string MMDPass = "shadow"; > {}


//================================================================================================//
