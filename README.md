InterAppDataEx
==============

Inter-app data transfer demo using Inter-app audio feature of iOS7

###説明
Inter-app audioを使ってアプリ間のデータ転送を実現するデモ．  
Generatorがファイルを読み取りそのバイト列をPCMデータとしてHost側に転送．  
Host側のAudioUnitで受けとりバイト列として保存する．  
なぜかXcode上でのデバッグではHost側がうまくうごきません．  
Xcodeからインストールしてデバッグ無しで起動すると正しく動作します．  

