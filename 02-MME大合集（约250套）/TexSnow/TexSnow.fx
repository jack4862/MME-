////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

int index = 0; //ループ用変数
int count
<
   string UIName = "count";
   string UIWidget = "Numeric";
   int UIMin = 1;
   int UIMax = 2000;
> = 1000;


float Height
<
   string UIName = "Height";
   string UIWidget = "Numeric";
   int UIMin = 1;
   int UIMax = 2000;
> = 80;

float WidthX
<
   string UIName = "WidthX";
   string UIWidget = "Numeric";
   int UIMin = 1;
   int UIMax = 2000;
> = 100;

float WidthZ
<
   string UIName = "WidthZ";
   string UIWidget = "Numeric";
   int UIMin = 1;
   int UIMax = 2000;
> = 100;



float Speed
<
   string UIName = "Speed";
   string UIWidget = "Slider";
   float UIMin = 0.0;
   float UIMax = 40.0;
> = 10;

float ParticleSize
<
   string UIName = "ParticleSize";
   string UIWidget = "Slider";
   float UIMin = 0.0;
   float UIMax = 3.0;
> = 0.8;

float SlopeLevel
<
   string UIName = "SlopeLevel";
   string UIWidget = "Slider";
   float UIMin = 0.0;
   float UIMax = 2.0;
> = 0.3;

float NoizeLevel
<
   string UIName = "NoizeLevel";
   string UIWidget = "Slider";
   float UIMin = 0.0;
   float UIMax = 2.0;
> = 0.4;

float RotationSpeed
<
   string UIName = "RotationSpeed";
   string UIWidget = "Slider";
   float UIMin = 0.0;
   float UIMax = 20.0;
> = 3;

float FadeLength
<
   string UIName = "FadeLength";
   string UIWidget = "Slider";
   float UIMin = 0.0;
   float UIMax = 1000.0;
> = 200;



//パーティクルテクスチャ
texture2D Tex1 <
    string ResourceName = "snow1.png";
>;
sampler Tex1Samp = sampler_state {
    texture = <Tex1>;
};

//乱数テクスチャ
texture2D rndtex <
    string ResourceName = "random2048.bmp";
>;
sampler rnd = sampler_state {
    texture = <rndtex>;
};

//乱数テクスチャ幅
#define RNDTEX_WIDTH 2048


float4 MaterialDiffuse : DIFFUSE  < string Object = "Geometry"; >;
static float alpha1 = MaterialDiffuse.a;

float ftime : TIME <bool SyncInEditMode = false;>;


// 座法変換行列
float4x4 WorldViewProjMatrix    : WORLDVIEWPROJECTION;
float4x4 WorldViewMatrixInverse : WORLDVIEWINVERSE;

static float3x3 BillboardMatrix = {
    normalize(WorldViewMatrixInverse[0].xyz),
    normalize(WorldViewMatrixInverse[1].xyz),
    normalize(WorldViewMatrixInverse[2].xyz),
};

//回転行列
static float rot = ftime * RotationSpeed + index * 6;
static float3x3 Rotation = {
    {cos(rot), sin(rot), 0},
    {-sin(rot), cos(rot), 0},
    {0, 0, 1},
};

///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
    float  Alpha      : COLOR0;
};

// 頂点シェーダ
VS_OUTPUT Mask_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out;
    Out.Alpha = 1;
    
    //回転・サイズ変更
    Pos.xyz = mul( Pos.xyz, Rotation );
    Pos.xy *= ParticleSize;
    
    // ビルボード
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
    
    // ランダム配置
    float2 base_tex_coord = float2((index+0.5)/RNDTEX_WIDTH, 0.5);
    float4 base_pos = tex2Dlod(rnd, float4(base_tex_coord,0,1));
    
    base_pos.xz -= 0.5;
    base_pos.y = frac(base_pos.y - (Speed * ftime / Height));
    
    //出現後と消滅直前はフェード
    Out.Alpha = saturate((1 - base_pos.y) * 3) * saturate(base_pos.y * 40);
    
    //領域変更
    base_pos.xyz *= float3(WidthX, Height, WidthZ);
    base_pos.xyz *= 0.1;
    
    //斜め
    base_pos.x += base_pos.y * SlopeLevel;
    
    //ノイズ付加
    base_pos.xz += noise(float2(ftime * 0.2, index * 5)) * NoizeLevel;
    
    Pos.xyz += base_pos;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    //遠方は薄く
    Out.Alpha *= 0.3 + 0.7 * (1 - saturate((Out.Pos.z - 50) / FadeLength));
    Out.Alpha *= alpha1;
    
    // テクスチャ座標
    Out.Tex = Tex;
    
    return Out;
}

// ピクセルシェーダ
float4 Mask_PS( VS_OUTPUT input ) : COLOR0
{
    float4 color = tex2D( Tex1Samp, input.Tex );
    color.a *= input.Alpha;
    return color;
}

///////////////////////////////////////////////////////////////////////////////////////////////

technique MainTec < 
    string MMDPass = "object";
    string Script = 
        "LoopByCount=count;"
        "LoopGetIndex=index;"
        "Pass=DrawObject;"
        "LoopEnd=;"
    ;
> {
    pass DrawObject {
        ZWRITEENABLE = false;
        //ここのコメントアウトを外せば加算合成に
        //SRCBLEND=ONE;
        //DESTBLEND=ONE;
        VertexShader = compile vs_3_0 Mask_VS();
        PixelShader  = compile ps_3_0 Mask_PS();
    }
}

