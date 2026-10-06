
プロジェクターエフェクト（APNG版）
作成者：舞力介入P
ベース：そぼろさんのスポットライトエフェクトVer.2.0


スポットライトエフェクトに数行追加しただけのものです。
基本は、スポットライトエフェクトと同じですが、
指定したアニメーションAGIF/APNGの映像が、プロジェクタのように投影されます。


○使用方法
・SpotLight1_Object.fx内の"ANIMATEDTEXTURE"の箇所に読み込みたいファイルを指定してください。
・スポットライトエフェクトと同様、SpotLight1.xをMMDで読み込んでください。

○備考
・SpotLight1_Object.fx内のLightPower1の値を変えると、光量を変更できます。
・影のつき方に問題が有る場合、ShadowColor1, ShadowColor2を調節してください。

○更新履歴
・ver1.1 影のつき方が問題があったため修正
　　　　（コード中のShadowColor変数についてもテクスチャを適用）
・ver1.2 ShadowColor1,ShadowColor2の値を変更


○再生成について
・本エフェクトは、スポットライトエフェクトに数行追加しただけのものなので、
　SpotLightGenerator.exeで再生成したものに対して、同様の編集を行えば、
　同じ効果が得られます。

・変更箇所（変更ファイル：SpotLight1_Object.fx ）

※ 29行目付近 ※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※
   #include "CommonSystem.fx"
   
→ //追加部分
→ texture2D ShadowMask : ANIMATEDTEXTURE < string ResourceName = "laughing_man.png"; >;
→ sampler ShadowMaskSampler = sampler_state {
→     texture = <ShadowMask>;
→     MINFILTER = LINEAR;
→     MAGFILTER = LINEAR;
→ };
　 
※ 475行目付近 ※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※
        if ( useToon ) {
            // トゥーン適用
            comp = min(saturate(dot(IN.Normal,-LightDirection)*Toon),comp);
            ShadowColor.rgb *= MaterialToon;
        }
        
→      //追加部分
→      Color.rgb *= tex2D(ShadowMaskSampler,TransTexCoord).rgb;
→      ShadowColor.rgb *= tex2D(ShadowMaskSampler,TransTexCoord).rgb;
→      comp *= tex2D(ShadowMaskSampler,TransTexCoord).a;
→      SpotRate = dot(LightDirection, LightAxisDirection)<=0
→              || any( TransTexCoord != saturate(TransTexCoord) );
        
        Color = lerp(ShadowColor, Color, comp);
※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※※

