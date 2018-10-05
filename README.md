# 186cpu
最終的にはここに対外的な説明が並ぶ  

# 共有メモ
リポジトリの名前を変えるのは難しくないのでとりあえず仮の名前にしてある  

# 使い方の想定
186cpu直下にcore, compiler, simulator, fpuという4つのディレクトリがあり、その中で各自作業をするという想定  
`186cpu/<charge>(役割)/README.md`に各自のメモ（仕様とかビルド方法とか）を書く的な  
1. 自分のPCの作業ディレクトリにしたい場所にクローン  
   `git clone <url>(右上にある）`  
   186cpuというディレクトリ（ローカルリポジトリ）ができるはず
2. `186cpu/<charge>`というディレクトリを作って成果物を入れる  
3. 追跡させてコミットしてプッシュ  
   ```
   cd 186cpu
   git add *
   git commit -m "<charge> first commit"
   git push origin master
   ```

コマンドが合ってるかは知りません
