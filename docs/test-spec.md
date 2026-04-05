# HashQuery テスト仕様書

## テストデータ

### @base

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |
| bob   | 20 | 200 |
| carol | 30 | 300 |
| dave  | 10 | 150 |
| eve   | 20 | 250 |

### @null_tbl

| name | val     |
|------|---------|
| x    | (undef) |
| y    | 42      |
| z    | (空文字) |

### @log_tbl

| line | msg                      |
|------|--------------------------|
| 1    | INFO  start              |
| 2    | ERROR connection failed  |
| 3    | INFO  retrying           |
| 4    | ERROR timeout            |
| 5    | INFO  done               |

### @edge_log

| line | msg          |
|------|--------------|
| 1    | ERROR first  |
| 2    | INFO  second |
| 3    | INFO  third  |
| 4    | INFO  fourth |
| 5    | ERROR last   |

### @members

| team  | name  | role   | score |
|-------|-------|--------|-------|
| alpha | alice | lead   | 90    |
| alpha | bob   | member | 75    |
| alpha | carol | member | 82    |
| beta  | dave  | lead   | 88    |
| beta  | eve   | member | 70    |
| gamma | frank | lead   | 95    |
| gamma | grace | member | 60    |

### @meta_base（メタ付き配列）

先頭要素: `{ '#' => { attrs => { a => 'str', b => 'num', c => 'num' }, order => [qw/a b c/] } }`

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |
| bob   | 20 | 200 |
| carol | 30 | 300 |

### @meta_empty_with_order（メタのみ・order あり）

先頭要素: `{ '#' => { attrs => { a => 'str', b => 'num' }, order => [qw/a b/] } }`

データ行なし。

### @meta_empty_attrs_only（メタのみ・attrs のみ）

先頭要素: `{ '#' => { attrs => { x => 'num', y => 'str' } } }`

データ行なし。order なし（カラムリストは attrs キーの辞書順ソート）。

---

## テストケース一覧

### as / except / set

| # | テストケース | 期待値 |
|---|---|---|
| 1 | `as $v` が `{ as => \$v }` を返す | ref=HASH, as=\$v |
| 2 | `except('c')` が `{ except => ['c'] }` を返す | is_deeply |
| 3 | `except('b', 'c')` が `{ except => ['b', 'c'] }` を返す | is_deeply |
| 4 | `except()` は 0 引数で die する | エラー: `except requires at least one column name` |
| 5 | `set(score => 99, grade => 'A')` がハッシュリファレンスを返す | is_deeply |

### HashQuery->new

| # | テストケース | 期待値 |
|---|---|---|
| 6 | インスタンスを生成できる | defined, isa HashQuery |
| 7 | 空配列でインスタンスを生成できる（die しない）、文字列は die | エラー: `HashQuery->new requires an Array of Hash` |
| 8 | カラム構成が不一致だと die する | エラー: `table columns are not consistent` |
| 9 | 元テーブルを変更しない | is_deeply |
| 10 | `as $var` 形式でオプションを受け取れる | isa HashQuery |
| 11 | `{ as => \$var }` 形式でオプションを受け取れる | isa HashQuery |
| 12 | 空テーブルでインスタンスを生成できる | isa HashQuery |

### SELECT メソッド

| # | テストケース | 期待値 |
|---|---|---|
| 13 | `*` で全列・全行を返す | 5行、a/b/c カラム存在 |
| 14 | 配列リファレンスで列を指定できる | 5行、a/b 存在、c 不在 |
| 15 | `except` で列を除外できる | 5行、a/b 存在、c 不在 |
| 16 | `except` で複数列を除外できる | a 存在、b/c 不在 |
| 17 | `_idx` は出力に含まれない | _idx 不在 |
| 18 | `undef` を渡すと die する | エラー: `SELECT requires` |
| 19 | `where` で行をフィルタできる | 2行（alice, dave） |
| 20 | `having` で集約フィルタできる | 4行（carol 以外） |
| 21 | `where` と `having` を組み合わせられる | 3行（alpha チームのみ） |
| 22 | `as` で count/affect が返る | count=2, affect=2 |
| 23 | 同じインスタンスを複数回呼べる | r1=2行, r2=2行 |
| 24 | 元テーブルは変更されない | is_deeply |

### DELETE メソッド

| # | テストケース | 期待値 |
|---|---|---|
| 25 | `where` にマッチした行を削除して残りを返す | 3行（bob, carol, eve） |
| 26 | 条件なしで全行を返す（何も削除しない） | 5行 |
| 27 | 一致なしで全行残る | 5行 |
| 28 | `having` と組み合わせて削除できる | 1行（carol のみ残る） |
| 29 | `_idx` は出力に含まれない | _idx 不在 |
| 30 | 元テーブルは変更されない | is_deeply |
| 31 | `as` で count/affect が返る | count=3, affect=2 |
| 32 | `SELECT` と対称動作する | selected + deleted = 5 |

### UPDATE メソッド

| # | テストケース | 期待値 |
|---|---|---|
| 33 | `where` にマッチした行を更新して全行返す | 5行、alice/dave の b=99 |
| 34 | `set` 関数形式でも更新できる | 5行、2行が b=99 |
| 35 | 条件なしで全行更新する | 5行、全て b=0 |
| 36 | 一致なしで全行そのまま返す | 5行、b=[10,20,30,10,20] |
| 37 | `having` と組み合わせて更新できる | 4行 b=0、carol のみ intact |
| 38 | 複数カラムを同時に更新できる | alice の b=0, c=0 |
| 39 | `_idx` は出力に含まれない | _idx 不在 |
| 40 | 元テーブルは変更されない | is_deeply |
| 41 | `as` で count/affect が返る | count=5, affect=2 |
| 42 | 存在しないカラムを指定すると die する | エラー: `unknown column in UPDATE` |
| 43 | ハッシュリファレンス以外を渡すと die する | エラー: `UPDATE requires a hash reference` |

### 条件メソッド（HashQuery::Value）

| # | テストケース | 期待値 |
|---|---|---|
| 44 | `like`: パターンマッチする | 1行（alice） |
| 45 | `like`: `%` で複数文字にマッチ | 3行（alice, dave, eve） |
| 46 | `not_like`: パターンに一致しない行を返す | 4行（alice 以外） |
| 47 | `between`: 両端含む範囲 | 4行 |
| 48 | `between`: 排他境界 | 0行 |
| 49 | `in`: リストに含まれる行 | 3行（alice, carol, dave） |
| 50 | `not_in`: リストに含まれない行 | 2行（bob, eve） |
| 51 | `asNull`: undef をデフォルト値に置き換える | 1行（y） |

### having 集計関数

| # | テストケース | 期待値 |
|---|---|---|
| 52 | `count_by`: グループ内の行数 | 4行（carol 以外） |
| 53 | `max_by`: グループ内の最大値 | 2行（bob, eve） |
| 54 | `min_by`: グループ内の最小値 | 2行（alice, dave） |
| 55 | `first_by`: グループ内の先頭行 | 3行（alice, bob, carol） |
| 56 | `last_by`: グループ内の末尾行 | 3行（carol, dave, eve） |

### grep_concat

| # | テストケース | 期待値 |
|---|---|---|
| 57 | マッチした行の値を返す | 2行（ERROR 行のみ） |
| 58 | 前後の行を含む文字列を返す（現在行マッチのみ選択） | 2行（ERROR 行のみ） |
| 59 | 指定カラムの値のみ連結する | 1行（line=2） |

### 実用例

| # | テストケース | 期待値 |
|---|---|---|
| 60 | `as` を使って `where` でフィルタ（列射影） | 3行、role カラム不在 |
| 61 | スコア 75 以上かつチームに 2 人以上いるメンバー | 3行（alice, bob, carol） |

### メタ情報付き配列対応

#### new()

| # | テストケース | 期待値 |
|---|---|---|
| 62 | メタ付き配列を受け取れる | isa HashQuery |
| 63 | メタ付き配列でカラム構成を正しく認識する | データ3行、a カラム存在、`'#'` キー不在 |
| 64 | rows が空でメタに order がある場合、列を復元できる | SELECT('*') 戻りメタの order=[a,b]（order から復元）、データ0行 |
| 65 | rows が空でメタに attrs のみある場合、列を辞書順で復元できる | SELECT('*') 戻りメタの order=[x,y]（attrs キーの辞書順）、データ0行 |

#### SELECT

| # | テストケース | 期待値 |
|---|---|---|
| 66 | `*` でメタ付き全列の attrs/order が返る | `$r->[0]{'#'}` に order=[a,b,c]（列順と一致）、attrs=全列型情報、データ3行 |
| 67 | 列を絞ると attrs/order が射影される | order=[a,b]（指定列順と一致）、attrs={a,b}、`c` は attrs に存在しない |
| 68 | 列順を入れ替えると order が返却列順に一致する | `SELECT([qw/b a/])` で order=[b,a]、attrs={b,a}、`c` は attrs に存在しない |
| 69 | `except` を使うと attrs/order が射影される | order=[a,b]、attrs={a,b}、`c` は attrs に存在しない |
| 70 | プレーン入力はメタなしで返る | `$r->[0]` に `'#'` キー不在、5行 |

#### DELETE

| # | テストケース | 期待値 |
|---|---|---|
| 71 | メタ付き入力は元メタをそのまま返す | `$r->[0]{'#'}` に order=[a,b,c]、attrs=全列、データ2行 |
| 72 | プレーン入力はメタなしで返る | `$r->[0]` に `'#'` キー不在 |

#### UPDATE

| # | テストケース | 期待値 |
|---|---|---|
| 73 | メタ付き入力は元メタをそのまま返す | `$r->[0]{'#'}` に order=[a,b,c]、attrs=全列、データ3行、更新済み1行(b=99) |
| 74 | プレーン入力はメタなしで返る | `$r->[0]` に `'#'` キー不在 |
