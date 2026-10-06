////////////////////////////////////////////////////////////////////////////////////////////////
//
//  MangaLines_Parallel.fx ver0.0.1  漫画･アニメの効果線エフェクト(平行線)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
int LineCount = 150;   // 効果線の本数
float LineThick = 0.7; // 効果線の基準太さ
float LineAlpha = 0.7; // 効果線の最大透過値
float PosParam = 0.65; // より分けパラメータ(0で均等,1に近づくほど外側により分けられる)
float3 LineColor = {0.0, 0.0, 0.0}; // 効果線色(RBG)

int SeedThick = 5;    // 太さに関する乱数シード
int SeedPos = 7;      // 配置に関する乱数シード
int SeedAnime = 15;   // アニメーションに関する乱数シード


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#define PAI 3.14159265f   // π

float AcsX  : CONTROLOBJECT < string name = "(self)"; string item = "X"; >;
float AcsY  : CONTROLOBJECT < string name = "(self)"; string item = "Y"; >;
float AcsZ  : CONTROLOBJECT < string name = "(self)"; string item = "Z"; >;
float AcsRz : CONTROLOBJECT < string name = "(self)"; string item = "Rz"; >;
float AcsRy : CONTROLOBJECT < string name = "(self)"; string item = "Ry"; >;
float AcsSi : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

float time : Time;

int Index;

// スクリーンサイズ
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5,0.5)/ViewportSize);

static float R = length( float2( ViewportSize.x/ViewportSize.y, 1.0f) );

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


///////////////////////////////////////////////////////////////////////////////////////
// 効果線描画
struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 VPos       : TEXCOORD0;   // ローカル･アニメーション座標
};

// 頂点シェーダ
VS_OUTPUT Line_VS(float4 Pos : POSITION)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    // 乱数定義
    float rand1 = abs(sin(24 * SeedThick * Index + 13) + cos(235 * SeedThick * Index + 17)) * 0.6f;
    float rand2 = abs(0.7*sin(83 * SeedPos * Index + 9) + 0.3*cos(91 * SeedPos * Index + 11));
    float rand3 = abs(sin(47 * SeedAnime * Index + 17) + cos(186 * SeedAnime * Index + 11)) * 0.5f;

    // ローカル･アニメーション座標
    Out.VPos.x = Pos.x;
    Out.VPos.y = sign(AcsSi)*2.0f*R+AcsZ
                - fmod(lerp(0.0f, 2.0f*(R+AcsZ), rand3)+time*AcsSi, 2.0f*(R+AcsZ));

    // 線の太さ
    Pos.y *= max((LineThick+AcsRy*180.0f/PAI)*(0.5+rand1)*(1.0f+Pos.x)*0.1f, 0.1f);

    // 平行線配置
    float2 Pos0 = float2(-R, lerp(-R, R, rand2));
    Pos0.y = sign(Pos0.y)*R*pow(abs(Pos0.y/R), max(1.0f-PosParam, 0.0f));
    Pos.xy += Pos0;

    // 座標回転
    Pos.xy = Rotation2D(Pos.xy, AcsRz);

    // 配置移動
    Pos.x += AcsX*ViewportSize.x/ViewportSize.y;
    Pos.y += AcsY;

    // スクリーン座標に変換
    Pos.x *= ViewportSize.y/ViewportSize.x;
    Out.Pos = Pos;

    return Out;
}

// ピクセルシェーダ
float4 Line_PS( VS_OUTPUT IN ) : COLOR0
{
    // 透過値設定
    float alpha1 = smoothstep((1.0f-AcsTr)*(1.0f+R), 1.0f+(1.0f-AcsTr)*5.0f, IN.VPos.x)*AcsTr;
    float alpha2 = smoothstep(-AcsZ, 0.0f, -abs(IN.VPos.x-IN.VPos.y));
    if( AcsZ < 0.0001f ) alpha2 = 1.0f;

    // 効果線の色
    float4 Color = float4( LineColor, alpha1*alpha2*LineAlpha );

    return Color;
}


///////////////////////////////////////////////////////////////////////////////////////
// テクニック

technique MainTec1 < string MMDPass = "object";
    string Script = "LoopByCount=LineCount;"
                    "LoopGetIndex=Index;"
                    "Pass=DrawObject;"
                    "LoopEnd=;"; >
{
    pass DrawObject {
        ZENABLE = false;
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_1_1 Line_VS();
        PixelShader  = compile ps_2_0 Line_PS();
    }
}

