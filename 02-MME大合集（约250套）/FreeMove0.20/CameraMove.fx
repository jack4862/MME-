////////////////////////////////////////////////////////////////////////////////////////////////
//
//  名前:Kinectで移動
//	作成;kion
//	種類:オブジェクト
//	説明:
//		Kinectでアクセサリ位置を取得して、移動行列を計算(座標+クォータニオン)
//
////////////////////////////////////////////////////////////////////////////////////////////////
// エフェクト宣言 //
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "object";
	string ScriptOrder = "standard";
> = 0.8;
////////////////////////////////////////////////////////////////////////////////////////////////
// 距離(位置、範囲)
float2 ForwardDistance	= {-6.0, 4.0};	// Z
float2 BackDistance		= {6.0, 4.0};	// Z
float2 LeftDistance		= {9.0, 5.0};	// X
float2 RightDistance	= {-9.0, 5.0};	// X
float2 DownDistance		= {4.0, 3.0};	// Y
float2 UpDistance		= {20.0, 3.0};	// Y

// 位置指定
float4x4 CenterControl	: CONTROLOBJECT < string name = "CenterControl.x"; >;
float4x4 LeftControl	: CONTROLOBJECT < string name = "LeftControl.x"; >;
float4x4 RightControl	: CONTROLOBJECT < string name = "RightControl.x"; >;

// 移動量
float3 Velocity = float3( 60, 60, 90 );
float3 RotateYPR = float3( radians(120.0), radians(60.0), radians(60.0) );

// 判定の倍率
float Size = 1.0;

////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
// 指定用アクセサリ名
#define POS_AC	"Cam1Pos.x"
// カメラの位置
float3 CamPos : CONTROLOBJECT < string name = POS_AC; string item = "XYZ"; >;
float3 CamRot : CONTROLOBJECT < string name = POS_AC; string item = "Rxyz"; >;


////////////////////////////////////////////////////////////////////////////////////////////////
// 移動処理
// 判定の倍率
float CameraMoveSize	: CONTROLOBJECT < string name = "CameraMove.x"; >;
// 再生ボタンが押されてから移動開始までの時間(録画用)
// (WAIT_TIME>=0)[s]
static float WAIT_TIME	= CameraMoveSize/10.0;

// 倍率調整
static float2 ForwardD	= ForwardDistance*Size;	// Z
static float2 BackD		= BackDistance*Size;	// Z
static float2 LeftD		= LeftDistance*Size;	// X
static float2 RightD	= RightDistance*Size;	// X
static float2 DownD		= DownDistance*Size;	// Y
static float2 UpD		= UpDistance*Size;		// Y

// 移動情報を保存
#define TEX_WIDTH	1
#define TEX_HEIGHT	2
texture texMoveMatDB : RenderDepthStencilTarget <
	int Width=TEX_WIDTH; int Height=TEX_HEIGHT; string Format = "D24S8";
>;
texture texMoveMat1 : RenderColorTarget <
	int Width=TEX_WIDTH; int Height=TEX_HEIGHT; string Format="A32B32G32R32F";
>;
shared texture texMoveMat2 : RenderColorTarget <
	int Width=TEX_WIDTH; int Height=TEX_HEIGHT; string Format="A32B32G32R32F";
>;
sampler smpMoveMat1 = sampler_state{
	Texture = <texMoveMat1>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;
    AddressU = Wrap; AddressV = Wrap;
};
sampler smpMoveMat2 = sampler_state{
	Texture = <texMoveMat2>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;
    AddressU = Wrap; AddressV = Wrap;
};

////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
// 時間[s]
float time_0_X : Time;
// フレーム間時間
float ftime : ELAPSEDTIME;
// テクスチャオフセット
static float2 TexOffset = (float2)0.5/float2(TEX_WIDTH,TEX_HEIGHT);

// クォータニオン→行列
float4x4 Quaternion2Matrix(float4 q){
	return float4x4(
				1-2*q.y*q.y-2*q.z*q.z,	2*q.x*q.y-2*q.w*q.z,	2*q.x*q.z+2*q.w*q.y,	0,
				2*q.x*q.y+2*q.w*q.z,	1-2*q.x*q.x-2*q.z*q.z,	2*q.y*q.z-2*q.w*q.x,	0,
				2*q.x*q.z-2*q.w*q.y,	2*q.y*q.z+2*q.w*q.x,	1-2*q.x*q.x-2*q.y*q.y,	0,
				0,						0,						0,						1	);
}
// Axis
float4 QuaternionAxis(float rad, float3 n){
	return float4(sin(rad*0.5)*n.x, sin(rad*0.5)*n.y, sin(rad*0.5)*n.z, cos(rad*0.5));
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
// Yaw(Y) Pitch(X) Roll(Z)
// y,p,r = Radian
float4 QuaternionYawPitchRoll(float y, float p, float r){
	y*=0.5;	p*=0.5; r*=0.5;
	return float4(	cos(y)*sin(p)*cos(r)-sin(y)*cos(p)*sin(r),
					sin(y)*cos(p)*cos(r)+cos(y)*sin(p)*sin(r),
					cos(y)*cos(p)*sin(r)-sin(y)*sin(p)*cos(r),
					cos(y)*cos(p)*cos(r)+sin(y)*sin(p)*sin(r)	);
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
// クォータニオンから回転後の軸を取得する
float3 Quaternion2AxisX(float4 q){
	return float3(	1-2*q.y*q.y-2*q.z*q.z,	2*q.x*q.y-2*q.w*q.z,	2*q.x*q.z+2*q.w*q.y	);
}
float3 Quaternion2AxisY(float4 q){
	return float3(	2*q.x*q.y+2*q.w*q.z,	1-2*q.x*q.x-2*q.z*q.z,	2*q.y*q.z-2*q.w*q.x	);
}
float3 Quaternion2AxisZ(float4 q){
	return float3(	2*q.x*q.z-2*q.w*q.y,	2*q.y*q.z+2*q.w*q.x,	1-2*q.x*q.x-2*q.y*q.y );
}
// 飛行機の動き用
// 回転後の軸を使用する
float4 QuaternionFlightYawPitchRoll(float4 q, float y, float p, float r){
	float3 axisX = Quaternion2AxisX(q);
	float3 axisY = Quaternion2AxisY(q);
	float3 axisZ = Quaternion2AxisZ(q);
	float4 qYaw = QuaternionAxis(y, axisY);
	float4 qPitch = QuaternionAxis(p, axisX);
	float4 qRoll = QuaternionAxis(r, axisZ);
	return QuaternionMultiply(QuaternionMultiply(qYaw, qPitch), qRoll);
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 頂点出力
struct VS_OUTPUT {
	float4 Pos	: POSITION;
	float2 Tex	: TEXCOORD0;
};
// 移動処理
// 頂点シェーダ
VS_OUTPUT MoveVS( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ) {
	VS_OUTPUT Out = (VS_OUTPUT)0;
	Out.Pos = Pos;
	Out.Tex = Tex + TexOffset;
	return Out;
}
// ピクセルシェーダ
float4 MovePS1( VS_OUTPUT In ) : COLOR
{
	float4 Color = (float4)1;
	if(time_0_X <= WAIT_TIME){
		Color = float4(0,0,0,1);
	}
	else{
		Color=tex2D(smpMoveMat2, In.Tex);
	}
	return Color;
}
// ピクセルシェーダ
float4 MovePS2( VS_OUTPUT In ) : COLOR
{
	float4 Color = (float4)1;
	Color=tex2D(smpMoveMat1, In.Tex);
	if(In.Tex.y<1.0/TEX_HEIGHT){
		// 距離を元に移動量を計算
		float3 mv=(float3)0;
		// 前進
		mv.z += 1.0 - saturate(abs(ForwardD.x-CenterControl._43)/ForwardD.y);
		// 後退
		mv.z -= 1.0 - saturate(abs(BackD.x-CenterControl._43)/BackD.y);
		// 上
		mv.y += 1.0 - saturate(abs(UpD.x-RightControl._42)/UpD.y);
		mv.y += 1.0 - saturate(abs(UpD.x-LeftControl._42)/UpD.y);
		// 下
		mv.y -= 1.0 - saturate(abs(DownD.x-RightControl._42)/DownD.y);
		mv.y -= 1.0 - saturate(abs(DownD.x-LeftControl._42)/DownD.y);
		// 回転方向に移動
		float4 q = tex2D(smpMoveMat1, float2(0.5,0.75));
		// カメラのオフセットを考慮
		float4 qCam = QuaternionYawPitchRoll(-CamRot.y,-CamRot.x,-CamRot.z);
		q = QuaternionMultiply(q, qCam);
		// 行列に変換
		float4x4 rot = Quaternion2Matrix(q);
		Color.rgb += mul(mv*Velocity*ftime, rot);
	}
	else{
		float3 mv=(float3)0;
		// 回転
		// Yaw
		mv.x -= 1.0 - saturate(abs(RightD.x-RightControl._41)/RightD.y);// 右
		mv.x += 1.0 - saturate(abs(LeftD.x-LeftControl._41)/LeftD.y);	// 左
		// 回転量
		mv = mv * RotateYPR * ftime;
		float4 q = tex2D(smpMoveMat1, float2(0.5,0.75));
		// 回転クォータニオン計算
		q = QuaternionFlightYawPitchRoll(q, mv.x,mv.y,mv.z);
		Color = QuaternionMultiply(Color, q);
	}
	return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// テクニック
technique Main <
	string Script =
		"RenderColorTarget0=texMoveMat1; RenderDepthStencilTarget=texMoveMatDB;"
			"Pass=PassMove1;"
		"RenderColorTarget0=texMoveMat2;"
			"Pass=PassMove2;"
	;
> {
	pass PassMove1 < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		AlphaBlendEnable = FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
		VertexShader = compile vs_3_0 MoveVS();
		PixelShader = compile ps_3_0 MovePS1();
	}
	pass PassMove2 < string Script= "Draw=Buffer;"; > {
		ALPHABLENDENABLE = FALSE;
	    ALPHATESTENABLE=FALSE;
		AlphaBlendEnable = FALSE;
		ZENABLE = FALSE;
		ZWRITEENABLE = FALSE;
		VertexShader = compile vs_3_0 MoveVS();
		PixelShader = compile ps_3_0 MovePS2();
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////