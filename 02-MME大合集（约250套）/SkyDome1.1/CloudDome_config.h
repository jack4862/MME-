////////////////////////////////////////////////////////////////////////////////////////////////
// ドーム状の雲の設定
////////////////////////////////////////////////////////////////////////////////////////////////
// 雲の色
float4 CloudColor = {1,1,1,1};
// 夜になったときの暗さ
float Dark = 0.2;
// 変化方向と速度
float2 SpeedDir = {0.4, 0.0};
// 雲テクスチャのスクロール速度
float3 CloudMix = {1, 0.5, 0.25};
// 雲の密度
float CloudDens = 0.5;
// 雲の色の強さ
float CloudVolume = 10;
// 雲テクスチャループ数
float CloudTexDens = 1;

// サイズ補正
float SkyDomeScale : CONTROLOBJECT < string name = "SkyDome.x"; >;
static float Scale = SkyDomeScale*0.1*0.8;


////////////////////////////////////////////////////////////////////////////////////////////////
// 詳細な設定 //
// 雲テクスチャ
texture texSample1 < string ResourceName = "Cloud1.jpg"; >;
sampler smpSample1 = sampler_state {
	texture = <texSample1>;	Filter=LINEAR;	ADDRESSU = WRAP; ADDRESSV = WRAP; };
texture texSample2 < string ResourceName = "Cloud2.jpg"; >;
sampler smpSample2 = sampler_state {
	texture = <texSample2>;	Filter=LINEAR;	ADDRESSU = WRAP; ADDRESSV = WRAP; };
texture texSample3 < string ResourceName = "Cloud3.jpg"; >;
sampler smpSample3 = sampler_state {
	texture = <texSample3>;	Filter=LINEAR;	ADDRESSU = WRAP; ADDRESSV = WRAP; };