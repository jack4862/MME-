////////////////////////////////////////////////////////////////////////////////////////////////
//
//  名前:カメラ平滑化
//	作成;kion
//	種類:オブジェクト
//	説明:
//		アクセサリ位置を取得して、ビュー行列を計算(座標+クォータニオン)
//		平滑化追加
//
////////////////////////////////////////////////////////////////////////////////////////////////
// エフェクト宣言 //
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "object";
	string ScriptOrder = "standard";
> = 0.8;
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ //
// 閾値
float LimitPos = 0.01;
float LimitQuat = 0.02;
// 平滑化量(1<)
#define POS_SMOOTH	6
#define QUAT_SMOOTH	6
// 平滑化開始時間
#define WAIT_TIME	0.1

////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
// 指定用アクセサリ名
#define POS_AC	"Cam1Pos.x"
// 位置指定
bool Cam		: CONTROLOBJECT < string name = POS_AC; >;
float4x4 CamMat	: CONTROLOBJECT < string name = POS_AC; >;
float CamSize	: CONTROLOBJECT < string name = POS_AC; >;
// 位置指定のみの場合ここの値
static float FovD = CamSize/10.0;

// 移動用テクスチャ
// CameraMove.fxで出力
shared texture texMoveMat2 : RenderColorTarget;
sampler smpMoveMat2 = sampler_state{
	Texture = <texMoveMat2>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;
	AddressU = Clamp; AddressV = Clamp;
};

// ビュー行列計算
// D3DXMatrixLookAtLH関数そのまま
float4x4 calcLookAtLH(float3 Eye, float3 At, float3 Up) {
	float3 zaxis = normalize(At-Eye);
	float3 xaxis = normalize(cross(Up,zaxis));
	float3 yaxis = normalize(Up);
    return float4x4(
		xaxis.x,		yaxis.x,		zaxis.x,		0,
		xaxis.y,		yaxis.y,		zaxis.y,		0,
		xaxis.z,		yaxis.z,		zaxis.z,		0,
		-dot(xaxis,Eye),-dot(yaxis,Eye),-dot(zaxis,Eye),1	);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 視点情報を記録する(過去の分も含める)
// 位置座標を格納するテクスチャ(XYZ座標形式)
#define TEXPOS_WIDTH	1
#define TEXPOS_HEIGHT	POS_SMOOTH	// 記録する数
// テクスチャ
texture texPosDB : RenderDepthStencilTarget <
	int Width=TEXPOS_WIDTH; int Height=TEXPOS_HEIGHT; string Format = "D24S8"; >;
texture texPos1 : RenderColorTarget <
	int Width=TEXPOS_WIDTH; int Height=TEXPOS_HEIGHT; string Format="A32B32G32R32F"; >;
texture texPos2 : RenderColorTarget <
	int Width=TEXPOS_WIDTH; int Height=TEXPOS_HEIGHT; string Format="A32B32G32R32F"; >;
// サンプラー
sampler smpPos1 = sampler_state{
	Texture = <texPos1>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;
	AddressU = Clamp; AddressV = Clamp;
};
sampler smpPos2 = sampler_state{
	Texture = <texPos2>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;
	AddressU = Clamp; AddressV = Clamp;
};
// テクスチャオフセット
static float2 TexPosOffset = (float2)0.5/float2(TEXPOS_WIDTH,TEXPOS_HEIGHT);
static float TexPosOffsetY = 1.0/TEXPOS_HEIGHT;

// 姿勢を格納するテクスチャ(クォータニオン形式)
#define TEXQUAT_WIDTH	1
#define TEXQUAT_HEIGHT	QUAT_SMOOTH	// 記録する数
// テクスチャ
texture texQuatDB : RenderDepthStencilTarget <
	int Width=TEXQUAT_WIDTH; int Height=TEXQUAT_HEIGHT; string Format = "D24S8"; >;
texture texQuat1 : RenderColorTarget <
	int Width=TEXQUAT_WIDTH; int Height=TEXQUAT_HEIGHT; string Format="A32B32G32R32F"; >;
texture texQuat2 : RenderColorTarget <
	int Width=TEXQUAT_WIDTH; int Height=TEXQUAT_HEIGHT; string Format="A32B32G32R32F"; >;
// サンプラー
sampler smpQuat1 = sampler_state{
	Texture = <texQuat1>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;
	AddressU = Clamp; AddressV = Clamp;
};
sampler smpQuat2 = sampler_state{
	Texture = <texQuat2>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;
	AddressU = Clamp; AddressV = Clamp;
};
// テクスチャオフセット
static float2 TexQuatOffset = (float2)0.5/float2(TEXQUAT_WIDTH,TEXQUAT_HEIGHT);
static float TexQuatOffsetY = 1.0/TEXQUAT_HEIGHT;

// ビュー行列を最終的に格納
#define TEX_WIDTH	1
#define TEX_HEIGHT	2
texture texViewMatDB : RenderDepthStencilTarget <
	int Width=TEX_WIDTH; int Height=TEX_HEIGHT; string Format = "D24S8"; >;
shared texture texViewMat : RenderColorTarget <
	int Width=TEX_WIDTH; int Height=TEX_HEIGHT; string Format="A32B32G32R32F"; >;
sampler smpViewMat = sampler_state{
	Texture = <texViewMat>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;
    AddressU = Clamp; AddressV = Clamp;
};
// テクスチャオフセット
static float2 TexViewOffset = (float2)0.5/float2(TEX_WIDTH,TEX_HEIGHT);

////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
// 時間[s]
float time_0_X : Time;
// フレーム間時間
float ftime : ELAPSEDTIME;

////////////////////////////////////////////////////////////////////////////////////////////////
// 計算関数
// クォータニオン→行列
float4x4 Quaternion2Matrix(float4 q){
	return float4x4(
				1-2*q.y*q.y-2*q.z*q.z,	2*q.x*q.y-2*q.w*q.z,	2*q.x*q.z+2*q.w*q.y,	0,
				2*q.x*q.y+2*q.w*q.z,	1-2*q.x*q.x-2*q.z*q.z,	2*q.y*q.z-2*q.w*q.x,	0,
				2*q.x*q.z-2*q.w*q.y,	2*q.y*q.z+2*q.w*q.x,	1-2*q.x*q.x-2*q.y*q.y,	0,
				0,						0,						0,						1	);
}
// 行列→クォータニオン
float4 Matrix2Quaternion(float4x4 m){
// 転置などで変更する必要あり(2010.12.28)
	float w1 = m._11+m._22+m._33;
	float w2 = m._11-m._22-m._33;
	float w3 = m._22-m._11-m._33;
	float w4 = m._33-m._11-m._22;
	float max=w1;
	int i=0;
	if(w2>max){
		max=w2;
		i=1;
	}
	if(w3>max){
		max=w3;
		i=2;
	}
	if(w4>max){
		max=w4;
		i=3;
	}
	float4 q;
	float w;
	w = sqrt(max+1.0)*0.5;
	float _4w = 0.25 / w;
	if(i==0){
		q.w = w;
		q.x = m._32-m._23;
		q.y = m._13-m._31;
		q.z = m._21-m._12;
		q.xyz*=_4w;
	}
	if(i==1){
		q.x = w;
		q.w = m._32-m._23;
		q.y = m._21+m._12;
		q.z = m._13+m._31;
		q.wyz*=_4w;
	}
	if(i==2){
		q.y = w;
		q.w = m._13-m._31;
		q.x = m._21+m._12;
		q.z = m._32+m._23;
		q.wxz*=_4w;
	}
	if(i==3){
		q.z = w;
		q.w = m._21-m._12;
		q.x = m._13+m._31;
		q.y = m._32+m._23;
		q.wxy*=_4w;
	}
	//q.w*=-1;
	return q;
}

// Yaw(Y)
float4 QuaternionYaw(float rad){
	return float4(0, sin(rad*0.5), 0, cos(rad*0.5));
}
// Pitch(X)
float4 QuaternionPitch(float rad){
	return float4(sin(rad*0.5), 0, 0, cos(rad*0.5));
}
// Roll(Z)
float4 QuaternionRoll(float rad){
	return float4(0, 0, sin(rad*0.5), cos(rad*0.5));
}
// Multiply
float4 QuaternionMultiply(float4 q1, float4 q2){
	return float4(	q1.w*q2.x+q2.w*q1.x + q1.y*q2.z - q1.z*q2.y,
					q1.w*q2.y+q2.w*q1.y + q1.z*q2.x - q1.x*q2.z,
					q1.w*q2.z+q2.w*q1.z + q1.x*q2.y - q1.y*q2.x,
					q1.w*q2.w-q1.x*q2.x-q1.y*q2.y-q1.z*q2.z		);
}
// Inverse
float4 QuaternionInverse(float4 q){
	q.w*=-1;
	return q / length(q);
}
// Normalize
float4 QuaternionNormalize(float4 q){
	return q/length(q);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// カメラ行列計算
// 頂点出力
struct VS_OUTPUT {
	float4 Pos	: POSITION;
	float2 Tex	: TEXCOORD0;
};
// 平滑化処理
// 頂点シェーダ
VS_OUTPUT InitPosVS( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = Pos;
	Out.Tex = Tex + TexPosOffset;
	return Out;
}
VS_OUTPUT InitQuatVS( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = Pos;
	Out.Tex = Tex + TexQuatOffset;
	return Out;
}
// 初期化とデータずらしてtexPos1に出力
float4 InitPosPS( VS_OUTPUT In ) : COLOR
{
	float4 Color=(float4)0;
	if(time_0_X <= WAIT_TIME){	// 初期化
		Color.xyz = CamMat._41_42_43;
	}
	else{	// データをずらす
		Color=tex2D(smpPos2, In.Tex + float2(0,TexPosOffsetY));
	}
	return Color;
}
float4 InitQuatPS( VS_OUTPUT In ) : COLOR
{
	float4 Color=(float4)0;
	if(time_0_X <= WAIT_TIME){	// 初期化
		Color = Matrix2Quaternion(calcLookAtLH(CamMat._41_42_43, CamMat._41_42_43+CamMat._31_32_33, CamMat._21_22_23));
	}
	else{	// データをずらす
		Color=tex2D(smpQuat2, In.Tex + float2(0,TexQuatOffsetY));
	}
	return Color;
}
// View行列を計算してtexPos2に出力
float4 CameraPosPS( VS_OUTPUT In ) : COLOR
{
	float4 Color=(float4)0;
	if(In.Tex.y<(1.0-TexPosOffsetY)){ // そのまま
		Color = tex2D(smpPos1, In.Tex);
	}
	else{	// View行列を格納
		Color.xyz = CamMat._41_42_43;
		// 閾値判定
		float3 LColor = tex2D(smpPos1, In.Tex + float2(0.0, 1.0-TexQuatOffsetY)).xyz;
		if(distance(Color,LColor)<LimitPos) Color.xyz = LColor;
	}
	return Color;
}
float4 CameraQuatPS( VS_OUTPUT In ) : COLOR
{
	float4 Color=(float4)0;
	if(In.Tex.y<(1.0-TexQuatOffsetY)){ // そのまま
		Color = tex2D(smpQuat1, In.Tex);
	}
	else{	// View行列を格納
		Color = Matrix2Quaternion(calcLookAtLH(CamMat._41_42_43, CamMat._41_42_43+CamMat._31_32_33, CamMat._21_22_23));
		// 閾値判定
		float4 LColor = tex2D(smpQuat1, In.Tex + float2(0.0, 1.0-TexQuatOffsetY));
		if(distance(Color,LColor)<LimitQuat) Color = LColor;
	}
	return Color;
}

// カメラ行列を計算
// 頂点シェーダ
VS_OUTPUT ViewVS( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = Pos;
	Out.Tex = Tex;
	return Out;
}
// texViewMatに出力
float4 ViewPS( VS_OUTPUT In ) : COLOR
{
	float4 Color = (float4)0;
	if(In.Tex.y<1.0/TEX_HEIGHT){	// 位置座標
		// 平均を計算して出力
		for(int i=0;i<TEXPOS_HEIGHT;i++)
			Color += tex2D(smpPos2, TexPosOffset + float2(0, TexPosOffsetY*i));
		Color /= TEXPOS_HEIGHT;
		Color += tex2D(smpMoveMat2, float2(0.5, 0.25));
	}
	else{	// 姿勢
		// 平均を計算して出力
		for(int i=0;i<TEXQUAT_HEIGHT;i++)
			Color += tex2D(smpQuat2, TexQuatOffset + float2(0, TexQuatOffsetY*i));
		Color /= TEXQUAT_HEIGHT;
		// 移動状態を追加(カメラ用に逆行列)
		Color = QuaternionMultiply(Color, QuaternionInverse(tex2D(smpMoveMat2, float2(0.5, 0.75))));
	}
	return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック
technique Main <
	string Script =
		// 座標
		"RenderColorTarget0=texPos1; RenderDepthStencilTarget=texPosDB;"
			"Pass=InitPosPass;"
		"RenderColorTarget0=texPos2;"
			"Pass=CameraPosPass;"
		// 姿勢
		"RenderColorTarget0=texQuat1; RenderDepthStencilTarget=texQuatDB;"
			"Pass=InitQuatPass;"
		"RenderColorTarget0=texQuat2;"
			"Pass=CameraQuatPass;"
		// 平均してまとめる
		"RenderColorTarget0=texViewMat; RenderDepthStencilTarget=texViewMatDB;"
			"Pass=ViewPass;"
	;
> {
	pass InitPosPass < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		AlphaBlendEnable = FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
		VertexShader = compile vs_3_0 InitPosVS();
		PixelShader = compile ps_3_0 InitPosPS();
	}
	pass CameraPosPass < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		AlphaBlendEnable = FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
		VertexShader = compile vs_3_0 InitPosVS();
		PixelShader = compile ps_3_0 CameraPosPS();
	}
	pass InitQuatPass < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		AlphaBlendEnable = FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
		VertexShader = compile vs_3_0 InitQuatVS();
		PixelShader = compile ps_3_0 InitQuatPS();
	}
	pass CameraQuatPass < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		AlphaBlendEnable = FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
		VertexShader = compile vs_3_0 InitQuatVS();
		PixelShader = compile ps_3_0 CameraQuatPS();
	}
	pass ViewPass < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		AlphaBlendEnable = FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
		VertexShader = compile vs_3_0 ViewVS();
		PixelShader = compile ps_3_0 ViewPS();
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////