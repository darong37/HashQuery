# Design Concept
Date: 2026-04-09

## Terms
用語は次のとおり。

- `AoH`: このプロジェクトで扱うハッシュリファレンスの配列リファレンス
- `row`: 1 行分のハッシュリファレンス
- `rows`: `AoH` の本体である data 部分
- `meta`: `rows` に付く付加情報。存在する場合は先頭要素にだけ置く。その先頭要素の形は次のとおり
- `meta 付き AoH`: `rows` に `meta` が付いた `AoH`

`AoH` の成立条件は次のとおり。

- 先頭要素の `meta` を除くすべての `row` は同じキー集合を持つ
- 各キーの値は `undef` であってはならない

```perl
{'#' => {
    attrs => {a => 'num', b => 'str'},
    count => 2,
    order => ['a', 'b'],
}}
```

- `attrs` はカラム名をキーに持つハッシュで、値は型情報を表す文字列を置く
- `count` は `meta` を除いた `rows` 件数を表すスカラー値
- `order` はカラム名の並びを表す配列リファレンス
- `attrs` と `count` が必須、`order` は任意とする
- `alias`: `as $var` で渡す変数。`where` / `having` 内では現在行を参照し、各メソッド完了後には結果サマリとして `count` と `affect` を受け取る
- `where`: 行フィルタ
- `having`: 行列フィルタ
- `DSL node`: `as` / `except` / `set` / `where` / `having` が返す引数用データ構造

## Concept

### 第一コンセプト: 1つの AoH を単一対象として SQL 風に扱う

HashQuery は、1つの AoH を単一対象として Perl 上で SQL のように扱うためのシンタックスシュガーである。対象は1つの AoH に限り、複数の AoH を束ねる仕組みは持たない。

`SELECT` / `DELETE` / `UPDATE` は同じ AoH を対象にする操作なので、`from` は DSL に入れない。対象 AoH は `HashQuery->new()` で受け取ってオブジェクト化し、そのオブジェクトに対して各メソッドを呼ぶ。

SQL らしい読みやすさは重視するが、SQL の全機能は再現しない。特に join のような複数 AoH 操作は前提にしない。

### 第二コンセプト: TableTools 形式の meta 付き AoH を標準形とする

HashQuery が標準で扱う AoH は、TableTools と同じく先頭に `'#'` メタを持つ meta 付き AoH とする。これにより入出力を TableTools 系データとそのまま接続でき、`attrs` / `count` / `order` を持つ AoH として一貫して受け渡せる。

meta を持たない AoH も互換入力として受け取れるが、AoH の成立条件を満たすことや meta を整えることの責務は HashQuery ではなく TableTools 側にある。meta を整える役割は TableTools の `validate()` が担う。`HashQuery->new()` は受け取った AoH を入口で `validate()` に通し、その後は `detach()` した `rows` と `meta` を分離して内部保持する。出力も原則として meta 付き AoH にそろえ、結果 rows が 0 件のときだけ例外として meta を持たない空配列リファレンス `[]` を返す。

meta は付いていればよいのではなく、常に実際の rows と一致していなければならない。特に `attrs` は現在のキー集合と型に、`count` は現在の rows 件数に、`order` は現在の列順に対応していなければならない。`SELECT` / `DELETE` / `UPDATE` の結果で rows が変わるなら、meta もその結果に合わせて組み替える。

方針は次のとおり。

- 入出力は AoH に統一する
- 実行の起点は `HashQuery->new()` によるインスタンス生成とする
- `new()` は受け取った AoH を入口で `TableTools::validate()` に通す
- `new()` は `detach()` した `rows` と `meta` を別々に保持する
- インスタンスは受け取った rows を clone して保持し、元の入力は変更しない
- 同一インスタンスに対して `SELECT` / `DELETE` / `UPDATE` を複数回呼んでも互いに影響しない
- `SELECT` / `DELETE` / `UPDATE` で使う条件 DSL は共通とする
- `where` は行フィルタ、`having` は行列フィルタとする
- `where` / `having` の現在行は `$_` で参照でき、`as $var` を指定したときは同じ行を `$var` でも参照できる
- `SELECT` は列の射影、`DELETE` は条件一致行の除外、`UPDATE` は条件一致行への固定値代入とする
- `SELECT` と `DELETE` は同じ条件 DSL を共有する。ある条件を `SELECT` に使えばその条件に合う rows を返し、同じ条件を `DELETE` に使えばその条件に合わない rows の結果を返す
- `UPDATE` は更新対象のキー名を直接指定する。ここで指定できるのは `attrs` に存在するキーに限る
- `as` を指定した場合、各メソッド完了後の `$var` には `{ count => N, affect => N }` 形式の hashref を入れる
- meta を持たない AoH も meta 付き AoH も入力として受け取れる
- 入力 AoH の成立条件や meta の整備責任は TableTools 側にある前提とする
- 出力は原則として常に meta 付き AoH とする
- ただし結果 rows が 0 件のときだけは例外として `[]` を返す
- HashQuery は、自分の処理結果に整合する meta を TableTools 仕様に従って返さなければならない
- その meta では、`attrs` は現在のキー集合と型に、`count` は結果 rows 件数に、`order` は現在の列順に対応していなければならない
- `SELECT` では返却列に合わせて `attrs` と `order` を射影する
- HashQuery 自体は `from` / `group_by` / `distinct` を持たない

## API
記号は次のとおり。

- `$aoh`: 入力 AoH
- `$hq`: `HashQuery` インスタンス
- `$as_dsl`: `new()` 第2引数。`as $alias` が作る DSL node
- `$cols_expr`: `SELECT()` 第1引数。列指定の表現。`'*'`、配列リファレンス、`except(...)` のいずれか
- `$upd_arg`: `UPDATE()` 第1引数。更新内容の hashref または `set(...)`
- `$dsl`: `where(...)` または `having(...)` の戻り値
- `@dsls`: `SELECT` / `DELETE` / `UPDATE` の後続引数として渡す `where(...)` / `having(...)` の並び
- `$alias`: `as $var` で `new()` に渡すスカラー変数
- `$alias_result`: 実行後に `$alias` に格納される hashref

利用は大きく 2 段階に分かれる。

- インスタンス生成フェーズ: `HashQuery->new()` を呼ぶ段階。この場面で使う DSL は `as $alias`
- 実行フェーズ: 生成済みインスタンスに対して `SELECT` / `DELETE` / `UPDATE` を呼ぶ段階

これは実装が順番違いを積極的に検査するという意味ではなく、利用者に「どの場面で使う記法か」を示すための整理である。誤った場面で使った場合は、既存の実行時エラーで分かればよい。

実行フェーズの中でも、使う位置は次のように分かれる。

- `except(@cols)` は `SELECT()` 第1引数でだけ使える
- `set(%pairs)` は `UPDATE()` 第1引数でだけ使える
- `where { ... }` と `having { ... }` は `SELECT` / `DELETE` / `UPDATE` の DSL 引数として使える
- `count_by()` / `max_by()` / `min_by()` / `first_by()` / `last_by()` は `having { ... }` の中でだけ使える
- `grep_concat()` は `where { ... }` の中でだけ使える

| API | 役割 | 入力 | 出力 |
|---|---|---|---|
| `HashQuery->new($aoh)` | インスタンス生成 | `$aoh` | `$hq` |
| `HashQuery->new($aoh, as $alias)` | alias 付きインスタンス生成 | `$aoh`, `$alias` | `$hq` |
| `HashQuery->new($aoh, { as => \$alias })` | alias 付きインスタンス生成 | `$aoh`, `$as_dsl` | `$hq` |
| `$hq->SELECT($cols_expr, @dsls)` | 列射影して返す | `$cols_expr`, `@dsls` | `meta 付き AoH` または `[]` |
| `$hq->DELETE(@dsls)` | 一致行を除外して返す | `@dsls` | `meta 付き AoH` または `[]` |
| `$hq->UPDATE($upd_arg, @dsls)` | 一致行を更新して全行返す | `$upd_arg`, `@dsls` | `meta 付き AoH` または `[]` |
| `as $alias` | `new()` 用 alias 指定と実行結果サマリの受け取り先指定 | `$alias` | DSL node |
| `except(@cols)` | SELECT 除外列指定 | `@cols` | DSL node |
| `set(%pairs)` | UPDATE 内容指定 | `%pairs` | hashref |
| `where { ... }` | 行フィルタ指定 | block | DSL node |
| `having { ... }` | 行列フィルタ指定 | block | DSL node |
| `count_by(@keys)` | `@keys` の値が同じ行の件数取得 | `@keys` | 整数 |
| `max_by($target, @keys)` | `@keys` の値が同じ行における最大値取得 | `$target`, `@keys` | 値 |
| `min_by($target, @keys)` | `@keys` の値が同じ行における最小値取得 | `$target`, `@keys` | 値 |
| `first_by(@keys)` | `@keys` の値が同じ行の先頭判定 | `@keys` | 真偽値 |
| `last_by(@keys)` | `@keys` の値が同じ行の末尾判定 | `@keys` | 真偽値 |
| `grep_concat($col, $pattern, $start, $end)` | 前後行を含む値の連結取得 | `$col`, `$pattern`, `$start`, `$end` | 文字列 |

`as` を指定した場合の返り値は次の形とする。

```perl
{
    count  => N,
    affect => N,
}
```

- `count` は返却 `rows` 件数を表す
- `affect` は `SELECT` では結果件数、`DELETE` では削除件数、`UPDATE` では更新件数を表す
- 結果 `rows` が 0 件のときも alias は hashref のまま返し、`count` は 0 とする。`affect` は各メソッドで定義された意味に従う

