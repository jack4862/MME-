#define CONTROLLER "fluid2DController.pmx"
float mAreaSize : CONTROLOBJECT < string name = CONTROLLER; string item = "SAd2_範囲"; >;
float mDebug : CONTROLOBJECT < string name = CONTROLLER; string item = "SAd2_テスト"; >;
float mR : CONTROLOBJECT < string name = CONTROLLER; string item = "SAd2_R"; >;
float mG : CONTROLOBJECT < string name = CONTROLLER; string item = "SAd2_G"; >;
float mB : CONTROLOBJECT < string name = CONTROLLER; string item = "SAd2_B"; >;
float mScale : CONTROLOBJECT < string name = CONTROLLER; string item = "SAd2_大きさ"; >;
float mCoef : CONTROLOBJECT < string name = CONTROLLER; string item = "SAd2_量"; >;
float mSpecularScale : CONTROLOBJECT < string name = CONTROLLER; string item = "スペキュラ強さ"; >;


#include "Splash_Addon.fxsub"