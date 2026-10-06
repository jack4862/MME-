////////////////////////////////////////////////////////////////////////////////////////////////
//
// MirrorEmittionDraw for WorkingFloorAL.fx
//
////////////////////////////////////////////////////////////////////////////////////////////////
//オプションスイッチ(AL_Object.fxsubと同じ設定にすること)

//異方性フィルタリング作業用テクスチャサイズ
// 0で無効化
#define MIPMAPTEX_SIZE  0 //512

//テクスチャ高輝度識別フラグ
//#define TEXTURE_SELECTLIGHT

//閾値
float LightThreshold = 0.9;

// TrueCameraLXで使用する
//0がオフ、1がオンです
#define UseTrueCameraLX  0


////////////////////////////////////////////////////////////////////////////////////////////////

#define SPECULAR_BASE 100
#define SYNC false

float3 MirrorPos = float3( 0.0, 0.0, 0.0 );    // ローカル座標系における鏡面上の任意の座標(アクセ頂点座標の一点)
float3 MirrorNormal = float3( 0.0, 1.0, 0.0 ); // ローカル座標系における鏡面の法線ベクトル


///////////////////////////////////////////////////////////////////////////////////////////////
// 鏡面座標変換パラメータ
float4x4 MirrorWorldMatrix: CONTROLOBJECT < string Name = "(OffscreenOwner)"; >; // 鏡面アクセのワールド変換行列

// ワールド座標系における鏡像位置への変換
static float3 WldMirrorPos = mul( float4(MirrorPos, 1.0f), MirrorWorldMatrix ).xyz;
static float3 WldMirrorNormal = normalize( mul( MirrorNormal, (float3x3)MirrorWorldMatrix ) );

// 座標の鏡像変換
float4 TransMirrorPos( float4 Pos )
{
    Pos.xyz -= WldMirrorNormal * 2.0f * dot(WldMirrorNormal, Pos.xyz - WldMirrorPos);
    return Pos;
}

float3 CameraPosition : POSITION  < string Object = "Camera"; >;

// 鏡面表裏判定(座標とカメラが両方鏡面の表側にある時だけ＋)
float IsFace( float4 Pos )
{
    return min( dot(Pos.xyz-WldMirrorPos, WldMirrorNormal),
                dot(CameraPosition-WldMirrorPos, WldMirrorNormal) );
}

///////////////////////////////////////////////////////////////////////////////////////////////

// マテリアル色
float4   MaterialDiffuse   : DIFFUSE  < string Object = "Geometry"; >;
float3   MaterialAmbient   : AMBIENT  < string Object = "Geometry"; >;
float3   MaterialEmmisive  : EMISSIVE < string Object = "Geometry"; >;
float3   MaterialSpecular  : SPECULAR < string Object = "Geometry"; >;
float    SpecularPower     : SPECULARPOWER < string Object = "Geometry"; >;

// 座法変換行列
float4x4 WorldMatrix    : WORLD;
float4x4 ViewProjMatrix : VIEWPROJECTION;

#define PI 3.14159

float LightUp : CONTROLOBJECT < string name = "(self)"; string item = "LightUp"; >;
float LightUpE : CONTROLOBJECT < string name = "(self)"; string item = "LightUpE"; >;
float LightOff : CONTROLOBJECT < string name = "(self)"; string item = "LightOff"; >;
float Blink : CONTROLOBJECT < string name = "(self)"; string item = "LightBlink"; >;
float BlinkSq : CONTROLOBJECT < string name = "(self)"; string item = "LightBS"; >;
float BlinkDuty : CONTROLOBJECT < string name = "(self)"; string item = "LightDuty"; >;
float BlinkMin : CONTROLOBJECT < string name = "(self)"; string item = "LightMin"; >;

//時間
float ftime : TIME <bool SyncInEditMode = SYNC;>;

static float duty = (BlinkDuty <= 0) ? 0.5 : BlinkDuty;
static float timerate = ((Blink > 0) ? ((1 - cos(saturate(frac(ftime / (Blink * 10)) / (duty * 2)) * 2 * PI)) * 0.5) : 1.0)
                      * ((BlinkSq > 0) ? (frac(ftime / (BlinkSq * 10)) < duty) : 1.0);
static float timerate1 = timerate * (1 - BlinkMin) + BlinkMin;

static bool IsEmittion = (SPECULAR_BASE < SpecularPower)/* && (SpecularPower <= (SPECULAR_BASE + 100))*/ && (length(MaterialSpecular) < 0.01);
static float EmittionPower0 = IsEmittion ? ((SpecularPower - SPECULAR_BASE) / 7.0) : 1;
static float EmittionPower1 = EmittionPower0 * (LightUp * 2 + 1.0) * pow(400, LightUpE) * (1.0 - LightOff);


// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);


////////////////////////////////////////////////////////////////////////////////////////////////
// レンダリングターゲットのクリア値
float4 ClearColor = {0,0,0,0};
float ClearDepth  = 1.0;


#if MIPMAPTEX_SIZE==0
    #define MIPMAPSCRIPT    "RenderColorTarget0=;" \
                                "RenderDepthStencilTarget=;" \
                                "Pass=DrawObject;"
    
    #define CREATEMIPMAP
    
    // オブジェクトのテクスチャ
    texture ObjectTexture: MATERIALTEXTURE;
    sampler ObjTexSampler = sampler_state {
        texture = <ObjectTexture>;
        MINFILTER = LINEAR;
        MAGFILTER = LINEAR;
        MIPFILTER = LINEAR;
    };
    
#else
    #define MIPMAPSCRIPT    "RenderColorTarget0=UseMipmapObjectTexture;" \
                                "RenderDepthStencilTarget=MipDepthBuffer;" \
                                "ClearSetColor=ClearColor; Clear=Color;" \
                                "ClearSetDepth=ClearDepth; Clear=Depth;" \
                                "Pass=CreateMipmap;" \
                            "RenderColorTarget0=;" \
                                "RenderDepthStencilTarget=;" \
                                "Pass=DrawObject;"
    
    #define CREATEMIPMAP pass CreateMipmap < string Script= "Draw=Buffer;"; > { \
                                AlphaBlendEnable = FALSE; \
                                ZEnable = FALSE; \
                                VertexShader = compile vs_3_0 VS_MipMapCreater(); \
                                PixelShader  = compile ps_3_0 PS_MipMapCreater(); \
                            }
    
    // オブジェクトのテクスチャ
    texture ObjectTexture: MATERIALTEXTURE<
        int MipLevels = 0;
    >;
    sampler DefObjTexSampler = sampler_state {
        texture = <ObjectTexture>;
        MINFILTER = LINEAR;
        MAGFILTER = LINEAR;
    };
    
    texture2D MipDepthBuffer : RenderDepthStencilTarget <
        int Width = MIPMAPTEX_SIZE;
        int Height = MIPMAPTEX_SIZE;
        string Format = "D24S8";
    >;
    texture UseMipmapObjectTexture : RENDERCOLORTARGET <
        int Width = MIPMAPTEX_SIZE;
        int Height = MIPMAPTEX_SIZE;
        int MipLevels = 0;
        string Format = "A8R8G8B8" ;
    >;
    sampler ObjTexSampler = sampler_state {
        texture = <UseMipmapObjectTexture>;
        MINFILTER = ANISOTROPIC;
        MAGFILTER = ANISOTROPIC;
        MIPFILTER = LINEAR;
        MAXANISOTROPY = 16;
    };
    
    // テクセル位置のオフセット
    static float2 MipTexOffset = (float2(0.5,0.5)/MIPMAPTEX_SIZE);
    
#endif


////////////////////////////////////////////////////////////////////////////////////////////////
// ミップマップ作成

#if MIPMAPTEX_SIZE!=0
    struct VS_OUTPUT_MIPMAPCREATER {
        float4 Pos    : POSITION;
        float2 Tex    : TEXCOORD0;
    };
    VS_OUTPUT_MIPMAPCREATER VS_MipMapCreater( float4 Pos : POSITION, float4 Tex : TEXCOORD0 ){
        VS_OUTPUT_MIPMAPCREATER Out;
        Out.Pos = Pos;
        Out.Tex = Tex + MipTexOffset;
        return Out;
    }

    float4  PS_MipMapCreater(float2 Tex: TEXCOORD0) : COLOR0
    {
        return tex2D(DefObjTexSampler,Tex);
    }
    
#endif

///////////////////////////////////////////////////////////////////////////////////////////////

float texlight(float3 rgb){
    float val = saturate((length(rgb) - LightThreshold) * 3);
    
    val *= 0.2;
    
    return val;
}

///////////////////////////////////////////////////////////////////////////////////////////////
// 追加UVがAL用データかどうか判別

bool DecisionSystemCode(float4 SystemCode){
    bool val = (0.199 < SystemCode.r) && (SystemCode.r < 0.201)
            && (0.699 < SystemCode.g) && (SystemCode.g < 0.701);
    return val;
}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウOFF）

struct VS_OUTPUT {
    float4 Pos        : POSITION;    // 射影変換座標
    float4 Color      : COLOR0;      // 色
    float4 Tex        : TEXCOORD0;   // UV
    float4 WPos       : TEXCOORD1;   // 鏡像元のワールド座標
};


// 頂点シェーダ
VS_OUTPUT Basic_VS(float4 Pos : POSITION, float2 Tex : TEXCOORD0, 
                   float4 SystemCode : TEXCOORD1, float4 ColorCode : TEXCOORD2, float4 AppendCode : TEXCOORD2)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;
    bool IsALCode = DecisionSystemCode(SystemCode);
    
    // ワールド座標変換
    Pos = mul( Pos, WorldMatrix );
    Out.WPos = Pos; // ワールド座標
    
    // 鏡像位置への座標変換
    Pos = TransMirrorPos( Pos ); // 鏡像変換

    // カメラ視点のビュー射影変換
    Out.Pos = mul( Pos, ViewProjMatrix );
    Out.Pos.x *= -1.0f; // ポリゴンが裏返らないように左右反転にして描画
    
    // 発光色
    Out.Color = MaterialDiffuse;
    Out.Color.rgb += MaterialEmmisive / 2;
    Out.Color.rgb *= 0.5;
    Out.Color.rgb = IsEmittion ? Out.Color.rgb : float3(0,0,0);
    
    float3 UVColor = ColorCode.rgb * ColorCode.a;
    
    Out.Color.rgb += IsALCode ? UVColor : float3(0,0,0);
    
#if UseTrueCameraLX == 0
    float timerate2 = (SystemCode.z > 0) ? ((1 - cos(saturate(frac(ftime / SystemCode.z) / (duty * 2)) * 2 * PI)) * 0.5)
                     : ((SystemCode.z < 0) ? (frac(ftime / (-SystemCode.z )) < duty) : 1.0);
#else
    float timerate2 = (SystemCode.z > 0) ? ((1 - cos(saturate(frac((ftime + AppendCode.y) / SystemCode.z) / (duty * 2)) * 2 * PI)) * 0.5)
                     : ((SystemCode.z < 0) ? (frac((ftime + AppendCode.y) / (-SystemCode.z / PI * 180)) < duty) : 1.0);
#endif
    Out.Color.rgb *= max(timerate2 * (1 - BlinkMin) + BlinkMin, !IsALCode);
    Out.Color.rgb *= max(timerate1, SystemCode.z != 0);
    
    Out.Tex.xy = Tex; //テクスチャUV
    Out.Tex.w = IsALCode && (0.99 < SystemCode.w && SystemCode.w < 1.01);
    
    return Out;
}


// ピクセルシェーダ
float4 Basic_PS(VS_OUTPUT IN, uniform bool useTexture, uniform bool useToon) : COLOR0
{
    // 鏡面の裏側にある部位は鏡像表示しない
    clip( IsFace( IN.WPos ) );
    
    float4 Color = IN.Color;
    
    if(useTexture){
        #ifdef TEXTURE_SELECTLIGHT
            Color = tex2D(ObjTexSampler,IN.Tex.xy);
            Color.rgb *= texlight(Color.rgb);
        #else
            Color *= max(tex2D(ObjTexSampler,IN.Tex.xy), IN.Tex.w);
        #endif
    }
    
    if(useToon){
        Color.rgb *= EmittionPower1;
    }else{
        Color.rgb *= EmittionPower0;
    }
    
    return Color;
}

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画用テクニック
technique MainTec1 < string MMDPass = "object"; bool UseTexture = false; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS(false, false);
    }
}

technique MainTec2 < string MMDPass = "object"; bool UseTexture = true; bool UseToon = false; 
                     string Script = MIPMAPSCRIPT;
> {
    
    CREATEMIPMAP
    
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS(true, false);
    }
}

technique MainTec3 < string MMDPass = "object"; bool UseTexture = false; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS(false, true);
    }
}

technique MainTec4 < string MMDPass = "object"; bool UseTexture = true; bool UseToon = true; 
                     string Script = MIPMAPSCRIPT;
> {
    
    CREATEMIPMAP
    
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS(true, true);
    }
}


technique MainTecBS1 < string MMDPass = "object_ss"; bool UseTexture = false; bool UseToon = false; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS(false, false);
    }
}

technique MainTecBS2 < string MMDPass = "object_ss"; bool UseTexture = true; bool UseToon = false; 
                       string Script = MIPMAPSCRIPT;
 > {
    
    CREATEMIPMAP
    
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS(true, false);
    }
}

technique MainTecBS3 < string MMDPass = "object_ss"; bool UseTexture = false; bool UseToon = true; > {
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS(false, true);
    }
}

technique MainTecBS4 < string MMDPass = "object_ss"; bool UseTexture = true; bool UseToon = true; 
                       string Script = MIPMAPSCRIPT;
 > {
    
    CREATEMIPMAP
    
    pass DrawObject {
        VertexShader = compile vs_2_0 Basic_VS();
        PixelShader  = compile ps_2_0 Basic_PS(true, true);
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////
//影や輪郭は描画しない
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }

