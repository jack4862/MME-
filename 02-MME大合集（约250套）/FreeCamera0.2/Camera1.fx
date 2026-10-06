////////////////////////////////////////////////////////////////////////////////////////////////
//
//  名前:独自のカメラで描画する
//	作成;kion
//	種類:オブジェクト
//	説明:
//		full.fxの改良版
//		ピクセルシェーダーでライティング
//		テクニックの並びを少し変更
//  参考:full.fx ver1.3(by 舞力介入P)			
//
////////////////////////////////////////////////////////////////////////////////////////////////
// エフェクト宣言 //
float Script : STANDARDSGLOBAL <
	string ScriptOutput = "color";
	string ScriptClass = "object";
	string ScriptOrder = "standard";
> = 0.8;
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
// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float Aspect = ViewportSize.y/ViewportSize.x;

////////////////////////////////////////////////////////////////////////////////////////////////
// カメラ
// 透視変換行列計算
// MMD標準のカメラから奥行きをコピー
float4x4 calcProjection(float fov, float aspect, float4x4 proj) {
	float4x4 Out = proj;
	Out._22 = 1/tan(fov*0.5);
	Out._11 = aspect * Out._22;
    return Out;
}

// カメラ位置
static float3 CameraPosition = CamMat._41_42_43;
// カメラの行列
float4x4 WorldViewProjMatrix: WORLDVIEWPROJECTION;
float4x4 WorldMatrix		: WORLD;
float4x4 ViewMatrix			: VIEW;
float4x4 Proj				: PROJECTION;
static float4x4 ProjMatrix = calcProjection(radians(FovD), Aspect, Proj);

// カメラ行列格納テクスチャ
shared texture texViewMat : RenderColorTarget;
// サンプラー
sampler smpViewMat = sampler_state{
	Texture = <texViewMat>;
	MinFilter = POINT; MagFilter = POINT; MipFilter = POINT;
    AddressU = Clamp; AddressV = Clamp;
};

// クォータニオン→行列
float4x4 Quaternion2Matrix(float4 q){
	return float4x4(
				1-2*q.y*q.y-2*q.z*q.z,	2*q.x*q.y-2*q.w*q.z,	2*q.x*q.z+2*q.w*q.y,	0,
				2*q.x*q.y+2*q.w*q.z,	1-2*q.x*q.x-2*q.z*q.z,	2*q.y*q.z-2*q.w*q.x,	0,
				2*q.x*q.z-2*q.w*q.y,	2*q.y*q.z+2*q.w*q.x,	1-2*q.x*q.x-2*q.y*q.y,	0,
				0,						0,						0,						1	);
}
// 移動行列取得
float4x4 MoveViewMatrix(){
	float4x4 view = {	1,0,0,0,
						0,1,0,0,
						0,0,1,0,
						0,0,0,1 };
	// 移動
	view._41_42_43 = tex2Dlod(smpViewMat, float4(0.5,0.25, 0,0)).rgb;	
	// 回転
	view = mul(view, Quaternion2Matrix(tex2Dlod(smpViewMat, float4(0.5,0.75, 0,0))) );
	view._41_42_43*=-1;
	return view;
}
// 頂点変換
float4 MovePosition(float4 Pos){
	return mul(Pos, mul(mul(WorldMatrix, MoveViewMatrix()), ProjMatrix));
}

////////////////////////////////////////////////////////////////////////////////////////////////
// ライトの行列
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

// ライト方向
float3 LightDirection	: DIRECTION	< string Object = "Light"; >;

// オブジェクト材質
float4 MaterialDiffuse	: DIFFUSE	< string Object = "Geometry"; >;	// 拡散
float3 MaterialAmbient	: AMBIENT	< string Object = "Geometry"; >;	// 環境
float3 MaterialEmmisive	: EMISSIVE	< string Object = "Geometry"; >;	// 発光
float3 MaterialSpecular	: SPECULAR	< string Object = "Geometry"; >;	// 反射
float SpecularPower		: SPECULARPOWER < string Object = "Geometry"; >;
float3 MaterialToon		: TOONCOLOR;
float4 EdgeColor		: EDGECOLOR;

// ライト色
float3 LightDiffuse		: DIFFUSE	< string Object = "Light"; >;	// 拡散
float3 LightAmbient		: AMBIENT	< string Object = "Light"; >;	// 環境
float3 LightSpecular	: SPECULAR	< string Object = "Light"; >;	// 反射

// 拡散
static float4 DiffuseColor	= MaterialDiffuse * float4(LightDiffuse, 1.0f);
// 環境
static float3 AmbientColor	= saturate(MaterialAmbient * LightAmbient + MaterialEmmisive);
// 反射
static float3 SpecularColor	= MaterialSpecular * LightSpecular;

// 描画オプション
bool parthf;   // セルフシャドウのモード2
bool transp;   // 半透明フラグ
bool spadd;    // スフィアマップ加算合成フラグ
#define SKII1	1500
#define SKII2	8000
#define Toon	3

// テクスチャ
// オブジェクト
texture ObjectTexture: MATERIALTEXTURE;
// スフィアマップ
texture ObjectSphereMap: MATERIALSPHEREMAP;

// サンプラー
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR; MAGFILTER = LINEAR;
};
sampler ObjSphareSampler = sampler_state {
	texture = <ObjectSphereMap>;
	MINFILTER = LINEAR; MAGFILTER = LINEAR;
};
// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
//sampler MMDSamp2 : register(s2);


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）
// 頂点出力
struct VS_OUTPUT {
    float4 Pos		: POSITION;		// 射影変換座標
    float2 Tex		: TEXCOORD1;	// テクスチャ座標
    float3 Normal	: TEXCOORD2;	// 法線(ワールド)
    float3 Eye		: TEXCOORD3;	// カメラとの相対位置
    float2 SpTex	: TEXCOORD4;	// スフィアマップテクスチャ座標
};
// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;
	// 移動行列
	float4x4 view = MoveViewMatrix();
	// ワールドビュー射影変換
//	Out.Pos = mul(Pos, WorldViewProjMatrix);
	Out.Pos = mul(Pos, mul(mul(WorldMatrix, view), ProjMatrix));

	// カメラとの相対位置
	Out.Eye = CameraPosition - mul(Pos,WorldMatrix);
	// 頂点法線(ワールド空間)
	Out.Normal = normalize(mul(Normal,(float3x3)WorldMatrix));
	// テクスチャ座標
	Out.Tex = Tex;
	// スフィアマップ
	if(useSphereMap){
		// スフィアマップテクスチャ座標
		float2 NormalWV = mul( Out.Normal, (float3x3)view );
		Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
		Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
	}
	return Out;
}
// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT In, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR0
{
	// 環境光
	float4 Color = float4(AmbientColor, DiffuseColor.a);
	// 拡散光(トゥーン不使用)
	if(!useToon) Color.rgb += max(0,dot(In.Normal,-LightDirection)) * DiffuseColor.rgb;
	Color = saturate( Color );
	// 鏡面反射光
	float3 HalfVector = normalize(normalize(In.Eye) + -LightDirection);
	float3 Specular = pow( max(0,dot(HalfVector,normalize(In.Normal))), SpecularPower ) * SpecularColor;

	// テクスチャ
	if(useTexture) Color *= tex2D(ObjTexSampler,In.Tex);
	// スフィアマップ
	if(useSphereMap){
		if(spadd) Color += tex2D(ObjSphareSampler,In.SpTex);	// 加算
		else Color *= tex2D(ObjSphareSampler,In.SpTex);
	}
	// トゥーン
	if(useToon){
		float LightNormal = dot(In.Normal, -LightDirection);
		Color.rgb *= lerp(MaterialToon, float3(1,1,1), saturate(LightNormal * 16 + 0.5));
	}
	// スペキュラ適用
	Color.rgb += Specular;
	return Color;
}
///////////////////////////////////////////////////////////////////////////////////////////////
// テクニック（セルフシャドウOFF） //
// アクセサリ
technique MainTec0 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false; > {
	pass DrawObject {
		VertexShader = compile vs_3_0 Basic_VS(false, false, false);
		PixelShader  = compile ps_3_0 Basic_PS(false, false, false);
	}
}
technique MainTec1 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false; > {
	pass DrawObject {
		VertexShader = compile vs_3_0 Basic_VS(true, false, false);
		PixelShader  = compile ps_3_0 Basic_PS(true, false, false);
	}
}
technique MainTec2 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false; > {
	pass DrawObject {
		VertexShader = compile vs_3_0 Basic_VS(false, true, false);
		PixelShader  = compile ps_3_0 Basic_PS(false, true, false);
	}
}
technique MainTec3 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false; > {
	pass DrawObject {
		VertexShader = compile vs_3_0 Basic_VS(true, true, false);
		PixelShader  = compile ps_3_0 Basic_PS(true, true, false);
	}
}
// PMDモデル
technique MainTec4 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true; > {
	pass DrawObject {
		VertexShader = compile vs_3_0 Basic_VS(false, false, true);
		PixelShader  = compile ps_3_0 Basic_PS(false, false, true);
	}
}
technique MainTec5 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true; > {
	pass DrawObject {
		VertexShader = compile vs_3_0 Basic_VS(true, false, true);
		PixelShader  = compile ps_3_0 Basic_PS(true, false, true);
	}
}
technique MainTec6 < string MMDPass = "object"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true; > {
	pass DrawObject {
		VertexShader = compile vs_3_0 Basic_VS(false, true, true);
		PixelShader  = compile ps_3_0 Basic_PS(false, true, true);
	}
}
technique MainTec7 < string MMDPass = "object"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true; > {
	pass DrawObject {
		VertexShader = compile vs_3_0 Basic_VS(true, true, true);
		PixelShader  = compile ps_3_0 Basic_PS(true, true, true);
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）
// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);
// 頂点出力
struct BufferShadow_OUTPUT {
	float4 Pos		: POSITION;		// 射影変換座標
	float4 ZCalcTex	: TEXCOORD0;	// 射影変換座標(ライト)
	float2 Tex		: TEXCOORD1;	// テクスチャ座標
	float3 Normal	: TEXCOORD2;	// 法線(ワールド)
	float3 Eye		: TEXCOORD3;	// カメラとの相対位置
	float2 SpTex	: TEXCOORD4;	// スフィアマップテクスチャ座標
};
// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
	BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;
	
	// 移動行列
	float4x4 view = MoveViewMatrix();
	// ワールドビュー射影変換
//	Out.Pos = mul(Pos, WorldViewProjMatrix);
	Out.Pos = mul(Pos, mul(mul(WorldMatrix, view), ProjMatrix));
	
	// カメラとの相対位置
	Out.Eye = CameraPosition - mul(Pos, WorldMatrix);
	// 頂点法線(ワールド)
	Out.Normal = normalize(mul(Normal,(float3x3)WorldMatrix));
	// テクスチャ座標
    Out.Tex = Tex;
	// スフィアマップテクスチャ座標
	if(useSphereMap){
		float2 NormalWV = mul( Out.Normal, (float3x3)view );
		Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
		Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
	}
	// ライト視点によるワールドビュー射影変換
	Out.ZCalcTex = mul(Pos, LightWorldViewProjMatrix);
	return Out;
}
// ピクセルシェーダ
float4 BufferShadow_PS(BufferShadow_OUTPUT In, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR
{
	// 環境光
	float4 Color = float4(AmbientColor, DiffuseColor.a);
	// 拡散光(トゥーン不使用)
	if(!useToon) Color.rgb += max(0,dot(In.Normal,-LightDirection)) * DiffuseColor.rgb;
	Color = saturate( Color );
	// 鏡面反射光
	float3 HalfVector = normalize(normalize(In.Eye) + -LightDirection);
	float3 Specular = pow( max(0,dot(HalfVector,normalize(In.Normal))), SpecularPower ) * SpecularColor;
	// 影の色
	float4 ShadowColor = float4(AmbientColor, Color.a);

	// テクスチャ
	if(useTexture){
		float4 TexColor = tex2D(ObjTexSampler,In.Tex);
		Color *= TexColor;
		ShadowColor *= TexColor;
    }
	// スフィアマップ
    if(useSphereMap){
		float4 TexColor = tex2D(ObjSphareSampler,In.SpTex);
		if(spadd){	// 加算
			Color += TexColor; ShadowColor += TexColor;
		} else{
			Color *= TexColor; ShadowColor *= TexColor;
		}
	}
	// スペキュラ適用
	Color.rgb += Specular;
    
    // テクスチャ座標に変換
    In.ZCalcTex /= In.ZCalcTex.w;
    float2 TransTexCoord;
    TransTexCoord.x = (1.0f + In.ZCalcTex.x)*0.5f;
    TransTexCoord.y = (1.0f - In.ZCalcTex.y)*0.5f;

	// シャドウバッファ外
	if(any(saturate(TransTexCoord)!=TransTexCoord)) return Color;
	// シャドウバッファ内
	else{
		float comp;
		if(parthf)	// セルフシャドウ mode2 LPSM
			comp=1-saturate( max(In.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r,0.0f) * SKII2*TransTexCoord.y - 0.3f );
		else		// セルフシャドウ mode1
			comp=1-saturate( max(In.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r,0.0f) * SKII1 - 0.3f );
        // トゥーン適用
		if(useToon){
			comp = min(saturate(dot(In.Normal,-LightDirection)*Toon),comp);
			ShadowColor.rgb *= MaterialToon;
		}
		// 最終的な色
		float4 ans = lerp(ShadowColor, Color, comp);	// 元の色と影の色を線形合成
		// 半透明
		if(transp) ans.a = 0.5f;
		return ans;
	}
}
///////////////////////////////////////////////////////////////////////////////////////////////
// テクニック(セルフシャドウON)
// アクセサリ
technique MainTecBS0  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = false; > {
	pass DrawObject {
		VertexShader = compile vs_3_0 BufferShadow_VS(false, false, false);
		PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, false);
	}
}
technique MainTecBS1  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = false; > {
	pass DrawObject {
		VertexShader = compile vs_3_0 BufferShadow_VS(true, false, false);
		PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, false);
	}
}
technique MainTecBS2  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = false; > {
	pass DrawObject {
		VertexShader = compile vs_3_0 BufferShadow_VS(false, true, false);
		PixelShader  = compile ps_3_0 BufferShadow_PS(false, true, false);
	}
}
technique MainTecBS3  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = false; > {
	pass DrawObject {
		VertexShader = compile vs_3_0 BufferShadow_VS(true, true, false);
		PixelShader  = compile ps_3_0 BufferShadow_PS(true, true, false);
	}
}
// PMDモデル
technique MainTecBS4  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = false; bool UseToon = true; > {
	pass DrawObject {
		VertexShader = compile vs_3_0 BufferShadow_VS(false, false, true);
		PixelShader  = compile ps_3_0 BufferShadow_PS(false, false, true);
	}
}
technique MainTecBS5  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false; bool UseToon = true; > {
	pass DrawObject {
		VertexShader = compile vs_3_0 BufferShadow_VS(true, false, true);
		PixelShader  = compile ps_3_0 BufferShadow_PS(true, false, true);
	}
}
technique MainTecBS6  < string MMDPass = "object_ss"; bool UseTexture = false; bool UseSphereMap = true; bool UseToon = true; > {
	pass DrawObject {
		VertexShader = compile vs_3_0 BufferShadow_VS(false, true, true);
		PixelShader  = compile ps_3_0 BufferShadow_PS(false, true, true);
	}
}
technique MainTecBS7  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true; bool UseToon = true; > {
	pass DrawObject {
		VertexShader = compile vs_3_0 BufferShadow_VS(true, true, true);
		PixelShader  = compile ps_3_0 BufferShadow_PS(true, true, true);
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭 //
// 頂点シェーダ
float4 ColorRender_VS(float4 Pos : POSITION) : POSITION 
{
	// カメラ視点のワールドビュー射影変換
	return MovePosition(Pos);
//	return mul( Pos, WorldViewProjMatrix );
}
// ピクセルシェーダ
float4 ColorRender_PS() : COLOR
{
	return EdgeColor;
}
// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
	pass DrawEdge {
		AlphaBlendEnable = FALSE;
		AlphaTestEnable  = FALSE;
		VertexShader = compile vs_3_0 ColorRender_VS();
		PixelShader  = compile ps_3_0 ColorRender_PS();
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画
// 頂点シェーダ
float4 Shadow_VS(float4 Pos : POSITION) : POSITION
{
	// カメラ視点のワールドビュー射影変換
	return MovePosition(Pos);
//	return mul( Pos, WorldViewProjMatrix );
}
// ピクセルシェーダ
float4 Shadow_PS() : COLOR
{
	// アンビエント色で塗りつぶし
	return float4(AmbientColor.rgb, 0.65f);
}
// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {
	pass DrawShadow {
		VertexShader = compile vs_3_0 Shadow_VS();
		PixelShader  = compile ps_3_0 Shadow_PS();
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////
// シャドウバッファ
struct VS_ZValuePlot_OUTPUT {
	float4 Pos			: POSITION;	// 射影変換座標
	float4 ShadowMapTex	: TEXCOORD0;// Zバッファテクスチャ
};
// 頂点シェーダ
VS_ZValuePlot_OUTPUT ZValuePlot_VS( float4 Pos : POSITION )
{
	VS_ZValuePlot_OUTPUT Out = (VS_ZValuePlot_OUTPUT)0;
	// ライトの目線によるワールドビュー射影変換をする
	Out.Pos = mul( Pos, LightWorldViewProjMatrix );
    // テクスチャ座標を頂点に合わせる
    Out.ShadowMapTex = Out.Pos;
    return Out;
}
// ピクセルシェーダ
float4 ZValuePlot_PS( float4 ShadowMapTex : TEXCOORD0 ) : COLOR
{
	// R色成分にZ値を記録する
	return float4(ShadowMapTex.z/ShadowMapTex.w,0,0,1);
}
// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {
	pass ZValuePlot {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 ZValuePlot_VS();
		PixelShader  = compile ps_3_0 ZValuePlot_PS();
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////
