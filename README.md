# tex_docker_environment

Docker ベースで TeX プロジェクトをコンパイルするための汎用環境です。

## 使い方

1. コンパイルしたい zip ファイル、または展開済みフォルダを `projects/` に置く
2. `task` を実行する
3. 生成物を `output/<project-name>/` で確認する

`projects/` に複数の入力があるときは、番号で対象を選択できます。

```bash
task
```

対象を明示することもできます。非対話環境で実行する場合はこちらを使ってください。

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
- それでも曖昧なら、対話環境では番号で対象を選択する
- 非対話環境では停止して `TARGET=...` を求める

## TeX エンジン

通常は pdfLaTeX でコンパイルします。対象 `.tex` の先頭に次のような指定がある場合は、指定されたエンジンに自動で切り替えます。

```tex
% !TeX program = lualatex
% !TeX program = platex
```

`jarticle` や `pLaTeX2e` を要求するローカルクラスは、pLaTeX + dvipdfmx でコンパイルします。

明示的に指定したい場合は、`LATEX_ENGINE` を使ってください。

```bash
LATEX_ENGINE=lualatex task
LATEX_ENGINE=platex task compile INPUT=projects/my-project
LATEX_ENGINE=pdflatex task compile INPUT=projects/my-project
```

## 補足

- Docker イメージタグは `TEX_DOCKER_IMAGE` で変更できます
- `LATEXMK_ARGS` を使うと `latexmk` に追加オプションを渡せます
