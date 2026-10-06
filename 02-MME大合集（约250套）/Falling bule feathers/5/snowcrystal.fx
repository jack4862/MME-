////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

//粒子表示数
static const int MaxParticle
<
   string UIName = "粒子表示数";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 1000;
> = int( 50 );

//表示領域
float Height
<
   string UIName = "表示高さ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 2000;
> = float( 50 );

float WidthX
<
   string UIName = "X幅";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 2000;
> = float( 50 );

float WidthZ
<
   string UIName = "Z幅";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   int UIMin = 1;
   int UIMax = 2000;
> = float( 50 );

float RotateX
<
   string UIName = "X回転率";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   int UIMin = 0;
   int UIMax = 1;
> = float( 0 );

float RotateY
<
   string UIName = "Y回転率";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   int UIMin = 0;
   int UIMax = 1;
> = float( 0 );

float RotateZ
<
   string UIName = "Z回転率";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   int UIMin = 0;
   int UIMax = 1;
> = float( 0 );

//落下速度
float Speed
<
   string UIName = "落下速度";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 40.0;
> = float( 6 );

//パーティクルサイズ
float ParticleSize
<
   string UIName = "パーティクルサイズ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 5.0;
> = float( 0.5 );

float ParticleAlpha
<
   string UIName = "パーティクルアルファ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float( 0.21 );

int BillBoard
<
   string UIName = "ビルボード";
   string UIWidget = "Selector";
   string UISelector = "無効,有効";
   bool UIVisible =  true;
> = int( 1 );

//落下軌道の傾き
float SlopeLevel
<
   string UIName = "落下軌道の傾き";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 2.0;
> = float( 0.1 );

//落下軌道のゆらぎ
float NoizeLevel
<
   string UIName = "落下軌道のゆらぎ";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 2.0;
> = float( 0.4 );

//テクスチャの回転速度
float RotationSpeed
<
   string UIName = "回転速度";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 20.0;
> = float( 1 );

//遠方でフェードアウトする距離
float FadeLength
<
   string UIName = "フェードアウトする距離";
   string UIWidget = "Slider";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1000.0;
> = float( 200 );

float4 snowColor
<
   string UIName = "乗算する色";
   string UIWidget = "Color";
> = float4( 0.2196078 , 0.4980392 , 0.6078432 , 1 );


// パラメータ宣言

// 座法変換行列
float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;
float4x4 WorldMatrix              : WORLD;
float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

float3   LightDirection    : DIRECTION < string Object = "Light"; >;
float3   CameraPosition    : POSITION  < string Object = "Camera"; >;

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;
float3   MaterialToon      : TOONCOLOR;
// ライト色
float3   LightDiffuse      : DIFFUSE   < string Object = "Light"; >;
float3   LightAmbient      : AMBIENT   < string Object = "Light"; >;
float3   LightSpecular     : SPECULAR  < string Object = "Light"; >;
static float4 DiffuseColor  = MaterialDiffuse  * float4(LightDiffuse, 1.0f);
static float3 AmbientColor  = saturate(MaterialAmbient  * LightAmbient + MaterialEmmisive);
static float3 SpecularColor = MaterialSpecular * LightSpecular;

// テクスチャ
texture Tex : TEXTURE <
    string ResourceName = "snowcrystal.png";
>;

sampler texSamp = sampler_state
{
    texture = <Tex>;
    MINFILTER = LINEAR;
    MAGFILTER = LINEAR;
};

static float alpha1 = MaterialDiffuse.a;

float ftime : TIME <bool SyncInEditMode = false;>;


// 座法変換行列
float4x4 WorldViewMatrixInverse : WORLDVIEWINVERSE;

static float3x3 BillboardMatrix = {
    normalize(WorldViewMatrixInverse[0].xyz),
    normalize(WorldViewMatrixInverse[1].xyz),
    normalize(WorldViewMatrixInverse[2].xyz),
};

// 原点を中心としてベクトルuの周りをrad度回転
float3 rotate(float3 pos, float3 u, float3 rad)
{
    float s = sin(rad);
    float c = cos(rad);
    float4x4 mat = {
        u.x*u.x*(1-c)+c, u.x*u.y*(1-c)-u.z*s, u.z*u.x*(1-c)+u.y*s,0,
        u.x*u.y*(1-c)+u.z*s, u.y*u.y*(1-c)+c, u.y*u.z*(1-c)-u.x*s,0,
        u.z*u.x*(1-c)-u.y*s, u.y*u.z*(1-c)+u.x*s, u.z*u.z*(1-c)+c,0,
        0,0,0,1
        };
    return mul(float4(pos,1), mat).xyz;
}

///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
    float4 Color      : COLOR0;      // ディフューズ色
    float  Alpha      : COLOR1;
};

// 頂点シェーダ
VS_OUTPUT Mask_VS(float4 Pos : POSITION, float3 Normal : NORMAL, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out;
    Out.Alpha = 1;
    
    //ポリゴンのZ座標をインデックスとして利用
    float pindex = round(Pos.z);
    float t = (Speed * ftime / Height);
    Pos.z = 0;

    // ランダム配置
    float4 base_pos = float4(0,0,0,1);
    base_pos.y = cos(pindex * 17);
    float index = pindex + trunc(base_pos.y - t) * 500;
    index = sin(index) + cos(index);
    float index2 = sin(index*13);
    float a = sin(index * 173);
    float b = index * 11 * 67;
    base_pos.x = a * sin(b);
    base_pos.z = a * cos(b);
    
    base_pos.y = frac(base_pos.y - t);
    
    //出現後と消滅直前はフェード
    Out.Alpha = saturate(sin(base_pos.y * 3.14152965)* 2);

    float rot = ftime * RotationSpeed + index2 * 6;
    float3x3 Rotation = {
        {cos(rot), sin(rot), 0},
        {-sin(rot), cos(rot), 0},
        {0, 0, 1},
    };
    //回転・サイズ変更
    Pos.xyz = mul( Pos.xyz, Rotation );
    Pos.xy *= ParticleSize;
    
    float3 unit_pos = float3(0,0,0);
    unit_pos.x = sin(index * 133) * RotateX;
    unit_pos.y = cos(index * 171) * RotateY;
    unit_pos.z = cos(index * 197) * RotateZ;
    float rot2 = index * .823974;
    Pos.xyz = rotate(Pos.xyz, normalize(unit_pos), rot2);
    
    // ビルボード
    if (BillBoard)
        Pos.xyz = mul( Pos.xyz, BillboardMatrix );

    //領域変更
    base_pos.xyz *= float3(WidthX, Height, WidthZ);
    base_pos.xyz *= 0.1;
    
    //斜め
    base_pos.x += base_pos.y * SlopeLevel;
    
    //ノイズ付加
    base_pos.xz += (sin(ftime * 0.2 + index2) + cos(ftime * 0.5 + index2) * 0.5)  * NoizeLevel;
    
    Pos.xyz += base_pos;
    
    //表示上限より上のパーティクルは彼方へスッ飛ばす
    if (pindex >= MaxParticle)
        Pos.z += 100000000;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    //遠方は薄く
    Out.Alpha *= 0.3 + 0.7 * (1 - saturate((Out.Pos.z - 50) / FadeLength));
    Out.Alpha *= alpha1;
    
    // テクスチャ座標
    Out.Tex = Tex;

    Out.Color = 1;
    
    return Out;
}

// ピクセルシェーダ
float4 Mask_PS( VS_OUTPUT IN ) : COLOR0
{
    float4 Color = tex2D(texSamp, IN.Tex);
    Color *= snowColor;
    Color *= IN.Alpha;

    return Color;
}

///////////////////////////////////////////////////////////////////////////////////////////////

technique MainTec {
    pass DrawObject {
        ZENABLE = TRUE;
        ZWRITEENABLE = FALSE;
        CULLMODE = NONE;
        ALPHABLENDENABLE = TRUE;
        SRCBLEND = ONE;
        DESTBLEND = ONE;

        VertexShader = compile vs_2_0 Mask_VS();
        PixelShader  = compile ps_2_0 Mask_PS();
    }
}

