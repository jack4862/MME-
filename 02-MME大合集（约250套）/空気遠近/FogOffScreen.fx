
// エフェクト宣言 //
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "object";
	string ScriptOrder = "standard";
> = 0.8;
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ操作用オブジェクト
float3 XYZ : CONTROLOBJECT < string name = "(OffscreenOwner)"; string item = "XYZ";>;	// 座標
float X : CONTROLOBJECT < string name = "(OffscreenOwner)"; string item = "X";>;
float Y : CONTROLOBJECT < string name = "(OffscreenOwner)"; string item = "Y";>;
float Z : CONTROLOBJECT < string name = "(OffscreenOwner)"; string item = "Z";>;
float3 Rxyz : CONTROLOBJECT < string name = "(OffscreenOwner)"; string item="Rxyz";>;	// 角度
float Scale : CONTROLOBJECT < string name = "(OffscreenOwner)"; string item = "Si";>;	// スケール
float Tr : CONTROLOBJECT < string name = "(OffscreenOwner)"; string item = "Tr";>;	// 透過度
bool CenterFlag : CONTROLOBJECT < string name = "FogCenter.x"; >;			// 中心指定
float4x4 CenterMatrix : CONTROLOBJECT < string name = "FogCenter.x"; >;		// 中心位置
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメーター //
// フォグの底(デフォルトは0)
// 底より下は見えない
float BottomFog = 0;

// 滑らかさ
// 大きいほど変化がなだらかになる。
// Xが手前、Yが奥
// デフォルトは(X,Y)=(1,2);
// (X,Y)=(1,1)で変化が直線になる。
float2 FogParam = {1.0, 2.0};

// 透過度以下を切り捨て
#define CLIP_ALPHA 0.1


////////////////////////////////////////////////////////////////////////////////////////////////
// 外部パラメータ //
// カメラの行列
float4x4 WorldViewProjMatrix: WORLDVIEWPROJECTION;
float4x4 WorldMatrix		: WORLD;
float4x4 ViewMatrix			: VIEW;
float4x4 ProjMatrix			: PROJECTION;
// カメラ位置
float3 CameraPosition	: POSITION	< string Object = "Camera"; >;

// オブジェクト材質
float4 MaterialDiffuse	: DIFFUSE	< string Object = "Geometry"; >;	// 拡散
// ライト色
float3 LightDiffuse		: DIFFUSE	< string Object = "Light"; >;	// 拡散
// 拡散
static float4 DiffuseColor	= MaterialDiffuse * float4(LightDiffuse, 1.0f);

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    Filter = LINEAR;
};
// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

// フォグパラメータ
static float2 fog1 = float2(X, 3000+Z);
static float2 fog2 = float2(BottomFog, 20111+Y);


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画
// 頂点出力
struct VS_OUTPUT {
	float4 Pos	: POSITION;		// 射影変換座標
	float4 PosW	: TEXCOORD0;	// 変換済み座標
	float2 Tex	: TEXCOORD1;	// テクスチャ座標
};
// 頂点シェーダ
VS_OUTPUT Z_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0) 
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	// ワールドビュー射影変換
	Out.Pos = mul(Pos, WorldViewProjMatrix);
	Out.PosW = mul(Pos, WorldMatrix);
	// テクスチャ座標
	Out.Tex = Tex;
	return Out;
}
// ピクセルシェーダ
float4 Z_PS(VS_OUTPUT In, uniform bool useTexture) : COLOR
{
	// テクスチャ
	if(useTexture) DiffuseColor.a*=tex2D(ObjTexSampler,In.Tex).a;
	if(DiffuseColor.a<=CLIP_ALPHA) clip(-1);
	// 深度計算
	In.PosW.xyz/=In.PosW.w;
	In.PosW.w = distance(In.PosW.xyz,CameraPosition);
	float4 pos = In.PosW;
	// 中心位置を固定する場合
	if(CenterFlag) pos.w = distance(pos.xyz, CenterMatrix._41_42_43);
	// フォグのかかり具合を出力
	float f1 = 1.0-pow(1.0-pow(saturate((pos.w-fog1.x)/(fog1.y-fog1.x)), FogParam.x), FogParam.y);
	float f2 = pow(1.0-pow(saturate((pos.y-fog2.x)/(fog2.y-fog2.x)), FogParam.x), FogParam.y);
	return float4(saturate(f1*f2), 0, 0, DiffuseColor.a*Tr);
}

///////////////////////////////////////////////////////////////////////////////////////////////
// テクニック //
technique MainTec0 < string MMDPass = "object"; bool UseTexture = false; > {
	pass DrawObject {
		VertexShader = compile vs_2_0 Z_VS();
		PixelShader  = compile ps_2_0 Z_PS(false);
	}
}
technique MainTec1 < string MMDPass = "object"; bool UseTexture = true; > {
	pass DrawObject {
		VertexShader = compile vs_2_0 Z_VS();
		PixelShader  = compile ps_2_0 Z_PS(true);
	}
}
technique MainTecBS0  < string MMDPass = "object_ss"; bool UseTexture = false; > {
	pass DrawObject {
		VertexShader = compile vs_2_0 Z_VS();
		PixelShader  = compile ps_2_0 Z_PS(false);
	}
}
technique MainTecBS1  < string MMDPass = "object_ss"; bool UseTexture = true; > {
	pass DrawObject {
		VertexShader = compile vs_2_0 Z_VS();
		PixelShader  = compile ps_2_0 Z_PS(true);
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////
// ピクセルシェーダ
float4 EdgeZ_PS(VS_OUTPUT In) : COLOR
{
	// 深度計算
	In.PosW.xyz/=In.PosW.w;
	In.PosW.w = distance(In.PosW.xyz,CameraPosition);
	float4 pos = In.PosW;
	// 中心位置を固定する場合
	if(CenterFlag) pos.xyz -= CenterMatrix._41_42_43;
	// フォグのかかり具合を出力
	float f1 = 1.0-pow(1.0-pow(saturate((pos.w-fog1.x)/(fog1.y-fog1.x)), FogParam.x), FogParam.y);
	float f2 = pow(1.0-pow(saturate((pos.y-fog2.x)/(fog2.y-fog2.x)), FogParam.x), FogParam.y);
	return float4(saturate(f1*f2), 0, 0, Tr);
}
// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
	pass DrawEdge {
		VertexShader = compile vs_2_0 Z_VS();
		PixelShader  = compile ps_2_0 EdgeZ_PS();
	}
}
// 影（非セルフシャドウ）描画
technique ShadowTec < string MMDPass = "shadow"; > { }
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > { }

///////////////////////////////////////////////////////////////////////////////////////////////
