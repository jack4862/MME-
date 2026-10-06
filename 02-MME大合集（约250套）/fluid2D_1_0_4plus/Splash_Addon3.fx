#define CONTROLLER "fluid2DController.pmx"
float mAreaSize : CONTROLOBJECT < string name = CONTROLLER; string item = "SAd3_範囲"; >;
float mDebug : CONTROLOBJECT < string name = CONTROLLER; string item = "SAd3_テスト"; >;
float mR : CONTROLOBJECT < string name = CONTROLLER; string item = "SAd3_R"; >;
float mG : CONTROLOBJECT < string name = CONTROLLER; string item = "SAd3_G"; >;
float mB : CONTROLOBJECT < string name = CONTROLLER; string item = "SAd3_B"; >;
float mScale : CONTROLOBJECT < string name = CONTROLLER; string item = "SAd3_大きさ"; >;
float mCoef : CONTROLOBJECT < string name = CONTROLLER; string item = "SAd3_量"; >;
float mSpecularScale : CONTROLOBJECT < string name = CONTROLLER; string item = "スペキュラ強さ"; >;


#include "Splash_Addon.fxsub"