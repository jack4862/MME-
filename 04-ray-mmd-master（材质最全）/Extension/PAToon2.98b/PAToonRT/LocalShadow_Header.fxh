////////////////////////////////////////////////////////////////////////////////////////////////
//
//  LocalShadow_Header.fxh : LocalShadow シャドウマップ作成に必要な基本パラメータ定義ヘッダファイル
//  ここのパラメータを他のエフェクトファイルで #include して使用します。
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
// ※ファイル更新後に｢MMEffect｣→｢全て更新｣で参照しているエフェクトファイルを更新する必要があります

// シャドウマップバッファサイズ
#define LS_ShadowMapBuffSize  2048

// VSMシャドウマップの実装
#define LS_UseSoftShadow  1
// 0 : 実装しない(ソフトシャドウは使えないけど描画速度は向上する)
// 1 : 実装する(ソフトシャドウが使えるようになります)


// 解らない人はここから下はいじらないでね

////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

#ifndef LOCALSHADOW_MAIN

// コントロールパラメータ
#define PATOONCONTROLLER   "PAToonRTコントローラー.pmx"

bool LocalShadow_Valid          : CONTROLOBJECT < string name = PATOONCONTROLLER; >;
float3   LocalShadow_BonePosC     : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "セルフ影"; >;
float4x4 LocalShadow_BoneMatrixC  : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "セルフ影"; >;

float    LocalShadow_MorphLtSyncC : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "Lt陰影連動"; >;

float LocalShadow_MorphSize1C    : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "範囲縮小"; >;
float LocalShadow_MorphSize2C    : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "範囲拡大"; >;
float LocalShadow_MorphSize2XC   : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "X範囲拡大"; >;
float LocalShadow_MorphSize2YC   : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "Y範囲拡大"; >;


float LocalShadow_MorphDist1C    : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "距離近"; >;
float LocalShadow_MorphDist2C    : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "距離遠"; >;

float LocalShadow_MorphLtCtrlC   : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "Lt影濃調整"; >;

float LocalShadow_MorphLtSync2  : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "Lt遮影連動"; >;

// モデル埋め込みパラメータ
float3   LocalShadow_BonePosM     : CONTROLOBJECT < string name = "(self)"; string item = "セルフ影"; >;
float4x4 LocalShadow_BoneMatrixM  : CONTROLOBJECT < string name = "(self)"; string item = "セルフ影"; >;
float    LocalShadow_MorphLtSyncM : CONTROLOBJECT < string name = "(self)"; string item = "Lt陰影連動"; >;

float LocalShadow_MorphSize1M    : CONTROLOBJECT < string name = "(self)"; string item = "範囲縮小"; >;
float LocalShadow_MorphSize2M    : CONTROLOBJECT < string name = "(self)"; string item = "範囲拡大"; >;
float LocalShadow_MorphSize2XM   : CONTROLOBJECT < string name = "(self)"; string item = "X範囲拡大"; >;
float LocalShadow_MorphSize2YM   : CONTROLOBJECT < string name = "(self)"; string item = "Y範囲拡大"; >;


float LocalShadow_MorphDist1M    : CONTROLOBJECT < string name = "(self)"; string item = "距離近"; >;
float LocalShadow_MorphDist2M    : CONTROLOBJECT < string name = "(self)"; string item = "距離遠"; >;

float LocalShadow_MorphLtCtrlM   : CONTROLOBJECT < string name = "(self)"; string item = "Lt影濃調整"; >;

//パラメータの合算

static float3   LocalShadow_BonePos    = LocalShadow_BonePosC + LocalShadow_BonePosM;
static float4x4 LocalShadow_BoneMatrix = mul(LocalShadow_BoneMatrixC, LocalShadow_BoneMatrixM);

static float    LocalShadow_MorphLtSync1 = LocalShadow_MorphLtSyncC + LocalShadow_MorphLtSyncM;

static float LocalShadow_MorphSize1  = LocalShadow_MorphSize1C + LocalShadow_MorphSize1M;
static float LocalShadow_MorphSize2  = LocalShadow_MorphSize2C + LocalShadow_MorphSize2M;
static float LocalShadow_MorphSize2X = LocalShadow_MorphSize2XC + LocalShadow_MorphSize2XM;
static float LocalShadow_MorphSize2Y = LocalShadow_MorphSize2YC + LocalShadow_MorphSize2YM;


static float LocalShadow_MorphDist1  = LocalShadow_MorphDist1C + LocalShadow_MorphDist1M;
static float LocalShadow_MorphDist2  = LocalShadow_MorphDist2C +  LocalShadow_MorphDist2M;

static float LocalShadow_MorphLtCtrl = LocalShadow_MorphLtCtrlC + LocalShadow_MorphLtCtrlM;


float LocalShadow_ObjTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

// ライト方向(コントローラ設定方向)
float3 LocalShadow_LtDirection : DIRECTION < string Object = "Light"; >;
static float3 LocalShadow_LtCtrlDir = normalize(LocalShadow_BoneMatrix._31_32_33);
static float3 LocalShadow_LightDirection = normalize(lerp(LocalShadow_LtCtrlDir, LocalShadow_LtDirection, LocalShadow_MorphLtSync2));

// ライト距離
static float LocalShadow_Distance = 15.0f - 14.0f*LocalShadow_MorphDist1 + 85.0f*LocalShadow_MorphDist2;


///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 座標変換行列

// ライト方向のビュー変換行列
float4x4 LocalShadow_LightViewMatrix()
{
   // z軸方向ベクトル
   float3 viewZ = LocalShadow_LightDirection;

   // x軸方向ベクトル
   float3 viewX = cross( LocalShadow_BoneMatrix._21_22_23, LocalShadow_LightDirection ); 

   // x軸方向ベクトルの正規化(LookDirとLookUpDirの方向が一致する場合は特異値となる)
   if( !any(viewX) ) viewX = LocalShadow_BoneMatrix._11_21_31;
   viewX = normalize(viewX);

   // y軸方向ベクトル
   float3 viewY = cross( viewZ, viewX );  // 共に垂直なのでこれで正規化

   // ビュー座標変換の回転行列
   float3x3 ltViewRot = float3x3( viewX.x, viewY.x, viewZ.x,
                                  viewX.y, viewY.y, viewZ.y,
                                  viewX.z, viewY.z, viewZ.z );

   // 仮の光源位置
   float3 ltViewPos = LocalShadow_BoneMatrix._41_42_43 - LocalShadow_LightDirection * LocalShadow_Distance;

   // ビュー変換行列
   return float4x4( ltViewRot[0],  0,
                    ltViewRot[1],  0,
                    ltViewRot[2],  0,
                   -mul( ltViewPos, ltViewRot ), 1 );
}


// ライト方向の射影変換行列
float4x4 LocalShadow_LightProjMatrix()
{
   float sx = 1.0f / (5.0f - 4.0f*LocalShadow_MorphSize1 + 20.0f*LocalShadow_MorphSize2 + 95.0f*LocalShadow_MorphSize2X);
   float sy = 1.0f / (5.0f - 4.0f*LocalShadow_MorphSize1 + 20.0f*LocalShadow_MorphSize2 + 95.0f*LocalShadow_MorphSize2Y);
   float d = 0.5f / LocalShadow_Distance;

   return float4x4( sx, 0,  0, 0,
                    0,  sy, 0, 0,
                    0,  0,  d, 0,
                    0,  0,  0, 1 );
}


float4x4 LocalShadow_WorldMatrix : WORLD;

static float4x4 LocalShadow_LightViewProjMatrix = mul( LocalShadow_LightViewMatrix(), LocalShadow_LightProjMatrix() );
static float4x4 LocalShadow_LightWorldViewProjMatrix = mul( LocalShadow_WorldMatrix, LocalShadow_LightViewProjMatrix );

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ライト方向の修正

float3 LocalShadow_GetLightDirection(float3 ltDir)
{
    if( LocalShadow_Valid ){
        ltDir = normalize( lerp(LocalShadow_LtCtrlDir, ltDir, LocalShadow_MorphLtSync1) );
    }
    return ltDir;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// VSMシャドウマップ関連の処理

#ifndef LOCALSHADOWMAPDRAW

// ぼかし強度
float LocalShadow_MorphSdBulr : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "影ぼかし"; >;
static float LocalShadow_ShadowBulrPower = LocalShadow_MorphSdBulr * 5.0f;

// 影濃度
float LocalShadow_MorphSdDens1 : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "影薄く";   >;
float LocalShadow_MorphSdDens2 : CONTROLOBJECT < string name = PATOONCONTROLLER; string item = "影濃く";   >;
static float LocalShadow_LtCtrlDens = smoothstep(-1.5f+1.5f*LocalShadow_MorphLtCtrl, LocalShadow_MorphLtCtrl, dot(LocalShadow_LtCtrlDir, LocalShadow_LtDirection));
static float LocalShadow_Density1 = (1.0f - LocalShadow_MorphSdDens1) * LocalShadow_LtCtrlDens;
static float LocalShadow_Density2 = 1.0f + 5.0f * LocalShadow_MorphSdDens2;

// LocalShadowによるシャドウマップバッファ
shared texture2D LocalShadow_SMapBuff : RENDERCOLORTARGET;
sampler LocalShadow_ShadowMapSamp = sampler_state {
    texture = <LocalShadow_SMapBuff>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

#if LS_UseSoftShadow==1

    // シャドウマップの周辺サンプリング回数
    #define BASESMAP_COUNT  4

    // シャドウマップバッファサイズ
    #define SMAPSIZE_WIDTH   LS_ShadowMapBuffSize
    #define SMAPSIZE_HEIGHT  LS_ShadowMapBuffSize

    // シャドウマップのサンプリング間隔
    static float2 LocalShadow_SMapSampStep = float2(LocalShadow_ShadowBulrPower/SMAPSIZE_WIDTH, LocalShadow_ShadowBulrPower/SMAPSIZE_HEIGHT);

    // シャドウマップの周辺サンプリング1
    float2 LocalShadow_GetZPlotSampleBase1(float2 Tex, float smpScale)
    {
        float2 smpStep = LocalShadow_SMapSampStep * smpScale;
        float mipLv = log2( max(SMAPSIZE_WIDTH*smpStep.x, 1.0f) );
        float2 zplot = tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex, 0, mipLv)).xy * 2.0f;
        zplot += tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex+smpStep*float2(-1,-1), 0, mipLv)).xy;
        zplot += tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex+smpStep*float2( 1,-1), 0, mipLv)).xy;
        zplot += tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex+smpStep*float2(-1, 1), 0, mipLv)).xy;
        zplot += tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex+smpStep*float2( 1, 1), 0, mipLv)).xy;
        return (zplot / 6.0f);
    }

    // シャドウマップの周辺サンプリング2
    float2 LocalShadow_GetZPlotSampleBase2(float2 Tex, float smpScale)
    {
        float2 smpStep = LocalShadow_SMapSampStep * smpScale;
        float mipLv = log2( max(SMAPSIZE_WIDTH*smpStep.x, 1.0f) );
        float2 zplot = tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex, 0, mipLv)).xy * 2.0f;
        zplot += tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex+smpStep*float2(-1, 0), 0, mipLv)).xy;
        zplot += tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex+smpStep*float2( 1, 0), 0, mipLv)).xy;
        zplot += tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex+smpStep*float2( 0,-1), 0, mipLv)).xy;
        zplot += tex2Dlod(LocalShadow_ShadowMapSamp, float4(Tex+smpStep*float2( 0, 1), 0, mipLv)).xy;
        return (zplot / 6.0f);
    }

    // セルフシャドウの遮蔽確率を求める
    float LocalShadow_GetSelfShadowRate(float2 SMapTex, float z)
    {
        // シャドウマップよりZプロットの統計処理(zplot.x:平均, zplot.y:2乗平均)
        float2 zplot = float2(0,0);
        float rate = 1.0f;
        float sumRate = 0.0f;
        [unroll]
        for(int i=0; i<BASESMAP_COUNT; i+=2) {
            rate *= 0.5f; sumRate += rate;
            zplot += LocalShadow_GetZPlotSampleBase1(SMapTex, float(i+1)) * rate;
            rate *= 0.5f; sumRate += rate;
            zplot += LocalShadow_GetZPlotSampleBase2(SMapTex, float(i+2)) * rate;
        }
        zplot /= sumRate;

        // 影部判定(VSM:Variance Shadow Maps法)
        float variance = max( zplot.y - zplot.x * zplot.x, 0.05f/LocalShadow_Distance );
        float comp = variance / (variance + max(z - zplot.x, 0.0f));

        comp = smoothstep(0.1f/max(LocalShadow_ShadowBulrPower, 1.0f), 1.0f, comp);
        return (1.0f-(1.0f-comp)*LocalShadow_Density1);
    }

#else

    #define LocalShadow_SKII1  (200.0f*LocalShadow_Distance)

    // セルフシャドウの遮蔽確率を求める(ソフトシャドウを使わない場合)
    float LocalShadow_GetSelfShadowRate(float2 SMapTex, float z)
    {
        float comp;
        float dist = max( z - tex2D(LocalShadow_ShadowMapSamp, SMapTex).r, 0.0f );
        comp = 1.0f - saturate( dist * LocalShadow_SKII1 - 7.0f);

        return (1.0f-(1.0f-comp)*LocalShadow_Density1);
    }

#endif


////////////////////////////////////////////////////////////////////////////////////////////////
// 濃度設定関連の処理

struct  LocalShadow_COLOR {
    float4 Color;        // オブジェクト色
    float4 ShadowColor;  // 影色
};

// 影色に濃度を加味する
LocalShadow_COLOR LocalShadow_GetShadowDensity(float4 Color, float4 ShadowColor, bool useToon, float LightNormal)
{
    LocalShadow_COLOR Out;
    Out.Color = Color;
    Out.ShadowColor = ShadowColor;

    if( !useToon || length(Color.rgb-ShadowColor.rgb) > 0.01f ){
        float e = max(LocalShadow_Density2, 1.0f);
        float a = 1.0f / e;
        float b = 1.0f - smoothstep(3.0f, 6.0f, e);
        float3 color = lerp(ShadowColor.rgb*a, ShadowColor.rgb*b, pow(ShadowColor.rgb, e));
        Out.ShadowColor = float4(saturate(color), ShadowColor.a);
    }
    if( !useToon ){
        float e = lerp( LocalShadow_Density2, 1.0f, smoothstep(0.0f, 0.4f, LightNormal) );
        float a = 1.0f / e;
        float b = 1.0f - smoothstep(4.0f, 5.0f, e);
        float3 color = lerp(Color.rgb*a, Color.rgb*b, pow(Color.rgb, e));
        Out.Color = float4(saturate(color), Color.a);
        Out.Color.a *= LocalShadow_ObjTr;
        Out.ShadowColor.a *= LocalShadow_ObjTr;
    }

    return Out;
}


#endif
#endif
