////////////////////////////////////////////////////////////////////////////////////////////////
//
// Flocking_Obstacle_Capsule.fx  フロッキングアルゴリズム(障害物回避：カプセル)
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください
float AvoidanceFactor = 15.0;       // 回避度(大きくすると障害物との衝突回避しやすくなる)


// 解らない人はここから下はいじらないでね
////////////////////////////////////////////////////////////////////////////////////////////////


#define TEX_WIDTH  1               // ユニットデータ格納テクスチャピクセル幅
#define TEX_HEIGHT 1024            // ユニットデータ格納テクスチャピクセル高さ

// 座標変換行列
float4x4 WorldMatrix : WORLD;

static float AcsScaling = length(WorldMatrix._11_12_13); 
static float3 CapsPos1 = (float3)mul( float4(0.0f, -0.6f, 0.0f, 1.0f), WorldMatrix );
static float3 CapsPos2 = (float3)mul( float4(0.0f,  0.6f, 0.0f, 1.0f), WorldMatrix );

// ユニットの座標が記録されているテクスチャ
shared texture Flocking_CoordTex : RenderColorTarget;
sampler Flocking_SmpCoord = sampler_state
{
   Texture = <Flocking_CoordTex>;
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// ユニットの向き・速度が記録されているテクスチャ
shared texture Flocking_VelocityTex : RenderColorTarget;
sampler Flocking_SmpVelocity = sampler_state
{
   Texture = <Flocking_VelocityTex>;
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// ユニットのポテンシャルによる操舵力を記録するテクスチャ
shared texture Flocking_PotentialTex : RenderColorTarget;
sampler Flocking_SmpPotential = sampler_state
{
   Texture = <Flocking_PotentialTex>;
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// 共通の深度ステンシルバッファ
texture DepthBuffer : RenderDepthStencilTarget <
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
    string Format = "D24S8";
>;

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

////////////////////////////////////////////////////////////////////////////////////////////////
// モデルの回転逆行列
float4x4 InvRoundMatrix(float3 Angle)
{
   float3 AngleY = normalize( float3(Angle.x, 0.0f, Angle.z) );
   float cosy = -Angle.z;
   float siny = sign(Angle.x) * sqrt(1.0f - cosy*cosy);
   float3 AngleXY = normalize( float3(Angle.x, 0.0f, Angle.z) );
   float cosx = dot( Angle, AngleXY );
   float sinx = sign(Angle.y) * sqrt(1.0f - cosx*cosx);

   float4x4 rMat = { cosy, -sinx*siny, -cosx*siny, 0.0f,
                     0.0f,  cosx,      -sinx,      0.0f,
                     siny,  sinx*cosy,  cosx*cosy, 0.0f,
                     0.0f,  0.0f,       0.0f,      1.0f };

   return rMat;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 頂点シェーダ

struct VS_OUTPUT2 {
   float4 Pos      : POSITION;
   float2 texCoord : TEXCOORD0;
};

VS_OUTPUT2 Common_VS(float4 Pos: POSITION, float2 Tex: TEXCOORD) {
   VS_OUTPUT2 Out;
   Out.Pos = Pos;
   Out.texCoord = Tex + float2(0.5f/TEX_WIDTH, 0.5f/TEX_HEIGHT);
   return Out;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// ピクセルシェーダ(障害物回避の操舵力を求める)

float4 Potential_PS(float2 texCoord: TEXCOORD0) : COLOR
{
    // ポテンシャルによるユニットの操舵力
    float4 SteerForce = tex2D(Flocking_SmpPotential, texCoord);

    // ユニットの位置
    float3 Pos0 = (float3)tex2D(Flocking_SmpCoord, texCoord);

    // ユニットの方向・速度
    float4 v = tex2D(Flocking_SmpVelocity, texCoord);
    float3 Angle = v.xyz;
    float3 Vel = Angle * v.w;

    // 障害物の方向ベクトル
    float3 ObstaclePos;
    if( dot( Pos0-CapsPos1, CapsPos2-CapsPos1 ) <= 0.0f ){
       ObstaclePos = CapsPos1;
    }else if( dot(Pos0-CapsPos2, CapsPos1-CapsPos2 ) <= 0.0f ){
       ObstaclePos = CapsPos2;
    }else{
       float len = length(  CapsPos2 - CapsPos1 );
       float t = dot( CapsPos2-CapsPos1, Pos0-CapsPos1 ) / (len*len);
       ObstaclePos = (1.0f-t) * CapsPos1 + t * CapsPos2;
    }
    float3 ObstacleAngle = normalize( ObstaclePos - Pos0 );

    // 障害物までの距離
    float3 ObstacleLength = length( Pos0 - ObstaclePos ) - AcsScaling;

    // 障害物に衝突の可能性がある場合は操舵力を付加
    if( ObstacleLength < AvoidanceFactor && dot( Angle, ObstacleAngle ) > -0.5f ){
       // 障害物のポテンシャル
       float len1 = clamp( ObstacleLength, 0.001f, AvoidanceFactor );
       float len2 = max( AvoidanceFactor-ObstacleLength, 0.0f );
       float p = max( 1.0f/len1, 0.0f ) + len2*len2;
       float3 pa = mul( -ObstacleAngle, InvRoundMatrix(Angle) );
       pa.z = 0.0f;
       SteerForce.xyz += normalize(pa)*p;
    }

    return SteerForce;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique MainTec0 < string MMDPass = "object";
    string Script = 
        "RenderColorTarget0=Flocking_PotentialTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=CalcPotential;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
	    "Pass=DrawObject;"
        ;
>{
    pass CalcPotential < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 Potential_PS();
    }
    pass DrawObject {
    }
}

