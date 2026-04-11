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

データ行なし。

---

## テストヘルパー関数

| 関数 | 説明 |
|---|---|
| `data_rows($aoh)` | meta 行を除いたデータ行の配列リファレンスを返す |
| `meta_row($aoh)` | meta 行（`{ '#' => ... }` を持つ先頭要素）を返す。なければ `undef` |
| `assert_result_meta($aoh, $count, $attrs, $order)` | meta 行の存在・`attrs`・`count`・`order` を検証する。`$attrs` / `$order` は省略可 |

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
| 8 | カラム構成が不一致だと die する | エラー: `column count mismatch` または `unexpected column`（validate() から） |
| 9 | 元テーブルを変更しない | is_deeply |
| 10 | `as $var` 形式でオプションを受け取れる | isa HashQuery |
| 11 | `{ as => \$var }` 形式でオプションを受け取れる | isa HashQuery |
| 12 | 空テーブルでインスタンスを生成できる | isa HashQuery |

### SELECT メソッド

`@base` (`attrs = { a=>'str', b=>'num', c=>'num' }`) を使用。`assert_result_meta` で meta・attrs・count を検証する。

| # | テストケース | 期待値 |
|---|---|---|
| 13 | `*` で全列・全行を返す | meta あり、count=5、attrs={a:str,b:num,c:num}、データ5行、a/b/c カラム存在 |
| 14 | 配列リファレンスで列を指定できる | meta あり、count=5、attrs={a:str,b:num}、order=[a,b]、データ5行、c 不在 |
| 15 | `except` で列を除外できる | meta あり、count=5、attrs={a:str,b:num}、order=[a,b]、データ5行、c 不在 |
| 16 | `except` で複数列を除外できる | meta あり、count=5、attrs={a:str}、order=[a]、データ5行、b/c 不在 |
| 17 | `_idx` は出力に含まれない | データ行に _idx 不在 |
| 18 | `undef` を渡すと die する | エラー: `SELECT requires` |
| 19 | `where` で行をフィルタできる | meta あり、count=2、attrs={a:str,b:num,c:num}、データ2行（alice, dave） |
| 20 | `having` で集約フィルタできる | meta あり、count=4、attrs={a:str,b:num,c:num}、データ4行（carol 以外） |
| 21 | `where` と `having` を組み合わせられる | meta あり、count=3、attrs={team:str,name:str,score:num}、order=[team,name,score]、データ3行（alpha チームのみ） |
| 22 | `as` で count/affect が返る | `$s1->{count}=2`, `$s1->{affect}=2` |
| 22a | `as` - 結果が 0 件でも alias は hashref | ref=HASH, `count=0`, `affect=0` |
| 23 | 同じインスタンスを複数回呼べる | r1 データ2行, r2 データ2行 |
| 24 | 元テーブルは変更されない | is_deeply |

### DELETE メソッド

| # | テストケース | 期待値 |
|---|---|---|
| 25 | `where` にマッチした行を削除して残りを返す | meta あり、count=3、attrs={a:str,b:num,c:num}、データ3行（bob, carol, eve） |
| 26 | 条件なしで全行を返す（何も削除しない） | meta あり、count=5、attrs={a:str,b:num,c:num}、データ5行 |
| 27 | 一致なしで全行残る | meta あり、count=5、attrs={a:str,b:num,c:num}、データ5行 |
| 28 | `having` と組み合わせて削除できる | meta あり、count=1、attrs={a:str,b:num,c:num}、データ1行（carol のみ） |
| 29 | `_idx` は出力に含まれない | データ行に _idx 不在 |
| 30 | 元テーブルは変更されない | is_deeply |
| 31 | `as` で count/affect が返る | `$d1->{count}=3`, `$d1->{affect}=2` |
| 31a | `as` - 全件削除で結果 0 件でも alias は hashref | ref=HASH, `count=0`, `affect=5` |
| 32 | `SELECT` と対称動作する | selected データ行数 + deleted データ行数 = 5 |

### UPDATE メソッド

| # | テストケース | 期待値 |
|---|---|---|
| 33 | `where` にマッチした行を更新して全行返す | meta あり、count=5、attrs={a:str,b:num,c:num}、データ5行、alice/dave の b=99 |
| 34 | `set` 関数形式でも更新できる | meta あり、count=5、attrs={a:str,b:num,c:num}、データ5行、2行が b=99 |
| 35 | 条件なしで全行更新する | meta あり、count=5、attrs={a:str,b:num,c:num}、データ5行、全て b=0 |
| 36 | 一致なしで全行そのまま返す | meta あり、count=5、attrs={a:str,b:num,c:num}、データ5行、b=[10,20,30,10,20] |
| 37 | `having` と組み合わせて更新できる | meta あり、count=5、attrs={a:str,b:num,c:num}、4行 b=0、carol のみ intact |
| 38 | 複数カラムを同時に更新できる | meta あり、count=5、alice の b=0, c=0 |
| 39 | `_idx` は出力に含まれない | データ行に _idx 不在 |
| 40 | 元テーブルは変更されない | is_deeply |
| 41 | `as` で count/affect が返る | `$u1->{count}=5`, `$u1->{affect}=2` |
| 42 | 存在しないカラムを指定すると die する | エラー: `unknown column in UPDATE` |
| 43 | ハッシュリファレンス以外を渡すと die する | エラー: `UPDATE requires a hash reference` |

### 条件メソッド（HashQuery::Value）

| # | テストケース | 期待値 |
|---|---|---|
| 44 | `like`: パターンマッチする | meta あり、count=1、データ1行（alice） |
| 45 | `like`: `%` で複数文字にマッチ | meta あり、count=3、データ3行（alice, dave, eve） |
| 46 | `not_like`: パターンに一致しない行を返す | meta あり、count=4、データ4行（alice 以外） |
| 47 | `between`: 両端含む範囲 | meta あり、count=4、データ4行 |
| 48 | `between`: 排他境界 | データ0行（結果 `[]`） |
| 49 | `in`: リストに含まれる行 | meta あり、count=3、データ3行（alice, carol, dave） |
| 50 | `not_in`: リストに含まれない行 | meta あり、count=2、データ2行（bob, eve） |
| 51 | `asNull`: undef をデフォルト値に置き換える | meta あり、count=1、attrs={name:str,val:num}、データ1行（y） |

### having 集計関数

| # | テストケース | 期待値 |
|---|---|---|
| 52 | `count_by`: グループ内の行数 | meta あり、count=4、データ4行（carol 以外） |
| 53 | `max_by`: グループ内の最大値 | meta あり、count=2、データ2行（bob, eve） |
| 54 | `min_by`: グループ内の最小値 | meta あり、count=2、データ2行（alice, dave） |
| 55 | `first_by`: グループ内の先頭行 | meta あり、count=3、データ3行（alice, bob, carol） |
| 56 | `last_by`: グループ内の末尾行 | meta あり、count=3、データ3行（carol, dave, eve） |

### grep_concat

| # | テストケース | 期待値 |
|---|---|---|
| 57 | マッチした行の値を返す | meta あり、count=2、attrs={line:num,msg:str}、データ2行（ERROR 行のみ） |
| 58 | 前後の行を含む文字列を返す（現在行マッチのみ選択） | meta あり、count=2、データ2行（ERROR 行のみ） |
| 59 | 指定カラムの値のみ連結する | meta あり、count=1、データ1行（line=2） |

### 実用例

| # | テストケース | 期待値 |
|---|---|---|
| 60 | `as` を使って `where` でフィルタ（列射影） | meta あり、count=3、attrs={team:str,name:str}、order=[team,name]、データ3行、role カラム不在 |
| 61 | スコア 75 以上かつチームに 2 人以上いるメンバー | meta あり、count=3、attrs={team:str,name:str,score:num}、order=[team,name,score]、データ3行（alice, bob, carol） |

### メタ情報付き配列対応

#### new()

| # | テストケース | 期待値 |
|---|---|---|
| 62 | メタ付き配列を受け取れる | isa HashQuery |
| 63 | メタ付き配列でカラム構成を正しく認識する | meta あり、count=3、attrs={a:str,b:num,c:num}、order=[a,b,c]、データ3行 |
| 64 | 空 rows（meta に order あり）は SELECT で `[]` を返す | 結果 `[]`、データ0行 |
| 65 | 空 rows（meta に attrs のみ）は SELECT で `[]` を返す | 結果 `[]`、データ0行 |

#### SELECT

`@meta_base` (`attrs = { a=>'str', b=>'num', c=>'num' }`, `order = [a,b,c]`) を使用。

| # | テストケース | 期待値 |
|---|---|---|
| 66 | `*` でメタ付き全列の attrs/order が返る | meta あり、count=3、attrs={a:str,b:num,c:num}、order=[a,b,c]、データ3行 |
| 67 | 列を絞ると attrs/order が射影される | meta あり、count=3、attrs={a:str,b:num}、order=[a,b]、c は attrs に不在 |
| 68 | 列順を入れ替えると order が返却列順に一致する | meta あり、count=3、attrs={b:num,a:str}、order=[b,a]、c は attrs に不在 |
| 69 | `except` を使うと attrs/order が射影される | meta あり、count=3、attrs={a:str,b:num}、order=[a,b]、c は attrs に不在 |
| 70 | プレーン入力でも meta 付き AoH で返る | meta あり、count=5、attrs={a:str,b:num,c:num}、データ5行 |

#### DELETE

| # | テストケース | 期待値 |
|---|---|---|
| 71 | メタ付き入力は元 meta をそのまま付与して返す | meta あり、count=2、attrs={a:str,b:num,c:num}、order=[a,b,c]、データ2行 |
| 72 | プレーン入力でも meta 付き AoH で返る | meta あり、attrs={a:str,b:num,c:num} |

#### UPDATE

| # | テストケース | 期待値 |
|---|---|---|
| 73 | メタ付き入力は元 meta をそのまま付与して返す | meta あり、count=3、attrs={a:str,b:num,c:num}、order=[a,b,c]、データ3行、更新済み1行(b=99) |
| 74 | プレーン入力でも meta 付き AoH で返る | meta あり、attrs={a:str,b:num,c:num} |
