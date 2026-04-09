# tex_docker_environment

Docker ベースで TeX プロジェクトをコンパイルするための汎用環境です。

## 使い方

1. コンパイルしたい zip ファイル、または展開済みフォルダを `projects/` に置く
2. `task` を実行する
3. 生成物を `output/<project-name>/` で確認する

`projects/` に複数の入力があるときは、対象を明示してください。

```bash
task compile INPUT=projects/my-project.zip
task compile INPUT=projects/my-project TARGET=main.tex
```

外部パスを直接指定することもできます。

```bash
task compile INPUT=/absolute/path/to/project.zip
task compile INPUT=/absolute/path/to/project TARGET=subdir/main.tex
```

## 補助コマンド

```bash
task inputs
task clean
```

## エントリポイントの自動検出

`TARGET` を指定しない場合は、`\\documentclass` を含む `.tex` を探索し、次の順で選びます。

- 候補が 1 つだけならそれを使う
- `main.tex` が 1 つだけならそれを使う
- `manuscript.tex` や `paper.tex` など代表的な名前が 1 つだけならそれを使う
- それでも曖昧なら停止して `TARGET=...` を求める

## 補足

- Docker イメージタグは `TEX_DOCKER_IMAGE` で変更できます
- `LATEXMK_ARGS` を使うと `latexmk` に追加オプションを渡せます
