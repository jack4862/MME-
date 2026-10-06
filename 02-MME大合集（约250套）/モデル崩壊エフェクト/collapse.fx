////////////////////////////////////////////////////////////////////////////////////////////////
//
//	collapse.fx モデルがバラバラに分解されるエフェクト ver 1.5 by Led/折鶴P
//	下準備スクリプトを適用したモデルに使ってください。
//	元になったファイル：full.fx ver2.0 作成: 舞力介入P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// コントローラーのファイル名  複数コントローラーを使うときはここを変更

#define CONTROLLERNAME "collapse_controller.pmx"

////////////////////////////////////////////////////////////////////////////////

// パラメータ宣言


#define LARGEUV	 		500		// 目印用のUVのx座標閾値
#define	NOT_USE_ROUND_TEX		//	これを定義しておくと P角落とし.pngを使用しない
//#define	NOT_USE_ARRANGE_TEX		//	これを定義しておくと Arrange.png を使用しない

//--------------------------------------------------------------------------------------
//	崩壊システム読み込み
#include "collapse-sys.fxsub"




//	座法変換行列
float4x4 WorldViewProjMatrix		: WORLDVIEWPROJECTION;
float4x4 WorldMatrix				: WORLD;
float4x4 ViewMatrix					: VIEW;
float4x4 LightWorldViewProjMatrix	: WORLDVIEWPROJECTION < string Object = "Light"; >;

float3	 LightDirection				: DIRECTION < string Object = "Light"; >;
float3	 CameraPosition				: POSITION	< string Object = "Camera"; >;

// マテリアル色
float4	 MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3	 MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3	 MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3	 MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float	 SpecularPower	   : SPECULARPOWER < string Object = "Geometry"; >;
float3	 MaterialToon	   : TOONCOLOR;
float4	 EdgeColor		   : EDGECOLOR;
float4	 GroundShadowColor : GROUNDSHADOWCOLOR;
// ライト色
float3	 LightDiffuse	   : DIFFUSE   < string Object = "Light"; >;
float3	 LightAmbient	   : AMBIENT   < string Object = "Light"; >;
float3	 LightSpecular	   : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor	= MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor	= MaterialAmbient  * LightAmbient + MaterialEmmisive;
static float3 SpecularColor = MaterialSpecular * LightSpecular;

// テクスチャ材質モーフ値
float4	 TextureAddValue   : ADDINGTEXTURE;
float4	 TextureMulValue   : MULTIPLYINGTEXTURE;
float4	 SphereAddValue    : ADDINGSPHERETEXTURE;
float4	 SphereMulValue    : MULTIPLYINGSPHERETEXTURE;

bool	use_texture;
bool	use_spheremap;
bool	use_subtexture;		//	サブテクスチャフラグ
bool	use_toon;

bool	 parthf;   // パースペクティブフラグ
bool	 transp;   // 半透明フラグ
bool	 spadd;    // スフィアマップ加算合成フラグ
#define SKII1	 1500
#define SKII2	 8000
#define Toon	 3

#define FARAWAY float4(0,0,0,-1) //Pクリップで指定範囲からはみ出した破片の行先


// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
	texture = <ObjectTexture>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
	MIPFILTER = LINEAR;
	ADDRESSU  = WRAP;
	ADDRESSV  = WRAP;
};

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
	texture = <ObjectSphereMap>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
	MIPFILTER = LINEAR;
	ADDRESSU  = WRAP;
	ADDRESSV  = WRAP;
};

// トゥーンマップのテクスチャ
texture ObjectToonTexture: MATERIALTOONTEXTURE;
sampler ObjToonSampler = sampler_state {
	texture = <ObjectToonTexture>;
	MINFILTER = LINEAR;
	MAGFILTER = LINEAR;
	MIPFILTER = NONE;
	ADDRESSU  = CLAMP;
	ADDRESSV  = CLAMP;
};

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画
struct VS_OUTPUT_E {
	float4 Pos		  : POSITION;	 // 射影変換座標
	float2 Tex		  : TEXCOORD1;	 // テクスチャ
	float3 Normal	  : TEXCOORD2;	 // 法線
	float3 Eye		  : TEXCOORD3;	 // カメラとの相対位置
	float2 SpTex	  : TEXCOORD4;	 // スフィアマップテクスチャ座標
	float2 XisDistance: TEXCOORD5;	 // 動き出してからの距離
	float4 Position	  : TEXCOORD6;	 // ピクセルシェーダで使う用の座標
	float2 PRound	  : TEXCOORD7;	 // 角落とし用のテクスチャ座標
	float4 Color	  : COLOR0; 	 // ディフューズ色
	float3 Specular   : COLOR1; 	 // スペキュラ色
};

// 頂点シェーダ
VS_OUTPUT_E ColorRender_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, float2 Tex2 : TEXCOORD1, int ind :_INDEX )// : POSITION 
{
	VS_OUTPUT_E Out=(VS_OUTPUT_E)0;

	CalcCollapse( Pos, Normal, Tex, ind, Out.Position, Out.XisDistance, Out.PRound );

	// カメラ視点のワールドビュー射影変換
	Out.Pos=mul( Pos, WorldViewProjMatrix );

	if( Out.XisDistance.x > TransparentPCulling.y ) {
		Out.Pos	= FARAWAY;
	}

	return Out;
}

// ピクセルシェーダ
float4 ColorRender_PS(VS_OUTPUT_E IN) : COLOR
{
	float4 Color=EdgeColor;
	Color.a*=ParticleAlpha(IN.Position,IN.XisDistance,IN.Tex,IN.PRound);
	// 輪郭色で塗りつぶし
	return Color;
}


///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

// 頂点シェーダ
float4 Shadow_VS(float4 Pos : POSITION, float2 Tex: TEXCOORD0) : Position
{
	// カメラ視点のワールドビュー射影変換
	Pos.xyz+=float3((int)Tex.y+0.99,0,0);
	return mul( Pos, WorldViewProjMatrix );
}

// ピクセルシェーダ
float4 Shadow_PS() : COLOR
{
	// 地面影色で塗りつぶし
	return GroundShadowColor;
}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
	float4 Pos		  : POSITION;	 // 射影変換座標
	float2 Tex		  : TEXCOORD1;	 // テクスチャ
	float3 Normal	  : TEXCOORD2;	 // 法線
	float3 Eye		  : TEXCOORD3;	 // カメラとの相対位置
	float2 SpTex	  : TEXCOORD4;	 // スフィアマップテクスチャ座標
	float2 XisDistance: TEXCOORD5;	 // 動き出してからの距離
	float4 Position	  : TEXCOORD6;	 // ピクセルシェーダで使う用の座標
	float2 PRound	  : TEXCOORD7;	 // 角落とし用のテクスチャ座標
	float4 Color	  : COLOR0; 	 // ディフューズ色
	float3 Specular   : COLOR1; 	 // スペキュラ色
};

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, float2 Tex2 : TEXCOORD1, int ind :_INDEX, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
	VS_OUTPUT Out = (VS_OUTPUT)0;

	CalcCollapse( Pos, Normal, Tex, ind, Out.Position, Out.XisDistance, Out.PRound );

	// カメラ視点のワールドビュー射影変換
	Out.Pos = mul( Pos, WorldViewProjMatrix );

	// カメラとの相対位置
	Out.Eye = CameraPosition - mul( Pos, WorldMatrix );
	// 頂点法線
	Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	
	// ディフューズ色＋アンビエント色 計算
	Out.Color.rgb = AmbientColor;
	if ( !useToon ) {
		Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
	}
	Out.Color.a = DiffuseColor.a;
	Out.Color = saturate( Out.Color );
	
	// テクスチャ座標
	Out.Tex = Tex;
	
	if ( useSphereMap ) {
		if ( use_subtexture ) {
			// PMXサブテクスチャ座標
			Out.SpTex = Tex2;
		} else {
			// スフィアマップテクスチャ座標
			float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
			Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
			Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
		}
	}
	
	// スペキュラ色計算
	float3 HalfVector = normalize( normalize(Out.Eye) + -LightDirection );
	Out.Specular = pow( max(0,dot( HalfVector, Out.Normal )), SpecularPower ) * SpecularColor;

	if( Out.XisDistance.x > TransparentPCulling.y ) {
		Out.Pos	= FARAWAY;
	}

	return Out;
}

// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR0
{
	float4 Color = IN.Color;
	if ( useTexture ) {
		// テクスチャ適用
		Color *= tex2D( ObjTexSampler, IN.Tex );
	}
	if ( useSphereMap ) {
		// スフィアマップ適用
		float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
		if(spadd) Color.rgb += TexColor.rgb;
		else	  Color.rgb *= TexColor.rgb;
		Color.a *= TexColor.a;
	}

	Color.rgb+=ColorBoost(IN.XisDistance); 
	
	if ( useToon ) {
		// トゥーン適用
		float LightNormal = dot( IN.Normal, -LightDirection );
		Color *= tex2D(ObjToonSampler, float2(0, 0.5 - LightNormal * 0.5) );
	}
	
	// スペキュラ適用
	Color.rgb += IN.Specular;

	Color.a*=ParticleAlpha(IN.Position,IN.XisDistance.x,IN.Tex,IN.PRound);

//	Color.a	= saturate( Color.a ) + 0.2;
	
	return Color;
}


///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット
// 頂点シェーダ
float4	ZValuePlot_VS(	float4		Pos			: POSITION
							,		float3		Normal		: NORMAL
							,	inout float2	Tex			: TEXCOORD0
							,		int			ind			:_INDEX
							,	out float4		ShadowMapTex: TEXCOORD1
							,	out float2		XisDistance	: TEXCOORD5
							,	out float4		Position	: TEXCOORD6
							,	out float2		PRound		: TEXCOORD7
	) : POSITION
{
	float4	vPosition;

	CalcCollapse( Pos, Normal, Tex, ind, Position, XisDistance, PRound );

	// ライトの目線によるワールドビュー射影変換をする
	vPosition	= mul( Pos, LightWorldViewProjMatrix );

	// テクスチャ座標を頂点に合わせる
	ShadowMapTex	= vPosition;

	if( XisDistance.x > TransparentPCulling.y ) {
		vPosition	= FARAWAY;
	}

	return vPosition;
}

// ピクセルシェーダ
float4 ZValuePlot_PS(	float4	ShadowMapTex	: TEXCOORD1
					,	float2	Tex				: TEXCOORD0
					,	float2	XisDistance		: TEXCOORD5
					,	float4	Position		: TEXCOORD6
					,	float2	PRound			: TEXCOORD7
					) : COLOR
{
	clip( ParticleAlpha( Position, XisDistance.x, Tex, PRound ) - 0.1 );

	// R色成分にZ値を記録する
	return float4(ShadowMapTex.z/ShadowMapTex.w,0,0,1);
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

// シャドウバッファのサンプラ。"register(s0)"なのはMMDがs0を使っているから
sampler DefSampler : register(s0);

struct BufferShadow_OUTPUT {
	float4 Pos		: POSITION; 	// 射影変換座標
	float4 ZCalcTex : TEXCOORD0;	// Z値
	float2 Tex		: TEXCOORD1;	// テクスチャ
	float3 Normal	: TEXCOORD2;	// 法線
	float3 Eye		: TEXCOORD3;	// カメラとの相対位置
	float2 SpTex	: TEXCOORD4;	 // スフィアマップテクスチャ座標
	float2 XisDistance: TEXCOORD5;	
	float4 Position	  : TEXCOORD6;	 // ピクセルシェーダで使う用の座標
	float2 PRound	  : TEXCOORD7;	 // 角落とし用のテクスチャ座標
	float4 Color	: COLOR0;		// ディフューズ色
};

// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, float2 Tex2 : TEXCOORD1, int ind:_INDEX, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
	BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

	CalcCollapse( Pos, Normal, Tex, ind, Out.Position, Out.XisDistance, Out.PRound );

	// カメラ視点のワールドビュー射影変換
	Out.Pos = mul( Pos, WorldViewProjMatrix );
	
	// カメラとの相対位置
	Out.Eye = CameraPosition - mul( Pos, WorldMatrix );

	// 頂点法線
	Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );
	// ライト視点によるワールドビュー射影変換
	Out.ZCalcTex = mul( Pos, LightWorldViewProjMatrix );
	
	// ディフューズ色＋アンビエント色 計算
	Out.Color.rgb = AmbientColor;
	if ( !useToon ) {
		Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
	}
	Out.Color.a = DiffuseColor.a;
	Out.Color = saturate( Out.Color );
	
	// テクスチャ座標
	Out.Tex = Tex;
	
	if ( useSphereMap ) {
		if ( use_subtexture ) {
			// PMXサブテクスチャ座標
			Out.SpTex = Tex2;
		} else {
			// スフィアマップテクスチャ座標
			float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
			Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
			Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
		}
	}


	if( Out.XisDistance.x > TransparentPCulling.y ) {
		Out.Pos.w	= -1;
	}

	return Out;
}

// ピクセルシェーダ
float4 BufferShadow_PS(BufferShadow_OUTPUT IN, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon) : COLOR
{
	// スペキュラ色計算
	float3 HalfVector = normalize( normalize(IN.Eye) + -LightDirection );
	float3 Specular = pow( max(0,dot( HalfVector, normalize(IN.Normal) )), SpecularPower ) * SpecularColor;
	
	float4 Color = IN.Color;
	float4 ShadowColor = float4(saturate(AmbientColor), Color.a);  // 影の色
	if ( useTexture ) {
		// テクスチャ適用
		float4 TexColor = tex2D( ObjTexSampler, IN.Tex );
		// テクスチャ材質モーフ数
		TexColor.rgb = lerp(1, TexColor * TextureMulValue + TextureAddValue, TextureMulValue.a + TextureAddValue.a);
		Color *= TexColor;
		ShadowColor *= TexColor;
	}
	if ( useSphereMap ) {
		// スフィアマップ適用
		float4 TexColor = tex2D(ObjSphareSampler,IN.SpTex);
		// スフィアテクスチャ材質モーフ数
		TexColor.rgb = lerp(spadd?0:1, TexColor * SphereMulValue + SphereAddValue, SphereMulValue.a + SphereAddValue.a);
		if(spadd) {
			Color.rgb += TexColor.rgb;
			ShadowColor.rgb += TexColor.rgb;
		} else {
			Color.rgb *= TexColor.rgb;
			ShadowColor.rgb *= TexColor.rgb;
		}
		Color.a *= TexColor.a;
		ShadowColor.a *= TexColor.a;
	}
	// スペキュラ適用
	Color.rgb += Specular;
	
	// テクスチャ座標に変換
	IN.ZCalcTex /= IN.ZCalcTex.w;
	float2 TransTexCoord;
	TransTexCoord.x = (1.0f + IN.ZCalcTex.x)*0.5f;
	TransTexCoord.y = (1.0f - IN.ZCalcTex.y)*0.5f;
	
	if( all( saturate(TransTexCoord) == TransTexCoord ) ) {
		float comp;
		if(parthf) {
			// セルフシャドウ mode2
			comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII2*TransTexCoord.y-0.3f);
		} else {
			// セルフシャドウ mode1
			comp=1-saturate(max(IN.ZCalcTex.z-tex2D(DefSampler,TransTexCoord).r , 0.0f)*SKII1-0.3f);
		}
		if ( useToon ) {
			// トゥーン適用
			comp = min(saturate(dot(IN.Normal,-LightDirection)*Toon),comp);
			ShadowColor.rgb *= MaterialToon;
		}
		
		Color	= lerp(ShadowColor, Color, comp);
		if( transp ) Color.a = 0.5f;
	}

	Color.rgb+=ColorBoost(IN.XisDistance); 
	Color.a*=ParticleAlpha(IN.Position,IN.XisDistance,IN.Tex,IN.PRound);
	return Color;
}


///////////////////////////////////////////////////////////////////////////////////////////////

// オブジェクト描画用テクニック（アクセサリ用）
// 不要なものは削除可
technique MainTec < string MMDPass = "object"; > {
	pass DrawObject {
#ifdef	NOT_ZWRITE
		ZWriteEnable	= false;
#endif
		VertexShader	= compile vs_3_0 Basic_VS(use_texture, use_spheremap, use_toon);
		PixelShader		= compile ps_3_0 Basic_PS(use_texture, use_spheremap, use_toon);
	}
}

// オブジェクト描画用テクニック（アクセサリ用）
technique MainTecBS  < string MMDPass = "object_ss"; > {
	pass DrawObject {
#ifdef	NOT_ZWRITE
		ZWriteEnable	= false;
#endif
		VertexShader	= compile vs_3_0 BufferShadow_VS(use_texture, use_spheremap, use_toon);
		PixelShader		= compile ps_3_0 BufferShadow_PS(use_texture, use_spheremap, use_toon);
	}
}

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > {
	pass ZValuePlot {
		AlphaBlendEnable = FALSE;
		VertexShader = compile vs_3_0 ZValuePlot_VS();
		PixelShader  = compile ps_3_0 ZValuePlot_PS();
	}
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
	pass DrawEdge {
		VertexShader = compile vs_3_0 ColorRender_VS();
		PixelShader  = compile ps_3_0 ColorRender_PS();
	}
}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {
	pass DrawShadow {
		VertexShader = compile vs_3_0 Shadow_VS();
		PixelShader  = compile ps_3_0 Shadow_PS();
	}
}

///////////////////////////////////////////////////////////////////////////////////////////////
