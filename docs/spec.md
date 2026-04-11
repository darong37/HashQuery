# HashQuery 仕様書

## 0. 設計原則

HashQuery は、Perl の AoH（ハッシュリファレンスの配列リファレンス）を単一対象として SQL 風に操作するためのシンタックスシュガーである。DSL の構文は SQL をできるだけ忠実に模倣しており、SQL の知識がある開発者がそのまま直感的に読み書きできることを目指している。

オブジェクト指向 API として設計されており、`HashQuery->new(\@aoh)` でインスタンスを生成し、`SELECT` / `DELETE` / `UPDATE` をメソッドとして呼び出す。インスタンスは内部に clone した rows を保持するため、同一インスタンスに対して複数回メソッドを呼び出しても互いに影響しない。

`where` と `having` の役割は明確に分離している。`where` は行フィルタであり、現在行のみを見て評価する。`having` は行列フィルタであり、重複排除・最大値・先頭行といった「全体の中での位置づけ」を条件にできる。この2つを分離することで、SQL の `WHERE` / `HAVING` の概念をそのまま Perl の構文として表現している。

- 実行の起点は **`HashQuery->new`** によるインスタンス生成
- `SELECT` / `DELETE` / `UPDATE` は **インスタンスメソッド**
- `as` / `except` / `set` / `where` / `having` は **引数として渡す DSL ノード値**を返す関数
- 入出力はすべて **AoH**
- 出力は原則として常に **meta 付き AoH**。結果 rows が 0 件のときだけ例外として `[]` を返す
- 外部エンジン・別実行層は存在しない
- `from` / `group_by` / `distinct` は存在しない

## 1. 提供関数一覧

| 関数 | 分類 | 役割 |
|---|---|---|
| `as` | DSL | `new` のオプションとして `where` / `having` 内で使うエイリアス変数を指定する |
| `except` | DSL | `SELECT` の第一引数として除外するカラムを指定する |
| `set` | DSL | `UPDATE` の第一引数として更新内容を key/value リストで記述するための syntax sugar |
| `where` | DSL | 行フィルタ条件を指定する |
| `having` | DSL | 行列フィルタ条件を指定する |

## 2. DSL 構文

**プロトタイプ定義:**

```perl
sub as (\$);
sub except (@);
sub set (@);
sub where (&);
sub having (&);
```

**基本構文:**

```perl
my $hq = HashQuery->new(\@aoh, as $tbl);

my $result = $hq->SELECT([qw/a b c/], where { ... }, having { ... });
my $result = $hq->DELETE(where { ... });
my $result = $hq->UPDATE({ col => val }, where { ... });
```

## 3. コンストラクタ・メソッドリファレンス

### HashQuery->new

**シグネチャ:**

```perl
my $hq = HashQuery->new(\@aoh);
my $hq = HashQuery->new(\@aoh, as $tbl);
my $hq = HashQuery->new(\@aoh, { as => \$tbl });
```

**動作説明:**

第一引数に AoH（必須）を受け取りインスタンスを生成する。プレーン AoH（meta なし）も meta 付き AoH（先頭要素に `{ '#' => { attrs, count, order } }` を持つ配列）も受け取れる。

入口で `TableTools::validate()` を通すことで meta を確定させ、その後 `detach()` で meta と rows を分離して内部保持する。これによりプレーン入力でも meta が生成され、`$self->{meta}` は常にセットされる。

データ行が空のとき（`validate()` が `[]` を返したとき）、インスタンスは `rows = []`、`all = []`、`meta = { '#' => { attrs => {}, count => 0 } }` の最小構成で即座に生成される。入力に meta が付いていてもカラムリストの復元は行わない。`SELECT('*')` の結果は `[]` になる。

元の AoH は `clone` してインスタンス内部に保持するため、元のデータは変更されない。第二引数にオプションのハッシュリファレンスを渡すことができ、現時点では `as` のみをサポートする。`as $tbl` は `{ as => \$tbl }` の syntax sugar。

**meta の形式:**

```perl
{ '#' => {
    attrs => { a => 'num', b => 'str' },
    count => 2,
    order => ['a', 'b'],
}}
```

- `attrs`: カラム名をキー、型情報（`'num'` / `'str'`）を値とするハッシュ
- `count`: rows 件数（meta を除いた data 行の数）
- `order`: カラム名の並びを表す配列リファレンス

**エラー:**

| 状況 | エラーメッセージ |
|---|---|
| 第一引数が AoH でない | `"HashQuery->new requires an Array of Hash"` |
| rows のカラム構成が不一致 | `TableTools::validate()` が die する（例: `column count mismatch`, `unexpected column`） |
| `validate()` が空集合以外を返したのに meta がない | `"UNEXPECTED ERROR: validate() returned rows without meta"`（論理的にありえない内部エラー） |

### SELECT メソッド

**シグネチャ:**

```perl
$hq->SELECT('*')
$hq->SELECT('*', where { ... }, having { ... })
$hq->SELECT([qw/a b/], where { ... })
$hq->SELECT(except('c', 'd'), where { ... })
```

**動作説明:**

第一引数（必須）で出力カラムを指定する。`'*'` は全列、配列リファレンスは明示指定、`except(...)` の戻り値は除外指定。`undef` は die する。第二引数以降に `where { }` / `having { }` を順不同で渡せる。`_idx` は常に出力から除外される。

戻り値は meta 付き AoH。出力列に合わせて `attrs` / `order` を射影した meta が先頭要素として付与される。結果 rows が 0 件のときだけ例外として `[]` を返す。

`as` を指定した場合、完了後に alias 変数には `{ count => N, affect => N }` 形式の hashref が格納される。`count` = 結果行数、`affect` = 結果行数（SELECT では同値）。

**エラー:**

| 状況 | エラーメッセージ |
|---|---|
| 第一引数が不正 | `"SELECT requires '*', arrayref, or except(...)"` |

### DELETE メソッド

**シグネチャ:**

```perl
$hq->DELETE()
$hq->DELETE(where { ... })
$hq->DELETE(having { ... })
$hq->DELETE(where { ... }, having { ... })
```

**動作説明:**

引数（省略可）に `where { }` / `having { }` を順不同で渡せる。`where` / `having` にマッチした行を削除対象とし、残存 rows を meta 付き AoH で返す。引数省略時は何も削除されず全行を返す。元の AoH は変更しない。`SELECT` と対称的な操作であり、同じ条件で `SELECT` ↔ `DELETE` を差し替えることで削除対象の確認と実行を切り替えられる。

列集合は変化しないため、meta の `attrs` / `order` は元のものをそのまま付与する。結果 rows が 0 件のときだけ例外として `[]` を返す。

`as` を指定した場合、完了後に alias 変数には `{ count => N, affect => N }` 形式の hashref が格納される。`count` = 残存行数、`affect` = 削除行数。

### UPDATE メソッド

**シグネチャ:**

```perl
$hq->UPDATE({ col => val, ... })
$hq->UPDATE({ col => val, ... }, where { ... })
$hq->UPDATE(set(col => val, ...), where { ... })
```

**動作説明:**

第一引数（必須）に更新内容のハッシュリファレンスまたは `set(...)` の戻り値を渡す。`where` / `having` にマッチした行の指定カラムを固定値で上書きし、全行（更新済み行・未更新行を含む）を meta 付き AoH で返す。元の AoH は変更しない。存在しないカラムを指定した場合は die する。

列集合は変化しないため、meta の `attrs` / `order` は元のものをそのまま付与する。結果 rows が 0 件のときだけ例外として `[]` を返す。

`as` を指定した場合、完了後に alias 変数には `{ count => N, affect => N }` 形式の hashref が格納される。`count` = 全行数、`affect` = 更新行数。

**エラー:**

| 状況 | エラーメッセージ |
|---|---|
| 第一引数がハッシュリファレンスでない | `"UPDATE requires a hash reference"` |
| 存在しないカラム名を指定 | `"unknown column in UPDATE: <カラム名>"` |

### as 関数

**シグネチャ:**

```perl
as $var
```

**戻り値:**

```perl
{ as => \$var }
```

**動作説明:**

`new` の第二引数として渡すことで、`where` / `having` 内で現在行を参照するためのエイリアス変数を指定する。`as $tbl` と指定した場合、`where` / `having` の中で `$tbl->{col}` によって現在行のカラム値を参照できる。`as` を指定しない場合は `$_` で参照する。`as` を指定した場合も `$_` は同じ値を持つ。引数はスカラー変数への参照（`\$var` 形式）として受け取る。

各メソッド完了後、指定した変数には `{ count => N, affect => N }` 形式の hashref が格納される:

| メソッド | `count` | `affect` |
|---|---|---|
| `SELECT` | 結果行数 | 結果行数（count と同値） |
| `DELETE` | 残存行数 | 削除行数 |
| `UPDATE` | 全行数 | 更新行数 |

結果 rows が 0 件のときも alias には hashref が格納される（`count` = 0）。

**コード例:**

```perl
our $tbl;
my $hq = HashQuery->new(\@aoh, as $tbl);
my $r = $hq->SELECT('*', where { $tbl->{score} >= 80 });
# $tbl->{count} には結果行数、$tbl->{affect} には変化行数が格納される
```

### except 関数

**シグネチャ:**

```perl
except('c')
except('b', 'c')
```

**戻り値:**

```perl
{ except => ['c'] }
```

**動作説明:**

`SELECT` の第一引数として渡すことで、インスタンスが保持する全カラムリストから指定列を除外した列リストで射影する。引数は1個以上のカラム名を渡す。

**エラー:**

| 状況 | エラーメッセージ |
|---|---|
| 引数が0個 | `"except requires at least one column name"` |

### set 関数

**シグネチャ:**

```perl
set(score => 60, grade => 'C')
```

**戻り値:**

ハッシュリファレンス（`{ score => 60, grade => 'C' }`）

**動作説明:**

`UPDATE` の第一引数として渡す更新内容を key/value リストで記述するための syntax sugar。`{ col => val }` と完全に同義。波括弧なしで UPDATE の更新内容を記述できる。

### where 関数

**シグネチャ:**

```perl
where { 条件式 };
```

**戻り値:**

```perl
{ where => CODE }
```

**動作説明:**

rows を1行ずつ評価し、条件式が真の行のみを残す行フィルタ。`as` が指定されている場合はそのエイリアス変数が現在行を指す。`as` なしの場合は `$_` で参照する。`$tbl->{col}` や `$_->{col}` が返す値は `HashQuery::Value` のインスタンスであり、`like` / `between` / `in` などの条件メソッドを呼び出せる。

### having 関数

**シグネチャ:**

```perl
having { 条件式 };
```

**戻り値:**

```perl
{ having => CODE }
```

**動作説明:**

`where` 後の rows を対象に行単位で条件を評価し、真の行のみを残す行列フィルタ。`as` が指定されている場合はそのエイリアス変数が現在行を指す。集約関数（`count_by` / `max_by` / `min_by` / `first_by` / `last_by`）を条件式内で使用できる。集約対象は常に `where` 後の rows であり、元の rows ではない。

## 4. 条件メソッド（where / having 共通）

`$tbl->{col}` や `$_->{col}` が返す `HashQuery::Value` インスタンスに対してチェーン呼び出しする。

### like

```perl
$tbl->{col}->like($pattern)
```

- `$pattern`: パターン文字列（`%` は任意文字列、`_` は任意1文字）
- 戻り値: 真偽値（一致すれば 1、しなければ 0）
- `undef` の場合は 0 を返す

### not_like

```perl
$tbl->{col}->not_like($pattern)
```

- `like` と同じ規則で評価した結果を反転して返す
- `undef` の場合、`like` が 0 のため `not_like` は 1 を返す

### between

```perl
$tbl->{col}->between($min, $max)
```

- `$min` / `$max`: 数値または文字列スカラー。末尾に `!` を付けると排他境界
- 戻り値: 真偽値（範囲内であれば 1）
- `undef` の場合は 0 を返す

### in

```perl
$tbl->{col}->in([ $v1, $v2, ... ])
$tbl->{col}->in($v1, $v2, ...)
```

- 引数: 配列リファレンス、またはフラットなリスト
- 戻り値: 真偽値（候補集合に含まれれば 1）
- `undef` の場合は 0 を返す

### not_in

```perl
$tbl->{col}->not_in([ $v1, $v2, ... ])
$tbl->{col}->not_in($v1, $v2, ...)
```

- `in` と同じ引数形式を受け付ける
- `in` の評価結果を反転して返す

### asNull

```perl
$tbl->{col}->asNull($default)
```

- `$default`: 置き換え後のデフォルト値（スカラー値）
- 対象値が `undef` または空文字の場合は `$default` を返す
- 対象値が存在する場合は対象値そのものを返す

## 5. where 専用関数

### grep_concat

```perl
grep_concat($col, $pattern, $start, $end)
```

- `$col`: 対象カラム名（文字列スカラー。必須）
- `$pattern`: マッチングパターン（Regexp）。内部で `(?s)` を付与して使用する
- `$start`: 取得開始位置（整数。省略時は 0）
- `$end`: 取得終了位置（整数。省略時は `$start` と同値）

**動作説明:**

現在行の `$col` カラム値が `$pattern` に一致した場合に、`$start` 〜 `$end` の範囲の行の `$col` カラム値を改行区切りで連結した文字列を返す。一致しない場合、または `$col` の値が `undef` / 空文字の場合は空文字を返す。連結する値は `$col` カラムのみであり、他カラムの値は含まれない。`$start` 〜 `$end` の範囲は rows の境界でクランプする。`where` ブロック外で呼び出した場合は die する。

**コード例:**

```perl
# msg カラムに ERROR を含む行の前後1行を連結した文字列を確認
where { grep_concat('msg', qr/ERROR/, -1, 1) ne '' }
```

## 6. having 専用集計関数

`having` ブロック内でのみ使用できる。ブロック外で呼び出した場合は die する。`HashQuery::HavingContext` に保持された現在行と `where` 後の rows を参照して動作する。

### count_by

```perl
count_by($col1, $col2, ...)
```

- 入力: グループキーとなる1個以上のカラム名（文字列リスト）
- 戻り値: 現在行と同じグループキーを持つ行数（整数）

### max_by

```perl
max_by($target, $col1, $col2, ...)
```

- `$target`: 最大値を求める対象カラム名（第一引数）
- `$col1, ...`: グループキー（第二引数以降）
- 戻り値: グループ内の `$target` の最大値。有効値がなければ `undef`

### min_by

```perl
min_by($target, $col1, $col2, ...)
```

- `max_by` と同様の引数形式で最小値を返す

### first_by

```perl
first_by($col1, $col2, ...)
```

- 入力: グループキーとなるカラム名（1個以上）
- 戻り値: 現在行がグループ内の先頭行であれば 1、そうでなければ 0

### last_by

```perl
last_by($col1, $col2, ...)
```

- 入力: グループキーとなるカラム名（1個以上）
- 戻り値: 現在行がグループ内の末尾行であれば 1、そうでなければ 0

## 7. 実行モデル

### SELECT メソッド

1. `SELECT` 引数から出力カラムリストを確定する
2. インスタンス内部 rows を `clone` する
3. 各行への `_idx` 付加（0 始まりの行番号）
4. `_filter_rows` で `where` / `having` を適用する
5. 列射影（`_idx` を除外）
6. `_set_meta_count` で meta の `count` を結果行数にセットする
7. `_set_meta_attrs` で出力列に合わせて `attrs` / `order` を射影する
8. `_set_alias` で alias 変数に `{ count => N, affect => N }` を格納する
9. `_build_return` で meta 付き AoH を組み立てて返す（0 件なら `[]`）

### DELETE メソッド

1. インスタンス内部 rows を `clone` する
2. 各行への `_idx` 付加（0 始まりの行番号）
3. `_filter_rows` で削除対象 rows を特定する（引数省略時はスキップ）
4. 削除対象行を除いた残存 rows を確定する
5. `_set_meta_count` で meta の `count` を残存行数にセットする
6. `_set_alias` で alias 変数に `{ count => N, affect => 削除行数 }` を格納する
7. `_build_return` で meta 付き AoH を組み立てて返す（0 件なら `[]`）

### UPDATE メソッド

1. 更新内容のカラム名が全て既存カラムであることを検証（不正なら die）
2. インスタンス内部 rows を `clone` する
3. 各行への `_idx` 付加（0 始まりの行番号）
4. `_filter_rows` で更新対象 rows を特定する
5. 更新候補の各行に対して更新内容を代入
6. 全行（更新済み行・未更新行を含む）を確定する
7. `_set_meta_count` で meta の `count` を全行数にセットする
8. `_set_alias` で alias 変数に `{ count => N, affect => 更新行数 }` を格納する
9. `_build_return` で meta 付き AoH を組み立てて返す（0 件なら `[]`）

### 内部パッケージ

| パッケージ | 役割 |
|---|---|
| `HashQuery` | インスタンス主体。`new`・`SELECT`・`DELETE`・`UPDATE` を提供する |
| `HashQuery::RowHash` | `$tbl` / `$_` の実体。`tie` によるハッシュアクセスを提供し、カラム添字で `HashQuery::Value` を返す |
| `HashQuery::Value` | カラム値を保持する値オブジェクト。条件メソッド・変換メソッドおよび数値/文字列/真偽値オーバーロードを持つ |
| `HashQuery::WhereContext` | `where` 実行時の現在行と rows を保持し、`grep_concat` に実行コンテキストを提供する |
| `HashQuery::HavingContext` | `having` 実行時の現在行と `where` 後の rows を保持し、集約関数に計算コンテキストを提供する |

**外部依存:**

| モジュール | 用途 |
|---|---|
| `Clone` | rows の深いコピー（内部データの隔離） |
| `TableTools` | `validate`（meta の生成・検証）/ `detach`（meta と rows の分離）/ `attach`（meta の再付与） |

## 8. 制約・注意事項

- `HashQuery->new` の第一引数は AoH でなければならない
- 入力 AoH の全 rows は同一のカラム構成を持つ必要がある（不一致の場合は die する）
- 同一インスタンスに対して `SELECT` / `DELETE` / `UPDATE` を複数回呼び出すことができる（互いに独立）
- `count_by` / `max_by` / `min_by` / `first_by` / `last_by` は `having` ブロック外で呼ぶと die する
- `grep_concat` は `where` ブロック外で呼ぶと die する。返す値は指定カラムのみであり、他カラムは含まれない
- `as` に渡す変数は `our`（パッケージ変数）で宣言する必要がある（`my` では動作しない）
- `having` の集約対象は `where` 後の rows であり、元の入力 rows ではない
- `_idx` カラムは最終出力に含まれない
- `SELECT` / `DELETE` / `UPDATE` はすべて非破壊的操作（元 AoH を変更しない）
- `UPDATE` に存在しないカラムを指定した場合は die する
- `UPDATE` は固定値のみサポート。動的な計算は呼び出し前に Perl 側で行う
- `except` の引数が0個の場合は die する
