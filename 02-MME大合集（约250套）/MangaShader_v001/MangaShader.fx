////////////////////////////////////////////////////////////////////////////////////////////////
//
//  MangaShader.fx ver0.0.1  モデルの漫画風描画を行います
//  作成: 針金P( 舞力介入P氏のfull.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
#define TexFile1  "ScreenToon1.png"  // 濃いスクリーントーンテクスチャファイル名1
#define TexFile2  "ScreenToon2.png"  // 薄いスクリーントーンテクスチャファイル名2
float ToonLevel1 = 0.4;         // 黒とトーンの境値(0～1)
float ToonLevel2 = 0.8;         // トーンと白の境値(0～1)
float ToonScaling1 = 0.014;     // 濃いトーンのスケーリング
float ToonScaling2 = 0.012;     // 薄いトーンのスケーリング
float ToonScalingShadow = 0.01; // 地面影トーンのスケーリング
float Toon2Alpha = 1.0;         // 薄いトーンの濃度(顔の影が髭に見える場合はここを下げる)
float EdgeThick = 1.0;          // 独自描画のエッジ太さ


// 解らない人はここから下はいじらないでね
////////////////////////////////////////////////////////////////////////////////////////////////

// 座標変換行列
float4x4 WorldViewProjMatrix  : WORLDVIEWPROJECTION;
float4x4 WorldMatrix          : WORLD;
float4x4 ViewMatrix           : VIEW;
float4x4 ProjMatrix           : PROJECTION;
float4x4 ViewProjMatrix       : VIEWPROJECTION;

float3 LightDirection  : DIRECTION < string Object = "Light"; >;
float3 CameraPosition  : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4 MaterialDiffuse  : DIFFUSE  < string Object = "Geometry"; >;
float3 MaterialAmbient  : AMBIENT  < string Object = "Geometry"; >;
float3 MaterialEmmisive : EMISSIVE < string Object = "Geometry"; >;
static float4 DiffuseColor = MaterialDiffuse;
static float3 AmbientColor = saturate(MaterialAmbient + MaterialEmmisive);

bool spadd;    // スフィアマップ加算合成フラグ

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// スフィアマップのテクスチャ
texture ObjectSphereMap: MATERIALSPHEREMAP;
sampler ObjSphareSampler = sampler_state {
    texture = <ObjectSphereMap>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

// スクリーントーンテクスチャ1
texture2D screen_tex1 <
    string ResourceName = TexFile1;
    int MipLevels = 0;
>;
sampler TexSampler1 = sampler_state {
    texture = <screen_tex1>;
    MinFilter = ANISOTROPIC;
    MagFilter = ANISOTROPIC;
    MipFilter = LINEAR;
    MaxAnisotropy = 5;
    AddressU  = WRAP;
    AddressV = WRAP;
};

// スクリーントーンテクスチャ1
texture2D screen_tex2 <
    string ResourceName = TexFile2;
    int MipLevels = 0;
>;
sampler TexSampler2 = sampler_state {
    texture = <screen_tex2>;
    MinFilter = ANISOTROPIC;
    MagFilter = ANISOTROPIC;
    MipFilter = LINEAR;
    MaxAnisotropy = 5;
    AddressU  = WRAP;
    AddressV = WRAP;
};


// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

////////////////////////////////////////////////////////////////////////////////////////////////
// スクリーントーンの貼り付け
float3 SetToonColor1(float4 VPos)
{
    // スクリーンの座標
    VPos.x = ( VPos.x/VPos.w + 1.0f ) * 0.5f;
    VPos.y = 1.0f - (VPos.y/VPos.w + 1.0f ) * 0.5f;

    // 貼り付けるテクスチャの色
    float2 texCoord = float2( VPos.x*ViewportSize.x/ViewportSize.y/ToonScaling1, VPos.y/ToonScaling1 );
    float3 Color = tex2D( TexSampler1, texCoord ).rgb;

    return Color;
}

float3 SetToonColor2(float4 VPos)
{
    // スクリーンの座標
    VPos.x = ( VPos.x/VPos.w + 1.0f ) * 0.5f;
    VPos.y = 1.0f - (VPos.y/VPos.w + 1.0f ) * 0.5f;

    // 貼り付けるテクスチャの色
    float2 texCoord = float2( VPos.x*ViewportSize.x/ViewportSize.y/ToonScaling2, VPos.y/ToonScaling2 );
    float4 Color = lerp( float4(1.0f, 1.0f, 1.0f, 1.0f), tex2D( TexSampler2, texCoord ), Toon2Alpha );

    return Color.rgb;
}

float4 SetToonColor3(float4 VPos)
{
    // スクリーンの座標
    VPos.x = ( VPos.x/VPos.w + 1.0f ) * 0.5f;
    VPos.y = 1.0f - (VPos.y/VPos.w + 1.0f ) * 0.5f;

    // 貼り付けるテクスチャの色
    float2 texCoord = float2( VPos.x*ViewportSize.x/ViewportSize.y/ToonScalingShadow, VPos.y/ToonScalingShadow );
    float4 c = tex2D( TexSampler1, texCoord );
    float alpha = 1.0f - (c.r + c.g + c.b) * 0.33333f;

    return float4(0.0f, 0.0f, 0.0f, alpha);
}

////////////////////////////////////////////////////////////////////////////////////////////////
struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD1;   // テクスチャ
    float3 Normal     : TEXCOORD2;   // 法線
    float2 SpTex      : TEXCOORD3;   // スフィアマップテクスチャ座標
    float4 VPos       : TEXCOORD4;   // スクリーン座標取得用射影変換座標
    float4 Color      : COLOR0;      // ディフューズ色
};


////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画(独自描画,エッジOFF材質・アクセサリにもエッジを付ける)

// 頂点シェーダ
VS_OUTPUT Edge_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useToon)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // 素材モデルのワールド座標変換
    Pos = mul( Pos, WorldMatrix );

    // ワールド座標変換による頂点法線
    Out.Normal = normalize( mul( Normal, (float3x3)WorldMatrix ) );

    // カメラとの距離
    float len = max( length( CameraPosition - Pos ), 5.0f );

    // 頂点を法線方向に押し出す
    Pos.xyz += Out.Normal * ( pow( len, 0.9f ) * EdgeThick * 0.0025f * pow(2.4142f / ProjMatrix._22, 0.7f) );

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, ViewProjMatrix );

    // 半透明にエッジを付けないためにオブジェクト色も求めておく
    // ディフューズ色＋アンビエント色 計算
    Out.Color.rgb = AmbientColor;
    if ( !useToon ) {
        Out.Color.rgb += max(0,dot( Out.Normal, -LightDirection )) * DiffuseColor.rgb;
    }
    Out.Color.a = DiffuseColor.a;
    Out.Color = saturate( Out.Color );

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 Edge_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useToon) : COLOR0
{
    float4 Color = IN.Color;
    if ( useTexture ) {
        // テクスチャ適用
        Color *= tex2D( ObjTexSampler, IN.Tex );
    }
    // 半透明にはエッジを付けない
    float alpha = Color.a;
    alpha = step( 0.98f, alpha );

    // 輪郭色で塗りつぶし
    return float4(0.0f ,0.0f ,0.0f, alpha);
}

// 輪郭描画用テクニック
technique EdgeTec < string MMDPass = "edge"; > {
    pass DrawEdge{
       // MMD標準のエッジ描画
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画

// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0, uniform bool useTexture, uniform bool useSphereMap, uniform bool useToon)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );

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
        // スフィアマップテクスチャ座標
        float2 NormalWV = mul( Out.Normal, (float3x3)ViewMatrix );
        Out.SpTex.x = NormalWV.x * 0.5f + 0.5f;
        Out.SpTex.y = NormalWV.y * -0.5f + 0.5f;
    }

    // スクリーン座標取得用
    Out.VPos = Out.Pos;

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
        if(spadd) Color.rgb += tex2D(ObjSphareSampler,IN.SpTex).rgb;
        else      Color.rgb *= tex2D(ObjSphareSampler,IN.SpTex).rgb;
    }

    // モノクロに変換
    float v = (Color.r + Color.g + Color.b) * 0.3333f;
    Color.rgb = float3(v, v, v);

    // 明度で黒,白,スクリーントーンに分ける
    if(v < ToonLevel1){
       Color.rgb = float3(0.0f, 0.0f, 0.0f);
    }else if(v < ToonLevel2){
       // スクリーントーン色
       if( useToon ) {
           Color.rgb = float3(1.0f, 1.0f, 1.0f);
           float LightNormal = dot( IN.Normal, -LightDirection );
           if(saturate(LightNormal * 16 + 0.5) < 0.5f){
               Color.rgb = float3(0.8f, 0.8f, 0.8f);
           }
       }
       Color.rgb *= SetToonColor1(IN.VPos);
    }else{
       // 白はトーンシェードで白,薄スクリーントーンに分ける
       Color.rgb = float3(1.0f, 1.0f, 1.0f);
       if( useToon ) {
           float LightNormal = dot( IN.Normal, -LightDirection );
           if(saturate(LightNormal * 16 + 0.5) < 0.5f){
               Color.rgb = SetToonColor2(IN.VPos);
           }
       }
    }

    return Color;
}


///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画用テクニック（アクセサリ用）
technique MainTec01 < string MMDPass = "object"; bool UseTexture = false; bool useSphereMap = false; bool UseToon = false; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, false, false);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS(false, false);
        PixelShader  = compile ps_2_0 Edge_PS(false, false);
    }
}

technique MainTec02 < string MMDPass = "object"; bool UseTexture = false; bool useSphereMap = true; bool UseToon = false; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, true, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, true, false);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS(false, false);
        PixelShader  = compile ps_2_0 Edge_PS(false, false);
    }
}

technique MainTec03 < string MMDPass = "object"; bool UseTexture = true; bool useSphereMap = false; bool UseToon = false; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, false, false);
        PixelShader  = compile ps_2_0 Basic_PS(true, false, false);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS(true, false);
        PixelShader  = compile ps_2_0 Edge_PS(true, false);
    }
}

technique MainTec04 < string MMDPass = "object"; bool UseTexture = true; bool useSphereMap = true; bool UseToon = false; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, true, false);
        PixelShader  = compile ps_2_0 Basic_PS(true, true, false);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS(true, false);
        PixelShader  = compile ps_2_0 Edge_PS(true, false);
    }
}

technique MainTec05 < string MMDPass = "object_ss"; bool UseTexture = false; bool useSphereMap = false; bool UseToon = false; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, false, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, false, false);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS(false, false);
        PixelShader  = compile ps_2_0 Edge_PS(false, false);
    }
}

technique MainTec06 < string MMDPass = "object_ss"; bool UseTexture = false; bool useSphereMap = true; bool UseToon = false; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, true, false);
        PixelShader  = compile ps_2_0 Basic_PS(false, true, false);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS(false, false);
        PixelShader  = compile ps_2_0 Edge_PS(false, false);
    }
}

technique MainTec07 < string MMDPass = "object_ss"; bool UseTexture = true; bool useSphereMap = false; bool UseToon = false; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, false, false);
        PixelShader  = compile ps_2_0 Basic_PS(true, false, false);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS(true, false);
        PixelShader  = compile ps_2_0 Edge_PS(true, false);
    }
}

technique MainTec08 < string MMDPass = "object_ss"; bool UseTexture = true; bool useSphereMap = true; bool UseToon = false; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, true, false);
        PixelShader  = compile ps_2_0 Basic_PS(true, true, false);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS(true, false);
        PixelShader  = compile ps_2_0 Edge_PS(true, false);
    }
}

// オブジェクト描画用テクニック（PMDモデル用）
technique MainTec09 < string MMDPass = "object"; bool UseTexture = false; bool useSphereMap = false; bool UseToon = true; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, false, true);
        PixelShader  = compile ps_2_0 Basic_PS(false, false, true);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS(false, true);
        PixelShader  = compile ps_2_0 Edge_PS(false, true);
    }
}

technique MainTec10 < string MMDPass = "object"; bool UseTexture = false; bool useSphereMap = true; bool UseToon = true; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, true, true);
        PixelShader  = compile ps_2_0 Basic_PS(false, true, true);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS(false, true);
        PixelShader  = compile ps_2_0 Edge_PS(false, true);
    }
}

technique MainTec11 < string MMDPass = "object"; bool UseTexture = true; bool useSphereMap = false; bool UseToon = true; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, false, true);
        PixelShader  = compile ps_2_0 Basic_PS(true, false, true);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS(true, true);
        PixelShader  = compile ps_2_0 Edge_PS(true, true);
    }
}

technique MainTec12 < string MMDPass = "object"; bool UseTexture = true; bool useSphereMap = true; bool UseToon = true; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, true, true);
        PixelShader  = compile ps_2_0 Basic_PS(true, true, true);
    }
    pass DrawEdge {
        CullMode = CW;
        VertexShader = compile vs_2_0 Edge_VS(true, true);
        PixelShader  = compile ps_2_0 Edge_PS(true, true);
    }
}

technique MainTec13 < string MMDPass = "object_ss"; bool UseTexture = false; bool useSphereMap = false; bool UseToon = true; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, false, true);
        PixelShader  = compile ps_2_0 Basic_PS(false, false, true);
    }
}

technique MainTec14 < string MMDPass = "object_ss"; bool UseTexture = false; bool useSphereMap = true; bool UseToon = true; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(false, true, true);
        PixelShader  = compile ps_2_0 Basic_PS(false, true, true);
    }
}

technique MainTec15 < string MMDPass = "object_ss"; bool UseTexture = true; bool useSphereMap = false; bool UseToon = true; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, false, true);
        PixelShader  = compile ps_2_0 Basic_PS(true, false, true);
    }
}

technique MainTec16 < string MMDPass = "object_ss"; bool UseTexture = true; bool useSphereMap = true; bool UseToon = true; >
{
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS(true, true, true);
        PixelShader  = compile ps_2_0 Basic_PS(true, true, true);
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////
// 影（非セルフシャドウ）描画

struct VS_OUTPUT2 {
    float4 Pos   : POSITION;    // 射影変換座標
    float4 VPos  : TEXCOORD4;   // スクリーン座標取得用射影変換座標
};

// 頂点シェーダ
VS_OUTPUT2 Shadow_VS(float4 Pos : POSITION)
{
    VS_OUTPUT2 Out = (VS_OUTPUT2)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );

    // スクリーン座標取得用
    Out.VPos = Out.Pos;

    return Out;
}

// ピクセルシェーダ
float4 Shadow_PS(VS_OUTPUT2 IN) : COLOR
{
    float4 Color = SetToonColor3(IN.VPos);
    return Color;
}

// 影描画用テクニック
technique ShadowTec < string MMDPass = "shadow"; > {
    pass DrawShadow {
        VertexShader = compile vs_2_0 Shadow_VS();
        PixelShader  = compile ps_2_0 Shadow_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////

// Z値プロット用テクニック
technique ZplotTec < string MMDPass = "zplot"; > { }


///////////////////////////////////////////////////////////////////////////////////////////////
