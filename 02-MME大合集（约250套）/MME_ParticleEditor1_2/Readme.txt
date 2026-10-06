MME_ParticleEditor

http://www.nicovideo.jp/watch/sm12149815
に紹介されているサンプルエフェクトの、FireParticleSystem,FireParticleSystemEx_V20
をカスタマイズするための道具です。
fxファイルの中身が読めない方でも,
必要なパラメータだけカスタマイズできます。

■ファイル構成
MME_SimpleParticleEditor.exe ツール本体
Readme.txt　このファイル

■使い方
1：MME_ParticleEditor.exeを起動してください。
2：生成されたParticle1.xをMMDに読み込んでください。
　　GUI上のファイル名をドラッグ＆ドロップでもOKです。
3：スライダを適当に調整するとMMDに読み込んだパーティクルに反映されます
4：イメージどおりのパーティクルが完成したら、
　　Particle1.fx
    Particle1.tga
    Particle1.x
の3つを適当なフォルダにコピーして保存してください。

■ちょっと高度な使い方
右上の>>ボタンを押すと、スライダーの上限、下限を拡張できます。

■Ver1.1からの変更
- ParticleSystemExを、シェーダ２．０に対応したParticleSystemEx_VS20に変更しました。
今までExのみ動作しなかった方でも使えるようになりました。
また、これによりアクセサリファイル（Particle.x）をParticleSystemEx_VS20のものに変更したため、
従来のパラメータと同じ設定をしても、違う形になる場合がありますがご了承下さい。
- 上書きボタン、自動更新チェックボックスの廃止
起動すると同時に、自動更新状態になります。
設定を開始する前、または設定が完了して、アプリケーションを終了する前に、
ファイル名を変更しておくように注意してください。
- フォルダを開くボタン追加
調整中のパーティクルファイルは、アプリケーションと同じフォルダに生成されます。
うっかりアプリケーションのフォルダを閉じてしまった場合、このボタンを押してください。

■参考
MME
http://www.nicovideo.jp/watch/sm12149815
パターン
http://www.nicovideo.jp/watch/sm12208618

■FAQ、アップデート情報等
http://www23.atwiki.jp/pit_shan/pages/20.html

PiT