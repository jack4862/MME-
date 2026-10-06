////////////////////////////////////////////////////////////////////////////////////////////////
//
//  Flocking.fx ver0.0.4  フロッキングアルゴリズムを使った群れ行動制御
//  作成: 針金P
//
////////////////////////////////////////////////////////////////////////////////////////////////
// ここのパラメータを変更してください

int Count = 200;  // モデル複製数(最大1024, Flocking_Obj.fxも同じ値を設定する必要あり)

float WideViewRadius = 15.0;     // 視認エリア半径(大きくすると他のユニットが見つかりやすくなる)
float WideViewAngle = 45.0;      // 視認エリア角度(0～180)(大きくすると他のユニットが見つかりやすくなる)
float CohesionFactor = 5.0;      // 結合度(大きくすると近隣ユニットどうしが一つにまとまりやすくなる)
float AlignmentFactor = 25.0;    // 整列度(大きくすると近隣ユニットどうしが同じ方向を向きやすくなる)
float SeparationFactor = 100.0;  // 分離度(大きくすると隣接ユニットとの衝突回避度が大きくなる)
float SeparationLength = 10.0;   // 分離判定距離(大きくすると隣接ユニットとの衝突回避行動をとりやすくなる)
float DrivingForceFactor = 50.0; // 推進力(大きくすると移動スピードが速くなる)
float ResistanceFactor = 2.0;    // 抵抗力(大きくすると移動スピードが減衰しやすくなる)
float VerticalAngleLimit = 30.0; // 鉛直移動制限角(0～90)(大きくすると上下方向の移動が活発になる)
float PotentialOutside = 60.0;   // 移動制限外縁距離(大きくすると移動範囲が広くなる)
float PotentialFloor = 10.0;     // 移動制限床面高さ(大きくすると床に近づいた時に高い位置で回避行動をとる)
float PotentialCiel = 60.0;      // 移動制限天井高さ(大きくするとより高い位置まで移動するようになる)

#define ArrangeFileName "ArrangeData.png" // 初期配置情報画像ファイル名(MikuMikuMobより作成)
#define ARRANGE_TEX_HEIGHT 1024           // 初期配置情報画像ファイルのピクセル高さ(必ず2の乗数で1024以上になるように画像ファイルを作成すること)


// 解らない人はここから下はいじらないでね
////////////////////////////////////////////////////////////////////////////////////////////////

float AcsTr  : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float AcsSi  : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
static bool InitFlag = AcsTr > 0.0f ? true : false;
static float OutsideLength = PotentialOutside * AcsSi * 0.1f;
static float CielHeight = PotentialFloor + (PotentialCiel - PotentialFloor) * AcsSi * 0.1f;

#define PAI 3.14159265f
static float WideViewCosA = cos( WideViewAngle*PAI/180.0f );
static float VAngLimit = VerticalAngleLimit*PAI/180.0f;

#define ARRANGE_TEX_WIDTH  8       // 配置テクスチャピクセル幅
#define TEX_WIDTH  1               // ユニットデータ格納テクスチャピクセル幅
#define TEX_HEIGHT 1024            // ユニットデータ格納テクスチャピクセル高さ

float time1 : Time;
float elapsed_time : ELAPSEDTIME;
static float Dt = (elapsed_time < 0.2f) ? clamp(elapsed_time, 0.01f, 1.0f/15.0f) : 1.0f/30.0f;


// 配置情報テクスチャ
texture2D ArrangeTex <
    string ResourceName = ArrangeFileName;
>;
sampler ArrangeSmp = sampler_state{
    texture = <ArrangeTex>;
    MinFilter = POINT;
    MagFilter = POINT;
    MipFilter = NONE;
};

// 1ステップ前の座標記録用
texture CoordTexOld : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler SmpCoordOld = sampler_state
{
   Texture = <CoordTexOld>;
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// 現在の座標記録用
shared texture Flocking_CoordTex : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler Flocking_SmpCoord = sampler_state
{
   Texture = <Flocking_CoordTex>;
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// 速度記録用
shared texture Flocking_VelocityTex : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
sampler Flocking_SmpVelocity = sampler_state
{
   Texture = <Flocking_VelocityTex>;
   ADDRESSU = CLAMP;
   ADDRESSV = CLAMP;
   MAGFILTER = NONE;
   MINFILTER = NONE;
   MIPFILTER = NONE;
};

// ポテンシャル記録用
shared texture Flocking_PotentialTex : RenderColorTarget
<
   int Width=TEX_WIDTH;
   int Height=TEX_HEIGHT;
   string Format="A32B32G32R32F";
>;
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
// モデルの回転行列
float4x4 RoundMatrix(float3 Angle)
{
   float3 AngleY = normalize( float3(Angle.x, 0.0f, Angle.z) );
   float cosy = -AngleY.z;
   float siny = sign(AngleY.x) * sqrt(1.0f - cosy*cosy);
   float3 AngleXY = normalize( float3(Angle.x, 0.0f, Angle.z) );
   float cosx = dot( AngleXY, Angle );
   float sinx = sign(Angle.y) * sqrt(1.0f - cosx*cosx);

   float4x4 rMat = { cosy,       0.0f,  siny,      0.0f,
                    -sinx*siny,  cosx,  sinx*cosy, 0.0f,
                    -cosx*siny, -sinx,  cosx*cosy, 0.0f,
                     0.0f,       0.0f,  0.0f,      1.0f };

   return rMat;
}

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
// 配置情報テクスチャからデータを取り出す
float Color2Float(int i, int j)
{
    float4 d = tex2D(ArrangeSmp, float2((i+0.5)/ARRANGE_TEX_WIDTH, (j+0.5)/ARRANGE_TEX_HEIGHT));
    float tNum = (65536.0f * d.x + 256.0f * d.y + d.z) * 255.0f;
    int pNum = (int)(d.w * 255);
    int sgn = 1 - 2 * (pNum % 2);
    float data = tNum * pow(10.0f, pNum/2 - 64) * sgn;
    return data;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 共通の頂点シェーダ

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
// 0フレーム再生でユニット座標を初期化

float4 PosInit_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   float4 Pos;
   if( time1 < 0.01f && InitFlag ){
      // 0フレーム再生でリセット
      int i = round( texCoord.y*TEX_HEIGHT );
      float3 pos = float3(Color2Float(0, i), Color2Float(1, i), Color2Float(2, i));
      Pos = float4(pos, 1.0f);
   }else{
      Pos = tex2D(Flocking_SmpCoord, texCoord);
   }

   return Pos;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 方向・速度の計算(xyz:正規化された方向ベクトル，w:速さ)

float4 Velocity_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   float4 vel;
   if( time1 < 0.01f && InitFlag ){
      // 0フレーム再生で方向初期化
      int i = round( texCoord.y*TEX_HEIGHT );
      float rx = Color2Float(3, i);
      float ry = Color2Float(4, i);
      float sinx = sin(rx);
      float cosx = cos(rx);
      float siny = sin(ry);
      float cosy = cos(ry);
      float3x3 rMat = { cosy,       0.0f,  siny,
                       -sinx*siny,  cosx,  sinx*cosy,
                       -cosx*siny, -sinx,  cosx*cosy};
      float3 ang = mul( float3(0.0f, 0.0f, -1.0f), rMat );
      vel = float4(ang, 0.0f);
   }else{
      float4 vel0 = tex2D(Flocking_SmpVelocity, texCoord);
      float3 Pos1 = (float3)tex2D(SmpCoordOld, texCoord);
      float3 Pos2 = (float3)tex2D(Flocking_SmpCoord, texCoord);
      float3 v = ( Pos2 - Pos1 )/Dt;
      float len = length( v );
      vel = (len > 0.0001f) ? float4( normalize(v), len ) : float4( vel0.xyz, len );
   }

   return vel;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// ポテンシャルの初期化(ポテンシャルによる操舵力は1フレーム前の結果が使われるため
// 0フレーム再生時は初期化の必要有り)

float4 PotentialInit_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   // ポテンシャルによるユニットの操舵力
   float4 SteerForce = tex2D(Flocking_SmpPotential, texCoord);
   if( time1 < 0.01f && InitFlag ){
      // 0フレーム再生でリセット
      SteerForce = float4(0.0f, 0.0f, 0.0f, 0.0f);
   }

   return SteerForce;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// 現ユニット座標値を1ステップ前の座標にコピー

float4 PosCopy_PS(float2 texCoord: TEXCOORD0) : COLOR
{
   float4 Pos = tex2D(Flocking_SmpCoord, texCoord);
   return Pos;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// 現ユニット座標値をフロッキングアルゴリズムで更新

float4 PosFlocking_PS(float2 texCoord: TEXCOORD0) : COLOR
{
    // 1ステップ前の位置
    float3 Pos0 = (float3)tex2D(SmpCoordOld, texCoord);
    float lenP0 = length( Pos0 );

    // 方向・速度
    float4 v = tex2D(Flocking_SmpVelocity, texCoord);
    float3 Angle = v.xyz;
    float3 Vel = Angle * v.w;

    // 回転逆行列
    float3x3 invRMat = (float3x3)InvRoundMatrix(Angle);

    // 操舵力初期化
    float3 SteerForce = 0.0f;
    float3 AvgPos = 0.0f;
    float3 AvgAng = 0.0f;
    int n = 0;

    // フロッキングアルゴリズム(各ユニットの位置関係から操舵力を求める)
    int j = round( texCoord.y*TEX_HEIGHT );
    for(int i=0; i<Count; i++){
       if( i != j ){
          float y = (float(i) + 0.5f)/TEX_HEIGHT;
          float3 pos_i = (float3)tex2D(SmpCoordOld, float2(texCoord.x, y));
          float3 ang_i = (float3)tex2D(Flocking_SmpVelocity, float2(texCoord.x, y));
          float len = length( pos_i - Pos0 );
          float cosa = dot( ang_i, Angle );
          if(len < WideViewRadius && cosa > WideViewCosA){ // 視認ユニットかどうか
             AvgPos += pos_i;
             AvgAng += ang_i;
             n++;
             // 分離の操舵力(ユニット同士の衝突回避)
             if(len < SeparationLength){
                float3 pos_local = mul( pos_i-Pos0, invRMat );
                SteerForce += normalize( -pos_local ) * SeparationFactor / len * min(1.0f, time1/5.0f);
             }
          }
       }
    }
    if( n > 0){
       // 結合の操舵力(一つにまとまる力)
       AvgPos = mul( AvgPos/float(n)-Pos0, invRMat );
       AvgPos.z = 0.0f;
       SteerForce += AvgPos * CohesionFactor;

       // 整列の操舵力(同じ方向を向かせる力)
       AvgAng = normalize( mul( AvgAng, invRMat ) );
       float a1 = acos( clamp(dot( AvgAng, float3(0.0f, 0.0f, -1.0f) ), -1.0f, 1.0f) );
       AvgAng = normalize( float3(AvgAng.x, AvgAng.y, 0.0f) );
       SteerForce +=  AvgAng * a1 * AlignmentFactor;
    }

    // ポテンシャルによる操舵力を付加
    SteerForce += (float3)tex2D(Flocking_SmpPotential, texCoord);

    // 操舵力の方向をワールド座標系に変換
    SteerForce = mul( SteerForce, (float3x3)RoundMatrix(Angle) );

    // 加速度計算(推進力+抵抗力+操舵力)
    float3 Accel = DrivingForceFactor * Angle - ResistanceFactor * Vel + SteerForce;

    // 新しい座標に更新
    float4 Pos = float4( Pos0 + Dt * (Vel + Dt * Accel), 1.0f );

    // 鉛直方向角度制限
    if( (PotentialFloor <= Pos.y && Pos.y <= CielHeight) ||
        (Pos.y < PotentialFloor && Pos.y < Pos0.y) ||
        (CielHeight < Pos.y && Pos.y > Pos0.y) ){
       float3 pos2 = (float3)Pos - Pos0;
       float3 pos3 = float3(pos2.x, 0.0f, pos2.z );
       float a = acos( min(dot( normalize(pos2), normalize(pos3) ), 1.0f) );
       if(a > VAngLimit){
          pos3.y = sign(pos2.y) * length(pos3) * tan(VAngLimit);
          Pos = float4( Pos0 + pos3, 1.0f );
       }
    }

    return Pos;
}


////////////////////////////////////////////////////////////////////////////////////////////////
// ユニットを指定範囲内に留めるためのポテンシャルによる操舵力を求める

float4 Potential_PS(float2 texCoord: TEXCOORD0) : COLOR
{
    // ユニットの位置
    float3 Pos0 = (float3)tex2D(Flocking_SmpCoord, texCoord);
    float lenP0 = length( Pos0 );

    // ユニットの方向・速度
    float4 v = tex2D(Flocking_SmpVelocity, texCoord);
    float3 Angle = v.xyz;
    float3 Vel = Angle * v.w;

    // 回転逆行列
    float3x3 invRMat = (float3x3)InvRoundMatrix(Angle);

    // ポテンシャルによる操舵力初期化
    float3 SteerForce = float3(0.0f, 0.0f, 0.0f);

    // 外縁ポテンシャル(遠くに行きすぎないように)
    float limit = (lenP0 < 2.0f*OutsideLength) ? -abs(cos(time1)) : -0.9999f;
    float p = clamp(-OutsideLength-Pos0.x, 0.0f, 20.0f);
    if( p > 0.0f && dot( Angle, float3(-1.0f, 0.0f, 0.0f) ) > limit ){
       float3 pa = mul( float3(-Pos0.x, 0.0f, -Pos0.z), invRMat );
       pa.z = 0.0f;
       SteerForce += normalize(pa)*p*p;
    }
    p = clamp(Pos0.x-OutsideLength, 0.0f, 20.0f);
    if( p > 0.0f && dot( Angle, float3(1.0f, 0.0f, 0.0f) ) > limit ){
       float3 pa = mul( float3(-Pos0.x, 0.0f, -Pos0.z), invRMat );
       pa.z = 0.0f;
       SteerForce += normalize(pa)*p*p;
    }
    p = clamp(-OutsideLength-Pos0.z, 0.0f, 20.0f);
    if( p > 0.0f && dot( Angle, float3(0.0f, 0.0f, -1.0f) ) > limit ){
       float3 pa = mul( float3(-Pos0.x, 0.0f, -Pos0.z), invRMat );
       pa.z = 0.0f;
       SteerForce += normalize(pa)*p*p;
    }
    p = clamp(Pos0.z-OutsideLength, 0.0f, 20.0f);
    if( p > 0.0f && dot( Angle, float3(0.0f, 0.0f, 1.0f) ) > limit ){
       float3 pa = mul( float3(-Pos0.x, 0.0f, -Pos0.z), invRMat );
       pa.z = 0.0f;
       SteerForce += normalize(pa)*p*p;
    }

    // 床面ポテンシャル(床下に潜らないように)
    p = max( PotentialFloor - Pos0.y, 0.0f);
    SteerForce.y += p*p;

    // 天井ポテンシャル(昇り過ぎないように)
    p = max( Pos0.y - CielHeight, 0.0f);
    SteerForce.y -= p*p;

   return float4(SteerForce, 0.0f);
}

/////////////////////////////////////////////////////////////////////////////////
// フロッキングアルゴリズム計算を行うテクニック
// ここの計算結果を基にFlocking_Obj.fxでユニットの複製・描画を行う

technique MainTec0 < string MMDPass = "object";
    string Script = 
        "RenderColorTarget0=Flocking_CoordTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PosInit;"
        "RenderColorTarget0=Flocking_VelocityTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=CalcVelocity;"
        "RenderColorTarget0=Flocking_PotentialTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PotentialInit;"
        "RenderColorTarget0=CoordTexOld;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PosCopy;"
        "RenderColorTarget0=Flocking_CoordTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=PosUpdate;"
        "RenderColorTarget0=Flocking_PotentialTex;"
	    "RenderDepthStencilTarget=DepthBuffer;"
	    "Pass=CalcPotential;"
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;";
>{
    pass PosInit < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 PosInit_PS();
    }
    pass CalcVelocity < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 Velocity_PS();
    }
    pass PotentialInit < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_1_1 Common_VS();
        PixelShader  = compile ps_2_0 PotentialInit_PS();
    }
    pass PosCopy < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_1_1 Common_VS();
        PixelShader  = compile ps_2_0 PosCopy_PS();
    }
    pass PosUpdate < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 PosFlocking_PS();
    }
    pass CalcPotential < string Script = "Draw=Buffer;";>
    {
        ALPHABLENDENABLE = FALSE;
        ALPHATESTENABLE = FALSE;
        VertexShader = compile vs_3_0 Common_VS();
        PixelShader  = compile ps_3_0 Potential_PS();
    }
}


