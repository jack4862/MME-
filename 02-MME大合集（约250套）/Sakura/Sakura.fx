////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ宣言

int index = 0; //ループ用変数

//パーティクル数最大値
#define CLONE_NUM 1024



int count
<
   string UIName = "count";
   string UIWidget = "Numeric";
   int UIMin = 1;
   int UIMax = 2048;
> = CLONE_NUM;

int count_ss = CLONE_NUM*2;

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
> = 2;

float NoizeLevel
<
   string UIName = "NoizeLevel";
   string UIWidget = "Slider";
   float UIMin = 0.0;
   float UIMax = 2.0;
> = 2;

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
    string ResourceName = "sakura.png";
>;


float3 ControllerPos : CONTROLOBJECT < string name = "Controller_0.pmd"; string item = "センター"; >;
float morph_spd : CONTROLOBJECT < string name = "Controller_0.pmd"; string item = "速度調節"; >;
float morph_width_x : CONTROLOBJECT < string name = "Controller_0.pmd"; string item = "範囲X"; >;
float morph_width_z : CONTROLOBJECT < string name = "Controller_0.pmd"; string item = "範囲Z"; >;
float morph_height : CONTROLOBJECT < string name = "Controller_0.pmd"; string item = "範囲Y"; >;
float morph_num : CONTROLOBJECT < string name = "Controller_0.pmd"; string item = "個数調節"; >;





sampler Tex1Samp = sampler_state {
    texture = <Tex1>;
};

//乱数テクスチャ
texture2D rndtex <
    //string ResourceName = "random2048.bmp";
    string ResourceName = "random4096.bmp";
>;
sampler rnd = sampler_state {
    texture = <rndtex>;
};

//乱数テクスチャ幅
#define RNDTEX_WIDTH 4096


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
static float rot_x = ftime * RotationSpeed + index * 12;
static float rot_y = ftime * RotationSpeed + index * 34;
static float rot_z = ftime * RotationSpeed + index * 56;

static float3x3 RotationX = {
    {1,	0,	0},
    {0, cos(rot_x), sin(rot_x)},
    {0, -sin(rot_x), cos(rot_x)},
};
static float3x3 RotationY = {
    {cos(rot_y), 0, -sin(rot_y)},
    {0, 1, 0},
	{sin(rot_y), 0,cos(rot_y)},
    };
static float3x3 RotationZ = {
    {cos(rot_z), sin(rot_z), 0},
    {-sin(rot_z), cos(rot_z), 0},
    {0, 0, 1},
};

float4x4 LightWorldViewProjMatrix : WORLDVIEWPROJECTION < string Object = "Light"; >;

///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット

struct VS_ZValuePlot_OUTPUT {
    float4 Pos : POSITION;              // 射影変換座標
    float  Alpha      : COLOR0;
    float4 ShadowMapTex : TEXCOORD0;    // Zバッファテクスチャ
    float2 Tex        : TEXCOORD1;   // テクスチャ
};

// 頂点シェーダ
VS_ZValuePlot_OUTPUT ZValuePlot_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_ZValuePlot_OUTPUT Out;
    Out.Alpha = 1;
    
    float findex = index;
    
    //回転・サイズ変更
    Pos.xyz = mul( Pos.xyz, RotationX );
    Pos.xyz = mul( Pos.xyz, RotationY );
    Pos.xyz = mul( Pos.xyz, RotationZ );
    Pos.xy *= ParticleSize;
    
    // ビルボード
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
    
    // ランダム配置
    float2 base_tex_coord = float2((findex+0.5)/RNDTEX_WIDTH, 0.5);
    float4 base_pos = tex2Dlod(rnd, float4(base_tex_coord,0,1));
    
    base_pos.xz -= 0.5;
    base_pos.y = frac(base_pos.y - ((Speed * (1-morph_spd)) * ftime / Height));
    
    //出現後と消滅直前はフェード
    Out.Alpha = saturate((1 - base_pos.y) * 3) * saturate(base_pos.y * 40);
    
    //領域変更
    WidthX *= 1.0+morph_width_x*10.0;
    WidthZ *= 1.0+morph_width_z*10.0;
    Height *= 1.0+morph_height*10.0;
    
    base_pos.xyz *= float3(WidthX, Height, WidthZ);
    base_pos.xyz *= 0.1;
    
    //斜め
    float2 vec = ControllerPos.xz*0.1;
    vec *= base_pos.y;
    base_pos.xz += vec;
    
    //ノイズ付加
    base_pos.xz += noise(float2(ftime * 0.2, findex * 5)) * NoizeLevel;
    
    Pos.xyz += base_pos;
   
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    //遠方は薄く
    Out.Alpha *= 0.3 + 0.7 * (1 - saturate((Out.Pos.z - 50) / FadeLength));
    Out.Alpha *= alpha1;
    
    // テクスチャ座標初期設定
    Out.Tex = Tex*0.5;
	
	//４種類のテクスチャから選択
	int w = findex%4;
	if(w < 2)
	{
		Out.Tex.x += 0.5;
	}
	if(w%2 == 0)
	{
		Out.Tex.y += 0.5;
	}

    // ライトの目線によるワールドビュー射影変換をする
    Out.Pos = mul( Pos, LightWorldViewProjMatrix );

    // テクスチャ座標を頂点に合わせる
    Out.ShadowMapTex = Out.Pos;

    return Out;
}

// ピクセルシェーダ
float4 ZValuePlot_PS( float4 ShadowMapTex : TEXCOORD0,float2 Tex : TEXCOORD1 ) : COLOR
{
	if(index >= (1-morph_num)*(float)count_ss)
	{
		discard;
	}
   float4 color = tex2D( Tex1Samp, Tex );
    
    // R色成分にZ値を記録する
    return color * float4(ShadowMapTex.z/ShadowMapTex.w,0,0,1);
}

// Z値プロット用テクニック
technique ZplotTec <
	string MMDPass = "zplot";    
	string Script = 
        "LoopByCount=count_ss;"
        "LoopGetIndex=index;"
        "Pass=ZValuePlot;"
        "LoopEnd=;"
    ;
> {
    pass ZValuePlot {
        AlphaBlendEnable = FALSE;
        VertexShader = compile vs_3_0 ZValuePlot_VS();
        PixelShader  = compile ps_3_0 ZValuePlot_PS();
    }
}


///////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT
{
    float4 Pos        : POSITION;    // 射影変換座標
    float2 Tex        : TEXCOORD0;   // テクスチャ
    float  Alpha      : COLOR0;
};
///////////////////////////////////////////////////////////////////////////////////////////////

// 頂点シェーダ
VS_OUTPUT Mask_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out;
    Out.Alpha = 1;
    
    float findex = index;
    
    //回転・サイズ変更
    Pos.xyz = mul( Pos.xyz, RotationX );
    Pos.xyz = mul( Pos.xyz, RotationY );
    Pos.xyz = mul( Pos.xyz, RotationZ );
    Pos.xy *= ParticleSize;
    
    // ビルボード
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
    
    // ランダム配置
    float2 base_tex_coord = float2((findex+0.5)/RNDTEX_WIDTH, 0.5);
    float4 base_pos = tex2Dlod(rnd, float4(base_tex_coord,0,1));
    
    base_pos.xz -= 0.5;
    base_pos.y = frac(base_pos.y - ((Speed * (1-morph_spd)) * ftime / Height));
    
    //出現後と消滅直前はフェード
    Out.Alpha = saturate((1 - base_pos.y) * 3) * saturate(base_pos.y * 40);
    
    //領域変更
    WidthX *= 1.0+morph_width_x*10.0;
    WidthZ *= 1.0+morph_width_z*10.0;
    Height *= 1.0+morph_height*10.0;
    
    base_pos.xyz *= float3(WidthX, Height, WidthZ);
    base_pos.xyz *= 0.1;
    
    //斜め
    float2 vec = ControllerPos.xz*0.1;
    vec *= base_pos.y;
    base_pos.xz += vec;
    
    //ノイズ付加
    base_pos.xz += noise(float2(ftime * 0.2, findex * 5)) * NoizeLevel;
    
    Pos.xyz += base_pos;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    //遠方は薄く
    Out.Alpha *= 0.3 + 0.7 * (1 - saturate((Out.Pos.z - 50) / FadeLength));
    Out.Alpha *= alpha1;
    
    // テクスチャ座標初期設定
    Out.Tex = Tex*0.5;
	
	//４種類のテクスチャから選択
	int w = findex%4;
	if(w < 2)
	{
		Out.Tex.x += 0.5;
	}
	if(w%2 == 0)
	{
		Out.Tex.y += 0.5;
	}
	
	
    return Out;
}
// 頂点シェーダ
VS_OUTPUT Mask_SS_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0)
{
    VS_OUTPUT Out;
    Out.Alpha = 1;
    
    float findex = index;
    findex *= 0.5;
    
    //回転・サイズ変更
    Pos.xyz = mul( Pos.xyz, RotationX );
    Pos.xyz = mul( Pos.xyz, RotationY );
    Pos.xyz = mul( Pos.xyz, RotationZ );
    Pos.xy *= ParticleSize;
    
    // ビルボード
    Pos.xyz = mul( Pos.xyz, BillboardMatrix );
    
    // ランダム配置
    float2 base_tex_coord = float2((findex+0.5)/RNDTEX_WIDTH, 0.5);
    float4 base_pos = tex2Dlod(rnd, float4(base_tex_coord,0,1));
    
    base_pos.xz -= 0.5;
    base_pos.y = frac(base_pos.y - ((Speed * (1-morph_spd)) * ftime / Height));
    
    //出現後と消滅直前はフェード
    Out.Alpha = saturate((1 - base_pos.y) * 3) * saturate(base_pos.y * 40);
    
    //領域変更
    WidthX *= 1.0+morph_width_x*10.0;
    WidthZ *= 1.0+morph_width_z*10.0;
    Height *= 1.0+morph_height*10.0;
    
    base_pos.xyz *= float3(WidthX, Height, WidthZ);
    base_pos.xyz *= 0.1;
    
    //斜め
    float2 vec = ControllerPos.xz*0.1;
    vec *= base_pos.y;
    base_pos.xz += vec;
    
    //ノイズ付加
    base_pos.xz += noise(float2(ftime * 0.2, findex * 5)) * NoizeLevel;
    
    Pos.xyz += base_pos;
    
    // カメラ視点のワールドビュー射影変換
    Out.Pos = mul( Pos, WorldViewProjMatrix );
    
    //遠方は薄く
    Out.Alpha *= 0.3 + 0.7 * (1 - saturate((Out.Pos.z - 50) / FadeLength));
    Out.Alpha *= alpha1;
    
    // テクスチャ座標初期設定
    Out.Tex = Tex*0.5;
	
	//４種類のテクスチャから選択
	int w = findex%4;
	if(w < 2)
	{
		Out.Tex.x += 0.5;
	}
	if(w%2 == 0)
	{
		Out.Tex.y += 0.5;
	}
	
	
    return Out;
}
// ピクセルシェーダ
float4 Mask_PS( VS_OUTPUT input ) : COLOR0
{
	if(index >= (1-morph_num)*(float)count)
	{
		discard;
	}
    float4 color = tex2D( Tex1Samp, input.Tex );
    color.a *= input.Alpha;
    return color;
}
float4 Mask_SS_PS( VS_OUTPUT input ) : COLOR0
{
	if(index >= (1-morph_num)*(float)count_ss)
	{
		discard;
	}
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
        CULLMODE = NONE;
        VertexShader = compile vs_3_0 Mask_VS();
        PixelShader  = compile ps_3_0 Mask_PS();
    }
}
technique MainTecSS < 
    string MMDPass = "object_ss";
    string Script = 
        "LoopByCount=count_ss;"
        "LoopGetIndex=index;"
        "Pass=DrawObject;"
        "LoopEnd=;"
    ;
> {
    pass DrawObject {
        ZWRITEENABLE = false;
        CULLMODE = NONE;
        VertexShader = compile vs_3_0 Mask_SS_VS();
        PixelShader  = compile ps_3_0 Mask_SS_PS();
    }
}
