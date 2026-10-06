Particle_RayBokeh

#介绍说明
化身バレッタ配布的【空中に漂う埃】实际上是从そぼろ配布的【WorldSnow】特效更改出来的粒子特效
但是化身バレッタ从把原来附带的粒子控制器删除了，导致控制粒子变得麻烦了一些
因此我将两个MME重新整合回一起，并制作与ray景深共用形成六边形粒子的预设。
使用的Ray版本为1.5.2

#文件介绍
\Readme					记录了原版本作者的MME
\Vmd					包含原WorldSnow中默认粒子控制器预设
0X Particle_X.vmd		各种粒子预设控制器数据
Particle_RayBokeh.x		粒子特效文件
Particle_RayBokeh.fx	粒子特效文件
Particle_RayBokeh.pmx	粒子控制器

#使用方法
0.在ray.conf里第73行开启bokeh功能，并在MMD中载入Ray-MMD渲染环境
1.导入Particle_RayBokeh.x和Particle_RayBokeh.pmx进MMD
2.导入01 Particle_Default.vmd预设进Particle_RayBokeh.pmx控制器中
3.导入RayController Bokeh_景深.vmd预设进ray_controller.pmx控制器中
4.在MMD中将ray.x绑定在模型头骨骼上
5.完成，自行调整粒子控制器表情参数，并且注册，或者使用其他预设

#附Ray渲染下载地址
https://github.com/ray-cast/ray-mmd/releases/tag/1.5.2

#借物书写
Rui/そぼろ/化身バレッタ/ARonisc

ARonisc
2022.6.21