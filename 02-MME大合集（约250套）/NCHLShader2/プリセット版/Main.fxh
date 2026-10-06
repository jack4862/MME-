// ここから先は分かる人のみ
///////////////////////////////////////////////////////////////////////////////////////////////

// オブジェクトのテクスチャ
texture ObjectTexture: MATERIALTEXTURE;
sampler ObjTexSampler = sampler_state {
    texture = <ObjectTexture>;
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
};

// ノーマルマップ&スペキュラマップ用テクスチャ
texture SubTexure: MATERIALSPHEREMAP;
sampler SubTexSampler = sampler_state {
    texture = <SubTexure>;
    MINFILTER = ANISOTROPIC;
    MAGFILTER = ANISOTROPIC;
    MIPFILTER = LINEAR;
    MAXANISOTROPY = 16;
    ADDRESSU = CLAMP;
    ADDRESSV = CLAMP;
};

// MMD本来のsamplerを上書きしないための記述です。削除不可。
sampler MMDSamp0 : register(s0);
sampler MMDSamp1 : register(s1);
sampler MMDSamp2 : register(s2);

// SSAOのテクスチャ
shared texture2D SSAO_Tex3 : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    int MipLevels = 0;
    string Format = "D3DFMT_R16F";
>;
sampler2D SSAOSamp = sampler_state {
    texture = <SSAO_Tex3>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = LINEAR;
    AddressU = CLAMP;
    AddressV = CLAMP;
};

// スクリーンシャドウマップ取得
shared texture2D ScreenShadowMapProcessed : RENDERCOLORTARGET <
    float2 ViewPortRatio = {1,1};
    int MipLevels = 1;
    string Format = "D3DFMT_R16F";
>;
sampler2D ScreenShadowMapProcessedSamp = sampler_state {
    texture = <ScreenShadowMapProcessed>;
    MinFilter = LINEAR; MagFilter = LINEAR; MipFilter = NONE;
    AddressU  = CLAMP; AddressV = CLAMP;
};

////////////////////////////////////////////////////////////////////////////////////////////////
// 輪郭描画
// 輪郭描画用テクニック
//technique EdgeTec < string MMDPass = "edge"; > {}
// ↑コメントアウトすればエッジ使用可能。

///////////////////////////////////////////////////////////////////////////////////////////////
// セルフシャドウ用Z値プロット
// Z値プロット用テクニック
//technique ZplotTec < string MMDPass = "zplot"; > {}
// コメントアウトを外すと影を落とさない

////////////////////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////
// オブジェクト描画（セルフシャドウON）

struct BufferShadow_INPUT {
    float4 Pos      : POSITION;     // 射影変換座標
    float2 Tex      : TEXCOORD;     // テクスチャ
    float3 Normal   : NORMAL;       // 法線
};

struct BufferShadow_OUTPUT {
    float4 Pos      : POSITION;     // 射影変換座標
    float4 ZCalcTex : TEXCOORD0;    // Z値
    float2 Tex      : TEXCOORD1;    // テクスチャ
    float3 Normal   : TEXCOORD2;    // 法線
    float3 Eye      : TEXCOORD3;    // カメラとの相対位置
    float4 Pos2     : TEXCOORD4;    // SSAO用
    float4 ScreenTex : TEXCOORD5;   // セルフシャドウ用
};

// 頂点シェーダ
BufferShadow_OUTPUT BufferShadow_VS(BufferShadow_INPUT IN, uniform bool useTexture)
{
    BufferShadow_OUTPUT Out = (BufferShadow_OUTPUT)0;

    // カメラ視点のワールドビュー射影変換
    Out.Pos = Out.Pos2 = mul( IN.Pos, WorldViewProjMatrix );
    
    // カメラとの相対位置
    Out.Eye = CameraPosition - mul( IN.Pos, WorldMatrix );

    // 頂点法線
    // 方向ライトしか使わないから変換しなくても結果は同じ?ぶっちゃけ良く分かってない
    //Out.Normal = ( mul( IN.Normal, WorldMatrix ) ); 
    Out.Normal = IN.Normal;

    // ライト視点によるワールドビュー射影変換
    Out.ZCalcTex = mul( IN.Pos, LightWorldViewProjMatrix );
         
    // テクスチャ座標
    Out.Tex = IN.Tex;

    //スクリーン座標取得
    Out.ScreenTex = Out.Pos;
    
    //超遠景におけるちらつき防止
    Out.Pos.z -= max(0, (int)((CameraDistance1 - 6000) * 0.04));

    return Out;
}

// 接空間取得
inline float3x3 compute_tangent_frame(float3 Normal, float3 View, float2 UV)
{
    float3 dp1 = ddx(View);
    float3 dp2 = ddy(View);
    float2 duv1 = ddx(UV);
    float2 duv2 = ddy(UV);

    float3x3 M = float3x3(dp1, dp2, cross(dp1, dp2));
    float2x3 inverseM = float2x3(cross(M[1], M[2]), cross(M[2], M[0]));
    float3 Tangent = mul(float2(duv1.x, duv2.x), inverseM);
    float3 Binormal = mul(float2(duv1.y, duv2.y), inverseM);

    return float3x3(normalize(Tangent), normalize(Binormal), Normal);
}

// Beckmann分布関数
inline float Beckmann(float m, float NH)
{
    float NH2 = NH*NH;
    return exp(-(1-NH2)/(NH2*m*m))/(4.0f*m*m*NH2*NH2);    
}

inline float Pow5(float n)
{
    return n*n*n*n*n;
}

// ピクセルシェーダ
float4 BufferShadow_PS(BufferShadow_OUTPUT IN, uniform const bool useTexture, uniform const bool useNormalMap) : COLOR
{

    // 視線ベクトル、ライトベクトル、法線ベクトル
    float3 Vn = normalize(IN.Eye);
    float3 Ln = normalize(-LightDirection);
    float3 Nn;

    // スペキュラマップ
    float SpecularMapVal = 1;

    // ノーマルマップ&スペキュラマップ適用
    if (useNormalMap) {
        float3x3 tangentFrame = compute_tangent_frame(IN.Normal, IN.Eye, IN.Tex);
        Nn = normalize( mul(2.0f * tex2D(SubTexSampler, IN.Tex) - 1, tangentFrame) );
        SpecularMapVal = tex2D(SubTexSampler,IN.Tex).a;
    } else {
        Nn = normalize(IN.Normal);
    }

    // リム関連
    float RimPower = max(0,dot(Vn,-Ln));
    float NV = dot(Nn, Vn);

    // 両面材質で、面がカメラ側を向いているかどうか(あまり機能してないっぽい)
    bool face = MaterialDiffuse.a < 0.99 && NV < 0 ? 0 : 1;

    // テクスチャ適用
    if (useTexture) {
        float4 TexColor = tex2D(ObjTexSampler, IN.Tex); 
        AmbientColor *= TexColor;
        DiffuseColor *= TexColor;
    }

    // ランバート、ハーフランバート、陰影補正用
    float LN = dot(Ln,Nn);
    float HLambert =LN*0.5f+0.5f;
    float ToonShade = smoothstep(SHADING_MIN, SHADING_MAX, HLambert);

    // セルフシャドウ
    IN.ScreenTex.xyz /= IN.ScreenTex.w;
    float2 TransScreenTex;
    TransScreenTex.x = (1 + IN.ScreenTex.x) * 0.5f;
    TransScreenTex.y = (1 - IN.ScreenTex.y) * 0.5f;
    TransScreenTex += ViewportOffset;
    float ShadowMapVal = saturate(tex2D(ScreenShadowMapProcessedSamp, TransScreenTex).r);

    // 陰影合成
    float comp = lerp(ToonShade,ShadowMapVal*ToonShade,ShadowStrength*(1-ShadowMapVal));
    float3 Diffuse = DiffuseColor*comp;

    // SSAO取得
    float2 uv = IN.Pos2.xy / IN.Pos2.w;
    uv = uv * float2( 0.5, -0.5 ) + float2( 0.5, 0.5 ) + ViewportOffset;
    float ao = tex2D( SSAOSamp, uv ).r;

    // 影の中はAOが濃くなり過ぎないようにする
    float3 aoColor = lerp(ao,sqrt(ao),1-comp);
    aoColor = lerp(MaterialToon*DiffuseColor,aoColor,aoColor);

    // でたらめ環境光
    float Amblamb = dot(Ln,(cross(Vn,Nn)))*0.5+0.5;
    float3 AmbLight = lerp(AmbLightColor0*(Amblamb*Amblamb),AmbLightColor1*(1-Amblamb),1-Amblamb)*AmbLightPower.rrr;

    // 半球ライティング
    float SdN = dot(SKYDIR,Nn)*0.5f+0.5f;
    float3 Hemisphere = lerp(GROUNDCOLOR, SKYCOLOR, SdN*SdN);

    // バックライト的な何か
    float BackHlamb = BackLightColor*(dot(-Ln,Nn)*0.5f+0.5f);
    float3 BackLight = BackLightColor*BackHlamb*BackHlamb*BackLightPower.rrr;

    // アンビエント合成
    float3 Ambient = aoColor*(BackLight+(AmbLight*Hemisphere))*0.1;

    // スペキュラ
    float3 Hn = normalize(Vn + Ln);
    float  NH = dot(Nn, Hn);
    float  VH = dot(Vn, Hn);
    float D = Beckmann(ROUGHNESS, NH);
    float G = min( 1, min(2*NH*NV/VH, 2*NH*LN/VH) );
    float F = lerp( FRESNEL, 1, 1-Pow5(dot(Ln, Hn)) );
    float3 Specular = max(0, F*D*G/NV)*LightAmbient*ShadowMapVal*SPECULAR_EXTENT;
 
    // でたらめ光沢
    // スフィアマップや環境マップでもいい気がする・・・
    float3 Gloss = (0,0,0);
    float3 Hn_I = normalize(Vn - Ln);
    float  NH_I = dot(Nn, Hn_I);
    float  VH_I = dot(Vn, Hn_I);
    float G_I = min( 1, min(-2*NH_I*NV/VH_I, -2*NH_I*LN/VH_I) );

    if ( GLOSS_EXTENT > 1 )  {
        Gloss = LightAmbient*Ambient*(saturate(0.5-(1-G_I)*(2+G_I)))*(GLOSS_EXTENT-1);  
    } else if ( GLOSS_EXTENT != 0 ) {
        Gloss = LightAmbient*Ambient*GLOSS_TYPE;
    }

    Ambient *= AmbientColor;

    // 適当リムライティング
    float Rim = saturate(1-NV*1.5);
    float3 RimLight = (Rim*lerp(comp*saturate(1-BackHlamb)*BackLight,LightAmbient*SUBCOLOR*D,RimPower)*RIM_STRENGTH);

    // なんちゃって表面下散乱
    float Sublamb = smoothstep(-0.3,1.0,HLambert) - smoothstep(0.0,1.1,HLambert);
    float3 Subsurface = DiffuseColor*SUBCOLOR*(Sublamb.rrr*SUBDEPTH)*sqrt(Rim*0.5+0.5);
    Subsurface *= lerp(SUBDEPTH/100, 1, Diffuse);

    // 最終合成
    float4 Color = float4(Diffuse+Ambient+saturate(SpecularMapVal*(Specular+Gloss)+max(Subsurface,RimLight))*face,DiffuseColor.a);
    //if( transp ) Color.a = 0.5f;

    return Color;
}

// オブジェクト描画用テクニック
technique MainTecBS0  < string MMDPass = "object_ss"; bool UseTexture = false;> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(false);
        PixelShader  = compile ps_3_0 BufferShadow_PS(false,false);
    }
}

technique MainTecBS1  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = false;> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true,false);
    }
}

technique MainTecBS2  < string MMDPass = "object_ss"; bool UseTexture = true; bool UseSphereMap = true;> {
    pass DrawObject {
        VertexShader = compile vs_3_0 BufferShadow_VS(true);
        PixelShader  = compile ps_3_0 BufferShadow_PS(true,true);
    }
}