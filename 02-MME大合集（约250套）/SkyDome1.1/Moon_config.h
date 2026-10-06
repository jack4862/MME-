////////////////////////////////////////////////////////////////////////////////////////////////
// 月の設定
////////////////////////////////////////////////////////////////////////////////////////////////
// パラメータ //
// 月の色
float4 MoonColor = {1, 1, 1, 1};

// 月のグラデーション(太陽を利用)
texture texMoon< string ResourceName = "SunGradation.jpg"; >;
sampler smpMoon = sampler_state{
	Texture = <texMoon>;
	Filter = LINEAR; ADDRESSU = CLAMP; ADDRESSV = CLAMP;
};

// 月の満ち欠け用ベクトル
float3 WaWMoonDir = {0.0,0.0,-1.0};	// 満月
//float3 WaWMoonDir = {0.0,0.0,1.0};	// 新月
//float3 WaWMoonDir = {0.5,0.3,0.3};	// 三日月
//float3 WaWMoonDir = {0.5,0.3,0.1};	// 半月

// 満ち欠け用法線テクスチャ
texture texMoonNormal< string ResourceName = "MoonNormal.jpg"; >;
sampler smpMoonNormal = sampler_state{
	Texture = <texMoonNormal>;
	Filter = LINEAR; ADDRESSU = CLAMP; ADDRESSV = CLAMP;
};