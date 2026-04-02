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

---

## テストケース一覧

### as / except / set

| # | テストケース | 期待値 |
|---|---|---|
| 1 | `as $v` が `{ as => \$v }` を返す | ref=HASH, as=\$v |
| 2 | `except('c')` が `{ except => ['c'] }` を返す | is_deeply |
| 3 | `except('b', 'c')` が `{ except => ['b', 'c'] }` を返す | is_deeply |
| 4 | `set(score => 99, grade => 'A')` がハッシュリファレンスを返す | is_deeply |

### HashQuery->new

| # | テストケース | 期待値 |
|---|---|---|
| 5 | インスタンスを生成できる | defined, isa HashQuery |
| 6 | 空配列でインスタンスを生成できる（die しない）、文字列は die | エラー: `HashQuery->new requires an Array of Hash` |
| 7 | カラム構成が不一致だと die する | エラー: `table columns are not consistent` |
| 8 | 元テーブルを変更しない | is_deeply |
| 9 | `as $var` 形式でオプションを受け取れる | isa HashQuery |
| 10 | `{ as => \$var }` 形式でオプションを受け取れる | isa HashQuery |
| 11 | 空テーブルでインスタンスを生成できる | isa HashQuery |

### SELECT メソッド

| # | テストケース | 期待値 |
|---|---|---|
| 12 | `*` で全列・全行を返す | 5行、a/b/c カラム存在 |
| 13 | 配列リファレンスで列を指定できる | 5行、a/b 存在、c 不在 |
| 14 | `except` で列を除外できる | 5行、a/b 存在、c 不在 |
| 15 | `except` で複数列を除外できる | a 存在、b/c 不在 |
| 16 | `_idx` は出力に含まれない | _idx 不在 |
| 17 | `undef` を渡すと die する | エラー: `SELECT requires` |
| 18 | `where` で行をフィルタできる | 2行（alice, dave） |
| 19 | `having` で集約フィルタできる | 4行（carol 以外） |
| 20 | `where` と `having` を組み合わせられる | 3行（alpha チームのみ） |
| 21 | `as` で count/affect が返る | count=2, affect=2 |
| 22 | 同じインスタンスを複数回呼べる | r1=2行, r2=2行 |
| 23 | 元テーブルは変更されない | is_deeply |

### DELETE メソッド

| # | テストケース | 期待値 |
|---|---|---|
| 24 | `where` にマッチした行を削除して残りを返す | 3行（bob, carol, eve） |
| 25 | 条件なしで全行を返す（何も削除しない） | 5行 |
| 26 | 一致なしで全行残る | 5行 |
| 27 | `having` と組み合わせて削除できる | 1行（carol のみ残る） |
| 28 | `_idx` は出力に含まれない | _idx 不在 |
| 29 | 元テーブルは変更されない | is_deeply |
| 30 | `as` で count/affect が返る | count=3, affect=2 |
| 31 | `SELECT` と対称動作する | selected + deleted = 5 |

### UPDATE メソッド

| # | テストケース | 期待値 |
|---|---|---|
| 32 | `where` にマッチした行を更新して全行返す | 5行、alice/dave の b=99 |
| 33 | `set` 関数形式でも更新できる | 5行、2行が b=99 |
| 34 | 条件なしで全行更新する | 5行、全て b=0 |
| 35 | 一致なしで全行そのまま返す | 5行、b=[10,20,30,10,20] |
| 36 | `having` と組み合わせて更新できる | 4行 b=0、carol のみ intact |
| 37 | 複数カラムを同時に更新できる | alice の b=0, c=0 |
| 38 | `_idx` は出力に含まれない | _idx 不在 |
| 39 | 元テーブルは変更されない | is_deeply |
| 40 | `as` で count/affect が返る | count=5, affect=2 |
| 41 | 存在しないカラムを指定すると die する | エラー: `unknown column in UPDATE` |
| 42 | ハッシュリファレンス以外を渡すと die する | エラー: `UPDATE requires a hash reference` |

### 条件メソッド（HashQuery::Value）

| # | テストケース | 期待値 |
|---|---|---|
| 43 | `like`: パターンマッチする | 1行（alice） |
| 44 | `like`: `%` で複数文字にマッチ | 3行（alice, dave, eve） |
| 45 | `not_like`: パターンに一致しない行を返す | 4行（alice 以外） |
| 46 | `between`: 両端含む範囲 | 4行 |
| 47 | `between`: 排他境界 | 0行 |
| 48 | `in`: リストに含まれる行 | 3行（alice, carol, dave） |
| 49 | `not_in`: リストに含まれない行 | 2行（bob, eve） |
| 50 | `asNull`: undef をデフォルト値に置き換える | 1行（y） |

### having 集計関数

| # | テストケース | 期待値 |
|---|---|---|
| 51 | `count_by`: グループ内の行数 | 4行（carol 以外） |
| 52 | `max_by`: グループ内の最大値 | 2行（bob, eve） |
| 53 | `min_by`: グループ内の最小値 | 2行（alice, dave） |
| 54 | `first_by`: グループ内の先頭行 | 3行（alice, bob, carol） |
| 55 | `last_by`: グループ内の末尾行 | 3行（carol, dave, eve） |

### grep_concat

| # | テストケース | 期待値 |
|---|---|---|
| 56 | マッチした行の値を返す | 2行（ERROR 行のみ） |
| 57 | 前後の行を含む文字列を返す（現在行マッチのみ選択） | 2行（ERROR 行のみ） |
| 58 | 指定カラムの値のみ連結する | 1行（line=2） |

### 実用例

| # | テストケース | 期待値 |
|---|---|---|
| 59 | `as` を使って `where` でフィルタ（列射影） | 3行、role カラム不在 |
| 60 | スコア 75 以上かつチームに 2 人以上いるメンバー | 3行（alice, bob, carol） |
