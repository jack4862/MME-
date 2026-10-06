////////////////////////////////////////////////////////////////////////////////////////////////
//
//  WorkingFloorAL.fx ver0.0.7  AutoLuminous�Ή��̏��ʋ����`��
//  �쐬: �j��P( ���͉��P����Mirror.fx, full.fx, ���ڂ뎁��AutoLuminous.fx���� )
//
////////////////////////////////////////////////////////////////////////////////////////////////
//�I�v�V�����X�C�b�`(AutoLuminous.fx�Ɠ����ݒ�ɂ��邱��)

//�������O�}�X�N���g�p����
//MME�^�u�� WF_MaskRT ������܂��B
//0���I�t�A1���I���ł�
#define MASK_ENABLE  0

//MMD��̕`���HDR���Ƃ��Ĉ����܂�
//���邳��1�𒴂��������������Č�����悤�ɂȂ�܂�
//0���I�t�A1���I���ł�
#define HDR_RENDER  1

//��Ɨp�o�b�t�@�̃T�C�Y�𔼕��ɂ��Čy�����܂�
//�掿�͗����܂�
//0���I�t�A1���I���ł�
#define HALF_DRAW  0


////////////////////////////////////////////////////////////////////////////////////
//�I�v�V�����X�C�b�`(WorkingFloorAL�ŗL�̐ݒ�)

// X�V���h�E�̕`������邩�ǂ���
// 0���I�t�A1���I���ł�
#define UseXShadow  1

float3 ShadowColor <      // X�e�̐F(RBG)
   string UIName = "X�e�F";
   string UIWidget = "Color";
   bool UIVisible =  true;
   float UIMin = 0.0;
   float UIMax = 1.0;
> = float3(0.247, 0.71, 0.827);

// ���ʃG�t�F�N�g�Ƃ��Ďg�p���邩
// 0�����ʋ����`��A1�����ʃG�t�F�N�g
#define UseMirror  0

// TrueCameraLX�Ŏg�p����
//0���I�t�A1���I���ł�
#define UseTrueCameraLX  0

// MMD�Ń��f������������ɕ`�悳��Ȃ��ꍇ�͂�����1�ɂ���
#define FLG_EXCEPTION  0


// ����Ȃ��l�͂������牺�͂�����Ȃ��ł�

////////////////////////////////////////////////////////////////////////////////////////////////

// ���W�ϊ��s��
float4x4 WorldMatrix     : WORLD;
float4x4 ViewMatrix      : VIEW;
float4x4 ProjMatrix      : PROJECTION;
float4x4 ViewProjMatrix  : VIEWPROJECTION;

//�J�����ʒu
float3 CameraPosition : POSITION  < string Object = "Camera"; >;

// ���ߒl
float AcsTr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;

// �X�N���[���T�C�Y
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5f, 0.5f)/ViewportSize;


#ifndef MIKUMIKUMOVING
    #if(FLG_EXCEPTION == 0)
        #define OFFSCREEN_FX_OBJECT  "WF_Object.fxsub"      // �I�t�X�N���[�������`��G�t�F�N�g
    #else
        #define OFFSCREEN_FX_OBJECT  "WF_ObjectExc.fxsub"   // �I�t�X�N���[�������`��G�t�F�N�g
    #endif
    #define ADD_HEIGHT   (0.05f)
    #define GET_VPMAT(p) (ViewProjMatrix)
#else
    #define OFFSCREEN_FX_OBJECT  "WF_Object_MMM.fxsub"      // �I�t�X�N���[�������`��G�t�F�N�g
    #define ADD_HEIGHT   (0.01f)
    #define GET_VPMAT(p) (MMM_IsDinamicProjection ? mul(ViewMatrix, MMM_DynamicFov(ProjMatrix, length(CameraPosition-p.xyz))) : ViewProjMatrix)
#endif


//�e�N�X�`���t�H�[�}�b�g
#if HDR_RENDER==0
    #define AL_TEXFORMAT "A8R8G8B8"
#else
    //#define AL_TEXFORMAT "A32B32G32R32F"
    #define AL_TEXFORMAT "A16B16G16R16F"
#endif

#if HALF_DRAW==0
    #define TEXSIZE1  1
#else
    #define TEXSIZE1  0.5
#endif

#if UseMirror==0
    #define BUFF_COLOR  { 0, 0, 0, 0 }
#else
    #define BUFF_COLOR  { 0, 0, 0, 1 }
#endif


// ���ʋ����`��̃I�t�X�N���[���o�b�t�@
shared texture WorkingFloorRT : OFFSCREENRENDERTARGET <
    string Description = "OffScreen RenderTarget for WorkingFloorAL.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = BUFF_COLOR;
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    string Format = AL_TEXFORMAT;
    string DefaultEffect = 
        "self = hide;"
        "*Luminous.x = hide;"
        "ToneCurve.x = hide;"
        "WorkingFloor*.x = hide;"
        "* =" OFFSCREEN_FX_OBJECT ";"
    ;
>;
sampler WorkingFloorView = sampler_state {
    texture = <WorkingFloorRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};


// �������̋����`��̃I�t�X�N���[���o�b�t�@
shared texture WF_EmitterRT : OFFSCREENRENDERTARGET <
    string Description = "EmitterDrawRenderTarget for WorkingFloorAL.fx";
    float2 ViewPortRatio = {TEXSIZE1,TEXSIZE1};
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    int MipLevels = 1;
    string Format = AL_TEXFORMAT;
    string DefaultEffect = 
        "self = hide;"
        "*Luminous.x = hide;"
        "ToneCurve.x = hide;"
        "WorkingFloor*.x = hide;"
        "* = WF_ObjectEmit.fxsub;"
    ;
>;

////////////////////////////////////////////////////////////////////////////////////////////////
// ���ʃ}�X�N�`���I�t�X�N���[���o�b�t�@

#if(MASK_ENABLE != 0)

shared texture WF_MaskRT : OFFSCREENRENDERTARGET <
    string Description = "MaskDrawRenderTarget for WorkingFloorAL.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = true;
    int MipLevels = 1;
    string Format = "D3DFMT_A8R8G8B8";
    string DefaultEffect = 
        "self = hide;"
        "* = hide;"
    ;
>;

#endif

////////////////////////////////////////////////////////////////////////////////////////////////
// X�e�`��Ɏg���I�t�X�N���[���o�b�t�@

#if(UseXShadow != 0)

texture FloorXShadowRT : OFFSCREENRENDERTARGET <
    string Description = "XShadowDrawRenderTarget for WorkingFloorAL.fx";
    float2 ViewPortRatio = {1.0,1.0};
    float4 ClearColor = { 0, 0, 0, 0 };
    float ClearDepth = 1.0;
    bool AntiAlias = false;
    int MipLevels = 1;
    string Format = "D3DFMT_A8R8G8B8";
    string DefaultEffect = 
        "self = hide;"
        "*.pmd = WF_XShadow.fxsub;"
        "*.pmx = WF_XShadow.fxsub;"
        "* = hide;"
    ;
>;
sampler XShadowSmp = sampler_state {
    texture = <FloorXShadowRT>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

#endif


////////////////////////////////////////////////////////////////////////////////////////////////
// TrueCameraLX�p�[�x�t���x���V�e�B�}�b�v�쐬�Ɏg���I�t�X�N���[���o�b�t�@

//�x���V�e�B�}�b�v�o�b�t�@�t�H�[�}�b�g
#define VM_TEXFORMAT "A32B32G32R32F"
//#define VM_TEXFORMAT "A16B16G16R16F"

#define VPRATIO 1.0

#if(UseTrueCameraLX != 0)

shared texture WF_DVMapDraw : OFFSCREENRENDERTARGET <
    string Description = "Depth && Velocity Map Drawing for WorkingFloorAL.fx";
    float2 ViewPortRatio = {VPRATIO,VPRATIO};
    float4 ClearColor = { 0.5, 0.5, 100, 1 };
    float ClearDepth = 1.0;
    string Format = VM_TEXFORMAT ;
    bool AntiAlias = false;
    int MipLevels = 1;
    string DefaultEffect = 
        "self = hide;"
        "* = WF_TCLXObject.fxsub;"
        ;
>;

#endif


////////////////////////////////////////////////////////////////////////////////////////////////
//���ʋ����`��

struct VS_OUTPUT {
    float4 Pos  : POSITION;
    float4 VPos : TEXCOORD1;
};

VS_OUTPUT VS_Mirror(float4 Pos : POSITION)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    Pos = mul( Pos, WorldMatrix );
    Pos.y += ADD_HEIGHT;  // ���Əd�Ȃ��Ă�����̂�������邽��

    // �J�������_�̃r���[�ˉe�ϊ�
    Pos = mul( Pos, GET_VPMAT(Pos) );

    Out.Pos = Pos;
    Out.VPos = Pos;

    return Out;
}

float4 PS_Mirror(VS_OUTPUT IN) : COLOR
{
    // �����̃X�N���[���̍��W(���E���]���Ă���̂Ō��ɖ߂�)
    float2 texCoord = float2( 1.0f - ( IN.VPos.x/IN.VPos.w + 1.0f ) * 0.5f,
                              1.0f - ( IN.VPos.y/IN.VPos.w + 1.0f ) * 0.5f ) + ViewportOffset;

    // �����̐F
    float4 Color = tex2D(WorkingFloorView, texCoord);
    Color.a *= AcsTr;

    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////
// X�e�`��

#if(UseXShadow != 0)

// ���_�V�F�[�_
VS_OUTPUT VS_XShadow(float4 Pos : POSITION)
{
    VS_OUTPUT Out = (VS_OUTPUT)0;

    Pos = mul( Pos, WorldMatrix );
    Pos.y += ADD_HEIGHT;  // ���Əd�Ȃ��Ă�����̂�������邽��

    // �J�������_�̃r���[�ˉe�ϊ�
    Out.Pos = mul( Pos, GET_VPMAT(Pos) );
    Out.VPos = mul( Pos, ViewProjMatrix );

    return Out;
}


// X�e�`��
float4 PS_XShadow(VS_OUTPUT IN) : COLOR
{
    // X�e�̃X�N���[���̍��W
    float2 texCoord = float2( ( IN.VPos.x/IN.VPos.w + 1.0f ) * 0.5f,
                              1.0f - ( IN.VPos.y/IN.VPos.w + 1.0f ) * 0.5f ) + ViewportOffset;
    float4 Color = tex2D(XShadowSmp, texCoord);
    Color.a = Color.r;
    Color.rgb = ShadowColor;

    return Color;
}

#endif

////////////////////////////////////////////////////////////////////////////////////////////////
//�e�N�j�b�N

technique MainTec0 < string MMDPass = "object"; > {
    pass DrawObject{
        VertexShader = compile vs_2_0 VS_Mirror();
        PixelShader  = compile ps_2_0 PS_Mirror();
    }
    #if(UseXShadow != 0)
    pass DrawXShadow{
        VertexShader = compile vs_2_0 VS_XShadow();
        PixelShader  = compile ps_2_0 PS_XShadow();
    }
    #endif
}

technique MainTec1 < string MMDPass = "object_ss"; > {
    pass DrawObject{
        VertexShader = compile vs_2_0 VS_Mirror();
        PixelShader  = compile ps_2_0 PS_Mirror();
    }
    #if(UseXShadow != 0)
    pass DrawXShadow{
        VertexShader = compile vs_2_0 VS_XShadow();
        PixelShader  = compile ps_2_0 PS_XShadow();
    }
    #endif
}

////////////////////////////////////////////////////////////////////////////////////////////////

//�e��֊s�͕`�悵�Ȃ�
technique EdgeTec < string MMDPass = "edge"; > { }
technique ShadowTec < string MMDPass = "shadow"; > { }
technique ZplotTec < string MMDPass = "zplot"; > { }




