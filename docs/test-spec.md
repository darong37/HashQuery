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

### @ab_tbl（No.56 用）

| a | b |
|---|---|
| x | 1 |
| x | 1 |
| x | 2 |
| y | 1 |

### @undef_val_tbl（No.60, 61 用）

| g | v       |
|---|---------|
| a | (undef) |
| b | 10      |

### @duo_tbl（No.64 用）

| g    | v |
|------|---|
| solo | 1 |
| duo  | 2 |
| duo  | 3 |

### @abv_tbl（No.65 用）

| a | b | v      |
|---|---|--------|
| x | 1 | first  |
| x | 1 | second |
| x | 2 | only   |

---

## テストケース

### 1. query — 基本動作

| No. | 説明 | 入力 / 条件 | 期待結果 |
|-----|------|------------|---------|
| 1 | DSLなしで全行を返す | `query \@base` | 行数 5 |
| 2 | DSLなしで全列を返す | `query \@base` | 先頭行のキーが `[a, b, c]`（ソート済み） |
| 3 | 空テーブルを渡すと空配列を返す | `query([])` | 行数 0 |
| 4 | 戻り値は AOH（配列リファレンス） | `query \@base` | `ref $r` が `'ARRAY'`、`ref $r->[0]` が `'HASH'` |
| 5 | 配列リファレンス以外を渡すと die する | `query {}` | `"Array of Hash"` を含むメッセージで die |
| 6 | 行のカラム構成が不一致だと die する | `query [{ a => 1 }, { a => 1, b => 2 }]` | `"consistent"` を含むメッセージで die |
| 7 | 無効な DSL 部品を渡すと die する | `query \@base, { unknown_key => 1 }` | `"invalid DSL"` を含むメッセージで die |
| 8 | 入力テーブルは変更されない（不変性） | `@base` に対して `where { $_->{a} > 1 }` を実行 | クエリ後も `@base` の内容が変化しない |

### 2. SELECT

| No. | 説明 | 入力 / 条件 | 期待結果 |
|-----|------|------------|---------|
| 9 | カラム明示指定で指定列のみ返す | `@base`、`SELECT [qw/a b/]` | 列 a・b のみ存在、c は存在しない、行数 5 |
| 10 | 行数は変わらない | `@base`、`SELECT [qw/a/]` | 行数 5 |
| 11 | except で指定カラムを除外する | `@base`、`SELECT { except => ['c'] }` | a・b 存在、c は存在しない |
| 12 | except で複数カラムを除外する | `@base`、`SELECT { except => [qw/b c/] }` | 先頭行のキーが `[a]` のみ |
| 13 | `'*'` で全列を返す | `@base`、`SELECT '*'` | 先頭行のキーが `[a, b, c]`（ソート済み） |
| 14 | 引数なしで全列を返す | `@base`、`SELECT` | 先頭行のキーが `[a, b, c]`（ソート済み） |
| 15 | `_idx` は出力に含まれない | `@base`、`SELECT '*'` | 先頭行に `_idx` キーが存在しない |
| 16 | `_idx` は明示指定しても出力に含まれない | `@base`、`SELECT [qw/a b c/]` | 先頭行に `_idx` キーが存在しない |

### 3. where

| No. | 説明 | 入力 / 条件 | 期待結果 |
|-----|------|------------|---------|
| 17 | `$_` でフィルタする（as なし） | `@base`、`where { $_->{b} == 10 }` | 行数 2、a: alice, dave |
| 18 | as で alias 変数を使ってフィルタする | `@base`、`as $t1`、`where { $t1->{b} >= 20 }` | 行数 3、先頭行 a = 'bob' |
| 19 | as を指定しても `$_` で参照できる | `@base`、`as $t2`、`where { $_->{b} == 30 }` | 行数 1、a = 'carol' |
| 20 | 全行一致した場合は全行返す | `@base`、`where { $_->{b} > 0 }` | 行数 5 |
| 21 | 条件を満たす行がない場合は空配列 | `@base`、`where { $_->{b} > 999 }` | 行数 0 |
| 22 | `_idx` で行番号を使ってフィルタできる | `@base`、`where { $_->{_idx} == 2 }` | 行数 1、a = 'carol' |
| 24 | like 前方一致 | `@base`、`where { $_->{a}->like('a%') }` | 行数 1、a = 'alice' |
| 25 | like 後方一致 | `@base`、`where { $_->{a}->like('%e') }` | 行数 3、a: alice, dave, eve |
| 26 | like 中間一致 | `@base`、`where { $_->{a}->like('%li%') }` | 行数 1、a = 'alice' |
| 27 | like `_` ワイルドカード（1文字） | `@base`、`where { $_->{a}->like('b__') }` | 行数 1、a = 'bob' |
| 28 | like 完全一致 | `@base`、`where { $_->{a}->like('carol') }` | 行数 1、a = 'carol' |
| 29 | like undef は false を返す | `@null_tbl`、`where { $_->{val}->like('%') }` | 行数 2、name: y, z（undef の x は除外） |
| 30 | not_like 否定条件 | `@base`、`where { $_->{a}->not_like('a%') }` | 行数 4、alice を含まない |
| 31 | not_like undef は true を返す | `@null_tbl`、`where { $_->{val}->not_like('%') }` | 行数 1、name = 'x'（undef のみ） |
| 32 | between 境界値を含む（通常範囲） | `@base`、`where { $_->{b}->between(10, 20) }` | 行数 4、b=10 と b=20 の全行 |
| 33 | between 境界値ちょうどで一致する（下限） | `@base`、`where { $_->{b}->between(10, 10) }` | 行数 2、b=10 のみ |
| 34 | between 下限排他（`!` 付き） | `@base`、`where { $_->{b}->between('10!', 30) }` | 行数 3、b > 10 かつ b <= 30 |
| 35 | between 上限排他（`!` 付き） | `@base`、`where { $_->{b}->between(10, '20!') }` | 行数 2、b=10 のみ |
| 36 | between 両端排他 | `@base`、`where { $_->{b}->between('10!', '30!') }` | 行数 2、b=20 のみ |
| 37 | between undef は false を返す | `@null_tbl`、`where { $_->{val}->between(0, 100) }` | 行数 1、name = 'y' |
| 38 | in 配列リファレンスで一致 | `@base`、`where { $_->{a}->in(['alice', 'carol']) }` | 行数 2、a: alice, carol |
| 39 | in フラットリストでも一致する | `@base`、`where { $_->{a}->in('alice', 'carol') }` | 行数 2、a: alice, carol |
| 40 | in 空リストはすべて false | `@base`、`where { $_->{a}->in([]) }` | 行数 0 |
| 41 | in undef は false を返す | `@null_tbl`、`where { $_->{val}->in([42]) }` | 行数 1、name = 'y' |
| 42 | not_in 配列リファレンスで除外 | `@base`、`where { $_->{a}->not_in(['alice', 'carol']) }` | 行数 3、a: bob, dave, eve |
| 43 | not_in フラットリストでも除外できる | `@base`、`where { $_->{a}->not_in('alice', 'carol') }` | 行数 3、a: bob, dave, eve |
| 44 | asNull undef をデフォルト値に置換する | `@null_tbl`、`where { $_->{val}->asNull(0) == 0 }` | 行数 2、name: x, z |
| 45 | asNull 空文字をデフォルト値に置換する | `@null_tbl`、`where { $_->{val}->asNull('none') eq 'none' }` | 行数 2、name: x, z |
| 46 | asNull 値が存在する場合は元の値を返す | `@null_tbl`、`where { $_->{val}->asNull(0) == 42 }` | 行数 1、name = 'y' |

### 4. grep_concat

| No. | 説明 | 入力 / 条件 | 期待結果 |
|-----|------|------------|---------|
| 47 | 一致しない行は空文字を返す | `@log_tbl`、`grep_concat('msg', qr/ERROR/, 0, 0) ne ''` で絞り込み | 行数 2（line=2, 4） |
| 48 | `$start=0 $end=0` で現在行のみ取得 | `@log_tbl`、`grep_concat('msg', qr/ERROR/, 0, 0)` の結果を収集 | 収集 2件、各結果に `"ERROR"` を含む、`"INFO"` は含まない |
| 49 | 前後行を含むコンテキストを取得 | `@log_tbl`、`grep_concat('msg', qr/ERROR/, -1, 1)` の結果を収集 | 収集 2件、line=2 の結果に `"INFO  start"` / `"ERROR connection failed"` / `"INFO  retrying"` をすべて含む |
| 50 | 先頭行での `$start=-1` は境界でクランプされる | `@edge_log`、`grep_concat('msg', qr/ERROR first/, -1, 1)` の結果を収集 | 収集 1件、`"ERROR first"` と `"INFO  second"` を含む、`"INFO  third"` は含まない |
| 51 | 末尾行での `$end=1` は境界でクランプされる | `@edge_log`、`grep_concat('msg', qr/ERROR last/, -1, 1)` の結果を収集 | 収集 1件、`"INFO  fourth"` と `"ERROR last"` を含む、`"INFO  third"` は含まない |
| 52 | `$start` 省略時は 0（現在行） | `@log_tbl`、`grep_concat('msg', qr/ERROR/)` の結果を収集 | 収集 2件、各結果を改行で split すると行数が 1 |
| 53 | undef カラムは空文字を返す | `@null_tbl`、`grep_concat('val', qr/.+/, 0, 0) ne ''` で絞り込み | 行数 1、name = 'y' |
| 54 | `_idx` は連結文字列に含まれない | `@log_tbl`、`grep_concat('msg', qr/ERROR/, 0, 0)` の結果を収集 | 収集 2件、全結果に `"_idx"` が含まれない |
| 82 | `=~` で直前コンテキストにマッチする ERROR 行を抽出 | `@log_tbl`、`grep_concat('msg', qr/ERROR/, -1, 0) =~ /start/` | 行数 1、line=2（ERROR connection failed） |
| 83 | `=~` で直後コンテキストに ERROR を含む INFO 行を抽出 | `@log_tbl`、`grep_concat('msg', qr/INFO/, 0, 1) =~ /ERROR/` | 行数 2、line=1, 3 |
| 84 | `!~` でリトライなしの ERROR 行を抽出 | `@log_tbl`、`grep_concat` が `ne ''` かつ `!~ /retrying/` | 行数 1、line=4（ERROR timeout） |
| 85 | `!~` でコンテキストの内容で ERROR 行を区別する | `@edge_log`、`grep_concat('msg', qr/ERROR/, -1, 1)` が `ne ''` かつ `!~ /fourth/` | 行数 1、line=1（ERROR first） |
| 90 | 指定カラムの値のみが結果に含まれる（単一行） | `@log_tbl`、`grep_concat('msg', qr/ERROR/, 0, 0)` の結果を収集 | 収集 2件、各結果が数値で始まらない（`line` の値が混入しない） |
| 91 | コンテキスト行でも指定カラムのみが含まれる | `@log_tbl`、`grep_concat('msg', qr/ERROR/, -1, 1)` の結果を収集 | 収集 2件、全行が数値で始まらない |
| 92 | 多カラムテーブルで指定カラム以外の値が混入しない | `@members`、`grep_concat('name', qr/alice/, 0, 0)` の結果を収集 | 収集 1件、`$results[0]` が `"alice\n"` と等しい |
| 93 | 指定カラムの値と等値比較できること | `@members`、`grep_concat('name', qr/dave/, 0, 0)` の結果を収集 | 収集 1件、`$results[0]` が `"dave\n"` と等しい |

### 5. having

| No. | 説明 | 入力 / 条件 | 期待結果 |
|-----|------|------------|---------|
| 55 | count_by で1件グループを除外する | `@base`、`having { count_by('b') > 1 }` | 行数 4、carol（b=30）は除外 |
| 56 | count_by 複数キーでグループ化 | `@ab_tbl`、`having { count_by(qw/a b/) > 1 }` | 行数 2、(a='x', b=1) グループのみ |
| 57 | count_by の集計対象は where 後のテーブル | `@base`、`where { $th2->{b} <= 20 }`、`having { count_by('b') > 1 }` | 行数 4（where で carol 除外後、b=10/20 は各 2件） |
| 58 | max_by でグループ最大値が条件を満たす行を残す | `@base`、`having { max_by('c', 'b') > 200 }` | 行数 3、b=20/30 グループのみ（alice, dave は除外） |
| 59 | min_by でグループ最小値が条件を満たす行を残す | `@base`、`having { min_by('c', 'b') < 200 }` | 行数 2、b=10 グループのみ（alice, dave） |
| 60 | max_by グループ内に有効値がない場合 undef を返す | `@undef_val_tbl`、`having { !defined max_by('v', 'g') }` | 行数 1、g='a'（v が全て undef） |
| 61 | min_by グループ内に有効値がない場合 undef を返す | `@undef_val_tbl`、`having { !defined min_by('v', 'g') }` | 行数 1、g='a' |
| 62 | first_by でグループ先頭行のみ残す | `@base`、`having { first_by('b') }` | 行数 3、alice（b=10）/ bob（b=20）/ carol（b=30） |
| 63 | last_by でグループ末尾行のみ残す | `@base`、`having { last_by('b') }` | 行数 3、carol（b=30）/ dave（b=10）/ eve（b=20） |
| 64 | first_by 1件グループは先頭かつ末尾 | `@duo_tbl`、`first_by('g')` と `last_by('g')` を各クエリで実行 | 両クエリとも g='solo' の行が含まれる |
| 65 | first_by 複数キーでグループ化 | `@abv_tbl`、`having { first_by(qw/a b/) }` | 行数 2、v='first' と v='only'（v='second' は除外） |
| 66 | count_by を having 外で呼ぶと die する | `count_by('a')` を having 外で呼ぶ | `"having"` を含むメッセージで die |
| 67 | max_by を having 外で呼ぶと die する | `max_by('a', 'b')` を having 外で呼ぶ | `"having"` を含むメッセージで die |
| 68 | min_by を having 外で呼ぶと die する | `min_by('a', 'b')` を having 外で呼ぶ | `"having"` を含むメッセージで die |
| 69 | first_by を having 外で呼ぶと die する | `first_by('a')` を having 外で呼ぶ | `"having"` を含むメッセージで die |
| 70 | last_by を having 外で呼ぶと die する | `last_by('a')` を having 外で呼ぶ | `"having"` を含むメッセージで die |
| 71 | as で alias 変数を使って行の値を参照できる | `@base`、`as $th1`、`having { $th1->{b} == 10 and count_by('b') > 1 }` | 行数 2、alice と dave |
| 72 | as なしでも `$_` で行の値を参照できる | `@base`、`having { $_->{b} == 10 and count_by('b') > 1 }` | 行数 2、alice と dave |

### 6. as

| No. | 説明 | 入力 / 条件 | 期待結果 |
|-----|------|------------|---------|
| 23 | クエリ完了後にレコード数が格納される | `@base`、`as $tc`、`where { $_->{b} == 10 }` | クエリ後 `$tc->{count}` = 2、`$tc->{affect}` = 2 |

### 7. 組み合わせ

| No. | 説明 | 入力 / 条件 | 期待結果 |
|-----|------|------------|---------|
| 73 | SELECT を where より前に書いても同じ結果 | `@base`、パターン1: `SELECT → where`、パターン2: `where → SELECT` | `$r1` と `$r2` が等価 |
| 74 | having を where より前に書いても同じ結果 | `@base`、パターン1: `having → where`、パターン2: `where → having` | `$r1` と `$r2` が等価 |
| 75 | as を後ろに書いても動作する | `@base`、`where { $td1->{b} == 10 }`、`as $td1`（as を where より後に記述） | 行数 2、alice と dave |
| 76 | where + SELECT | `@base`、`as $tc75`、`SELECT [qw/a/]`、`where { $tc75->{b} == 10 }` | 行数 2、キーが `[a]` のみ |
| 77 | where + SELECT（except） | `@base`、`as $tc76`、`SELECT { except => ['b'] }`、`where { $tc76->{b} == 10 }` | 行数 2、a・c 存在、b なし |
| 78 | where + having + SELECT | `@base`、`as $tc1`、`SELECT [qw/a b/]`、`where { $tc1->{b} <= 20 }`、`having { count_by('b') > 1 }` | 行数 4、c カラムなし |
| 79 | grep_concat + where で条件絞り込み | `@log_tbl`、`SELECT [qw/line msg/]`、`where { grep_concat('msg', qr/ERROR/, 0, 0) ne '' }` | 行数 2、line=2, 4 |
| 80 | where + having（having は where 後のテーブルを集計） | `@base`、`where { $tc79->{a} ne 'carol' }`、`having { count_by('b') > 1 }` | 行数 4（carol 除外後 b=10/20 は各 2件） |
| 81 | スペック記載のフルサンプル | `@base`、`select { except => ['c'] }`、`where { a gt 'abc' and 10 <= b <= 20 }`、`having { b >= 10 and count_by > 1 and max_by > 100 }` | 行数 4、a: alice, bob, dave, eve、c カラムなし |
| 86 | リードのみ絞り込んでチームと名前を取得 | `@members`、`SELECT [qw/team name/]`、`where { $m1->{role} eq 'lead' }` | 行数 3、列 team・name のみ |
| 87 | チームの最高スコアが90以上のチームのメンバーを取得 | `@members`、`SELECT [qw/team name score/]`、`having { max_by('score', 'team') >= 90 }` | 行数 4、beta チームは除外 |
| 88 | スコア75以上かつチームに2人以上いるメンバーを取得 | `@members`、`where { $m3->{score} >= 75 }`、`having { count_by('team') >= 2 }` | 行数 3、alpha チームのみ |
| 89 | スコア75以上のメンバーからチームごとの先頭を取得 | `@members`、`where { $m4->{score} >= 75 }`、`having { first_by('team') }` | 行数 3、alice / dave / frank |

### 8. DELETE

| No. | 説明 | 入力 / 条件 | 期待結果 |
|-----|------|------------|---------|
| 94 | DSL ノードを返す | `DELETE()` を呼び出す | `{ delete => 1 }` |
| 95 | `UPDATE` と同時に指定すると die する | `query \@base, DELETE, UPDATE { b => 0 }` | `"DELETE and UPDATE cannot be used together"` を含む die |
| 96 | where にマッチした行を削除して残りを返す | `@base`、`DELETE`、`where { $_->{b} == 10 }` | 行数 3、a: bob, carol, eve |
| 97 | 条件なしで全行削除する | `@base`、`DELETE` | 行数 0 |
| 98 | 一致なしで全行残る | `@base`、`DELETE`、`where { $_->{b} > 999 }` | 行数 5 |
| 99 | having と組み合わせて削除できる | `@base`、`DELETE`、`having { count_by('b') > 1 }` | 行数 1、a = 'carol' |
| 100 | 元テーブルは変更されない | `@base` で DELETE 実行後 | `@base` の内容が変化しない |
| 101 | `_idx` は出力に含まれない | `@base`、`DELETE`、`where { $_->{b} > 999 }` | 先頭行に `_idx` キーが存在しない |
| 102 | as で count と affect が返る | `@base`、`as $td`、`DELETE`、`where { $_->{b} == 10 }` | `$td->{count}` = 3、`$td->{affect}` = 2 |
| 103 | SELECT と同じ条件で対称動作する | `@base` に対して SELECT と DELETE を同じ where 条件で実行 | 両者の行数の合計が 5 |

### 9. UPDATE

| No. | 説明 | 入力 / 条件 | 期待結果 |
|-----|------|------------|---------|
| 104 | DSL ノードを返す | `UPDATE { score => 100 }` | `{ update => { score => 100 } }` |
| 105 | 複数カラム指定の DSL ノードを返す | `UPDATE { score => 100, grade => 'A' }` | `{ update => { score => 100, grade => 'A' } }` |
| 106 | ハッシュリファレンス以外は die する | `UPDATE('invalid')` | `"UPDATE requires a hash reference"` を含む die |
| 107 | `DELETE` と同時に指定すると die する | `query \@base, DELETE, UPDATE { b => 0 }` | `"DELETE and UPDATE cannot be used together"` を含む die |
| 108 | where にマッチした行を更新して全行返す | `@base`、`UPDATE { b => 99 }`、`where { $_->{b} == 10 }` | 全5行返る。alice・dave の b が 99 |
| 109 | 条件なしで全行更新する | `@base`、`UPDATE { b => 0 }` | 全5行の b が 0 |
| 110 | 一致なしで全行そのまま返す | `@base`、`UPDATE { b => 0 }`、`where { $_->{b} > 999 }` | 全5行 b が元の値のまま |
| 111 | having と組み合わせて更新できる | `@base`、`UPDATE { b => 0 }`、`having { count_by('b') > 1 }` | b==0 が4行、carol のみ元の値 |
| 112 | 複数カラムを同時に更新できる | `@base`、`UPDATE { b => 0, c => 0 }`、`where { $_->{a} eq 'alice' }` | alice の b・c が 0 |
| 113 | 元テーブルは変更されない | UPDATE 実行後に元配列を確認 | 元配列の内容が変化しない |
| 114 | `_idx` は出力に含まれない | `@base`、`UPDATE { b => 0 }`、`where { $_->{b} > 999 }` | 先頭行に `_idx` キーが存在しない |
| 115 | as で count と affect が返る | `@base`、`as $tu`、`UPDATE { b => 0 }`、`where { $_->{b} == 10 }` | `$tu->{count}` = 5、`$tu->{affect}` = 2 |
| 116 | 存在しないカラムを指定すると die する | `query \@base, UPDATE { nonexistent => 1 }` | `"unknown column in UPDATE: nonexistent"` を含む die |
