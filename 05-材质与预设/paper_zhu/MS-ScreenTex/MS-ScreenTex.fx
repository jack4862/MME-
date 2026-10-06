////////////////////////////////////////////////////////////////////////////////////////////////
//
//  MS-ScreenTex.fx ver1.0.0 
//  ÖÆ×ö: MoePus 2016.11.25
//  ˆDÆ¬£ºSuven  2016.11.19
//
////////////////////////////////////////////////////////////////////////////////////////////////
float Script : STANDARDSGLOBAL <
    string ScriptOutput = "color";
    string ScriptClass = "sceneorobject";
    string ScriptOrder = "postprocess";
> = 0.8;
float SI : CONTROLOBJECT < string name = "(self)"; string item = "Si"; >;
float TR : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; >;
float3 Rxyz			: CONTROLOBJECT < string name = "(self)"; string item="Rxyz"; >;
static float Ry = Rxyz.y*180/3.1415926;
static float Rz = Rxyz.z*180/3.1415926;
float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = float2(0.5,0.5)/ViewportSize;
float4 ClearColor = {0,0,0,1};
float ClearDepth  = 1.0;
texture2D bg <
    string ResourceName = "camera.png";
>;
sampler bgSampler = sampler_state {
    texture = <bg>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture2D maru <
    string ResourceName = "red.png";
>;
sampler maruSampler = sampler_state {
    texture = <maru>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture2D battery0 <
    string ResourceName = "battery1.png";
>;
sampler battery0Sampler = sampler_state {
    texture = <battery0>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};
texture2D battery1 <
    string ResourceName = "battery31.png";
>;
sampler battery1Sampler = sampler_state {
    texture = <battery1>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D battery2 <
    string ResourceName = "battery83.png";
>;
sampler battery2Sampler = sampler_state {
    texture = <battery2>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

texture2D battery3 <
    string ResourceName = "battery100.png";
>;
sampler battery3Sampler = sampler_state {
    texture = <battery3>;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
    MipFilter = NONE;
    AddressU  = CLAMP;
    AddressV = CLAMP;
};

////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_OUTPUT {
    float4 Pos			: POSITION;
    float2 Tex			: TEXCOORD0;
};

VS_OUTPUT VS_ScreenTex( float4 Pos : POSITION, float4 Tex : TEXCOORD0 )
{
    VS_OUTPUT Out = (VS_OUTPUT)0; 

    Out.Pos = Pos;
    Out.Tex = Tex + ViewportOffset;

    return Out;
}

float ftime : TIME <bool SyncInEditMode = false;>;
static bool maruVisi = SI>=0?cos(ftime*3.1415926*SI/10)>=0:0;
static bool lowBatteryVisi = Ry>=0?cos((ftime+Rz)*3.1415926*Ry)>=0:0;


float4 PS_ScreenTex( float2 Tex: TEXCOORD0 ) : COLOR
{
    float4 bg = tex2D( bgSampler, Tex );
    float4 maru = tex2D( maruSampler, Tex );
    float4 battery0 = tex2D( battery0Sampler, Tex );
    float4 battery1 = tex2D( battery1Sampler, Tex );
    float4 battery2 = tex2D( battery2Sampler, Tex );
    float4 battery3 = tex2D( battery3Sampler, Tex );

	float4 Color = bg;
	if(TR<0.25)
		{
		if(lowBatteryVisi)
		{		
		Color.rgb = (1-battery0.a)*Color.rgb + battery0.a * battery0.rgb;
		Color.a = max(battery0.a,Color.a);
		}
		}
	else if(TR<0.5)
		{
		Color.rgb = (1-battery1.a)*Color.rgb + battery1.a * battery1.rgb;
		Color.a = max(battery1.a,Color.a);
		}
	else if(TR<0.85)
		{
		Color.rgb = (1-battery2.a)*Color.rgb + battery2.a * battery2.rgb;
		Color.a = max(battery2.a,Color.a);
		}
	else
		{
		Color.rgb = (1-battery3.a)*Color.rgb + battery3.a * battery3.rgb;
		Color.a = max(battery3.a,Color.a);
		}

	if(maruVisi)
		{
		Color.rgb = (1-maru.a)*Color.rgb + maru.a * maru.rgb;
		Color.a = max(maru.a,Color.a);
		}
		
    return Color;
}

////////////////////////////////////////////////////////////////////////////////////////////////

technique ScreenTexTech <
    string Script = 
        "RenderColorTarget0=;"
	    "RenderDepthStencilTarget=;"
            "ClearSetColor=ClearColor;"
            "ClearSetDepth=ClearDepth;"
            "Clear=Color; Clear=Depth;"
            "ScriptExternal=Color;"
	    "Pass=ScreenTexPass;"
    ;
> {
    pass ScreenTexPass < string Script= "Draw=Buffer;"; > {
        AlphaBlendEnable = TRUE;
        VertexShader = compile vs_3_0 VS_ScreenTex();
        PixelShader  = compile ps_3_0 PS_ScreenTex();
    }
}
////////////////////////////////////////////////////////////////////////////////////////////////

