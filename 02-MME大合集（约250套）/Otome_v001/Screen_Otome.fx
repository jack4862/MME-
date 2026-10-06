////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Screen_Otome.fx ver0.0.1  乙女フィルターエフェクト･スクリーン固定版
//  作成: 針金P( 舞力介入P氏のlaughing_man.fx,FireParticleSystem.fx改変 )
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
int BallCount = 30;          // 水玉の描画オブジェクト数
float3 BallColor = {1.0, 1.0, 1.0}; // 水玉の乗算色(RBG)
float BallRandamColor = 0.9; // 水玉色のばらつき度(0.0～1.0)
float BallScale = 3.0;       // 水玉大きさ
float BallSpeed = 0.07;      // 水玉スピード
float BallAlpha = 0.5;       // 水玉Tr=1の時のα値

int LightCount = 50;         // 光粒子の描画オブジェクト数
float LightScale = 1.0;      // 光粒子大きさ
float LightSpeed = 0.03;     // 光粒子スピード
float LightAmp = 0.3;        // 光粒子瞬き振幅
float LightFreq = 2.0;       // 光粒子瞬き周波数
float LightRotSpeed = 0.2;   // 光粒子回転スピード
float LightCross = 3.0;      // 光粒子の十字度(大きくすると十字が鮮明になる)

int BallSeedXY = 9;          // 水玉配置に関する乱数シード
int BallSeedSize = 12;       // 水玉サイズに関する乱数シード
int BallSeedSpeed = 17;      // 水玉スピードに関する乱数シード
int BallSeedColor = 3;       // 水玉色に関する乱数シード
int LightSeedXY = 9;         // 光粒子配置に関する乱数シード
int LightSeedSize = 13;      // 光粒子サイズに関する乱数シード
int LightSeedSpeed = 17;     // 光粒子スピードに関する乱数シード
int LightSeedBlink = 13;     // 光粒子瞬きに関する乱数シード
int LightSeedCross = 19;     // 光粒子十字度合いに関する乱数シード


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

float Xmin = -1.5f;
float Xmax = 1.5f;
float Ymin = -1.1f;
float Ymax = 1.1f;

float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

int Index;

float time : Time;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

texture2D BallTex <
    string ResourceName = "ball.png";
>;
sampler BallSamp = sampler_state {
    texture = <BallTex>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

texture2D ParticleTex1 <
    string ResourceName = "Particle1.png";
>;
sampler ParticleSamp1 = sampler_state {
    texture = <ParticleTex1>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

texture2D ParticleTex2 <
    string ResourceName = "Particle2.png";
>;
sampler ParticleSamp2 = sampler_state {
    texture = <ParticleTex2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV  = CLAMP;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);


////////////////////////////////////////////////////////////////////////////////////////////////
// 座標の2D回転
float2 Rotation2D(float2 pos, float rot)
{
    float x = pos.x * cos(rot) - pos.y * sin(rot);
    float y = pos.x * sin(rot) + pos.y * cos(rot);

    return float2(x,y);
}


///////////////////////////////////////////////////////////////////////////////////////////////
// 水玉描画
struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
    float4 Color      : COLOR0;      // alpha値
};

// 頂点シェーダ
VS_OUTPUT Ball_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out;

    // 乱数定義
    float rand0 = abs(0.6f*sin(35 * BallSeedSize * Index + 13) + 0.4f*cos(73 * BallSeedSize * Index + 17));
    float rand1 = abs(0.4f*sin(51 * BallSeedSpeed * Index + 17) + 0.6f*cos(63 * BallSeedSpeed * Index + 19));
    float rand2 = abs(0.7f*sin(122 * BallSeedXY * Index + 19) + 0.3f*cos(237 * BallSeedXY * Index + 23));
    float rand3 = abs(0.6f*sin(81 * BallSeedXY * Index + 23) + 0.4f*cos(97 * BallSeedXY * Index + 29));
    float rand4r = abs(0.4f*sin(47 * BallSeedColor * Index + 29) + 0.6f*cos(83 * BallSeedColor * Index + 31));
    float rand4g = abs(0.7f*sin(48 * BallSeedColor * Index + 27) + 0.3f*cos(84 * BallSeedColor * Index + 30));
    float rand4b = abs(0.6f*sin(49 * BallSeedColor * Index + 26) + 0.4f*cos(85 * BallSeedColor * Index + 29));

    // 水玉サイズ
    float scale = (0.5f + rand0) * BallScale;
    Pos.x *= scale*ViewportSize.y/ViewportSize.x;
    Pos.y *= scale;

    // 水玉配置
    float speed = lerp(-BallSpeed, BallSpeed,rand1);
    float x = lerp(Xmin, Xmax, rand2);
    Pos.x += ((x+speed*time-Xmin)%(Xmax-Xmin)+Xmin+step(speed,0.0f)*(Xmax-Xmin));
    Pos.y +=lerp(Ymin, Ymax, rand3);
    Out.Pos = Pos;

    // 水玉の色
    float alpha = AcsTr * BallAlpha;
    float4 Color = float4(rand4r, rand4g, rand4b, 1.0f);
    Color = BallRandamColor * (Color - 1.0f) + 1.0f;
    Out.Color = saturate( float4(Color.xyz*BallColor, alpha) );

    // テクスチャ座標
    Out.Tex = Tex;

    return Out;
}

// ピクセルシェーダ
float4 Ball_PS( VS_OUTPUT IN ) : COLOR0
{
    float4 Color = tex2D( BallSamp, IN.Tex.xy );
    Color *= IN.Color;
    return Color;
}

// テクニック
technique MainTec0 < string MMDPass = "object"; string Subset = "0";
    string Script = "LoopByCount=BallCount;"
                    "LoopGetIndex=Index;"
                    "Pass=DrawObject;"
                    "LoopEnd=;"; >
{
    pass DrawObject {
        ZENABLE = false;
        VertexShader = compile vs_1_1 Ball_VS();
        PixelShader  = compile ps_2_0 Ball_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////
// パーティクル描画
struct VS_OUTPUT2
{
    float4 Pos        : POSITION;    // 射影変換座標
    float3 Tex        : TEXCOORD0;   // テクスチャ
    float4 Color      : COLOR0;      // alpha値
};

// 頂点シェーダ
VS_OUTPUT2 Particle_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT2 Out;

    // 乱数定義
    float rand0 = abs(0.5f*sin(35 * LightSeedSize * Index + 13) + 0.5f*cos(73 * LightSeedSize * Index + 17));
    float rand1 = abs(0.6f*sin(51 * LightSeedSpeed * Index + 17) + 0.4f*cos(63 * LightSeedSpeed * Index + 19));
    float rand2 = abs(0.4f*sin(122 * LightSeedXY * Index + 19) + 0.6f*cos(237 * LightSeedXY * Index + 23));
    float rand3 = abs(0.7f*sin(81 * LightSeedXY * Index + 23) + 0.3f*cos(97 * LightSeedXY * Index + 29));
    float rand4 = 0.5f*sin(53 * LightSeedBlink * Index + 17) + 0.5f*cos(61 * LightSeedBlink * Index + 19);
    float rand5 = (sin(47 * LightSeedCross * Index + 29) + cos(83 * LightSeedCross * Index + 31) + 3.0f) * 0.1f;

    // パーティクル回転
    Pos.xy = Rotation2D(Pos.xy, time*LightRotSpeed);

    // パーティクルサイズ
    float scale = (0.5f + rand0)*LightScale + LightAmp*sin(LightFreq*time+rand4*6.28f);
    Pos.x *= scale*ViewportSize.y/ViewportSize.x;
    Pos.y *= scale;

    // パーティクル配置
    float speed = lerp(-LightSpeed, LightSpeed, rand1);
    float x = lerp(Xmin, Xmax, rand2);
    Pos.x += (x+speed*time-Xmin)%(Xmax-Xmin)+Xmin+step(speed,0.0f)*(Xmax-Xmin);
    Pos.y += lerp(Ymin, Ymax, rand3);
    Out.Pos = Pos;

    // パーティクルの透過度
    Out.Color = float4(AcsTr, AcsTr, AcsTr, 1.0f);

    // テクスチャ座標
    Out.Tex = float3(Tex, 1.0f+LightCross*rand5);

    return Out;
}

// ピクセルシェーダ
float4 Particle_PS( VS_OUTPUT2 IN ) : COLOR0
{
    float4 Color = tex2D( ParticleSamp2, IN.Tex.xy );
    float2 Tex1 = (IN.Tex.xy-0.5f)*IN.Tex.z+0.5f;
    float4 Color1 = tex2D( ParticleSamp1, Tex1 );
    Color += Color1;
    Color.xyz *= IN.Color.xyz*0.5f;
    return Color;
}

// テクニック
technique MainTec1 < string MMDPass = "object"; string Subset = "1-";
    string Script = "LoopByCount=LightCount;"
                    "LoopGetIndex=Index;"
                    "Pass=DrawObject;"
                    "LoopEnd=;"; >
{
    pass DrawObject {
        ZENABLE = false;
        AlphaBlendEnable = TRUE;
        SrcBlend = ONE;
        DestBlend = ONE;
        VertexShader = compile vs_1_1 Particle_VS();
        PixelShader  = compile ps_2_0 Particle_PS();
    }
}

