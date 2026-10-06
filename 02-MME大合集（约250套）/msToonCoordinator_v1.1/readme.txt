■msToonCoordinator
　■ver.1.1
　■作者：ましまし（@Mashimashi_mmd）


■概要
　他のエフェクトの結果をもとにトゥーン化するポストエフェクト。
　詳しい使い方や解説は下記noteをご参照ください。
  https://note.com/notes/na1bc7c72e511

■規約
　エフェクト自体の使用・改変・再配布は自己責任で実行してください。


■使い方
  1) MMDでの準備
     Shade.xとEdge.x、そぼろさんのExcellentShadow.xを読み込む
     msToonCoordinatorController.pmxとdefault.vmdを読み込む
     （default.vmdを読み込むとMMDが落ちる場合、MMDの[ファイル]メニューから[モーションデータ読込]で読み込んでみて下さい）

  2) MMEの「エフェクト割当」での準備
     mainタブで(default)とPMXモデルにSimplePaint_EgeOff.fxを割り当てる
     mainタブでExcellentShadow.xのチェックをOFFにする
     msTC_ShadeRTタブでExcellentShadow.xのチェックをONにする


■コントローラーのパラメータ
　　■調整用:
　　　効果の確認用です。
　　　１段目：ベース色、すなわちShade.xとEdge.xを無効化した元の絵を表示。
　　　２段目：msTC_ShadeRTタブの状態。
　　　３段目：msTC_SublightRTタブの状態。
　　　４段目：msTC_EdgeRTタブの状態。


■謝辞
　このエフェクトはそぼろさんの基礎エフェクトセット Ver.3.0をもとに作成しました。
　また、他のエフェクトとの併用を前提としたエフェクトです。
  そぼろさんをはじめ、各エフェクト配布者の方々に感謝を申し上げます。


■その他
　不具合などがあればTwitterやマシュマロちゃんでご連絡ください。
　動画などのコメントでもいつか気づくと思います。


■更新履歴
　2021/04/24 ver.1.0
　一般配布

  2021/04/25 ver.1.1
  default.vmdを読み込むとMMDが落ちる現象をたぶん修正し、上記「使い方」に注意を付記しました（P.I.Pさん、less.さん、グレイさん、丘の上のでち公さんありがとうございます）
  EdgeフォルダのEdge〇〇.fxにあった「Gチャンネル：エッジ色の出にくさ」の説明を削除しました。実際はGチャンネルは何も使っていません。ごめん。