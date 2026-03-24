# HashQuery テスト仕様書

## テストデータ定義

本テストで使用するテーブルは以下のとおり。

### @base

| a       | b  | c   |
|---------|----|-----|
| alice   | 10 | 100 |
| bob     | 20 | 200 |
| carol   | 30 | 300 |
| dave    | 10 | 150 |
| eve     | 20 | 250 |

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

---

## 1. query — 基本動作

### No.1 DSLなしで全行を返す

```perl
my $r = query \@base;
```

**入力テーブル** — `@base`

**期待結果**

戻り値の行数が 5

---

### No.2 DSLなしで全列を返す

```perl
my $r = query \@base;
```

**入力テーブル** — `@base`

**期待結果**

先頭行のキーが `[a, b, c]`（ソート済み）

---

### No.3 空テーブルを渡すと空配列を返す

```perl
my $r = query([]);
```

**入力テーブル**

`[]`（空配列）

**期待結果**

`[]` と等価（行数 0）

---

### No.4 戻り値は AOH（配列リファレンス）

```perl
my $r = query \@base;
```

**入力テーブル** — `@base`

**期待結果**

- `ref $r` が `'ARRAY'`
- `ref $r->[0]` が `'HASH'`

---

### No.5 配列リファレンス以外を渡すとdieする

```perl
eval { query {} };
```

**入力テーブル**

`{}`（ハッシュリファレンス）

**期待結果**

`"Array of Hash"` を含むエラーメッセージで die する

---

### No.6 行のカラム構成が不一致だとdieする

```perl
eval { query [{ a => 1 }, { a => 1, b => 2 }] };
```

**入力テーブル**

| a | b      |
|---|--------|
| 1 | (なし) |
| 1 | 2      |

**期待結果**

`"consistent"` を含むエラーメッセージで die する

---

### No.7 無効なDSL部品を渡すとdieする

```perl
eval { query \@base, { unknown_key => 1 } };
```

**入力テーブル** — `@base`

**期待結果**

`"invalid DSL"` を含むエラーメッセージで die する

---

### No.8 入力テーブルは変更されない（不変性）

```perl
my @orig = ({ a => 1, b => 2 }, { a => 3, b => 4 });
my @copy = map { +{ %$_ } } @orig;
query \@orig,
    where { $_->{a} > 1 };
```

**入力テーブル**

| a | b |
|---|---|
| 1 | 2 |
| 3 | 4 |

**期待結果**

クエリ実行後も `@orig` の内容がクエリ前（`@copy`）と等価（元データが変更されていない）

---

## 2. select

### No.9 カラム明示指定で指定列のみ返す

```perl
my $r = query \@base,
    select [qw/a b/];
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  |
|-------|----|
| alice | 10 |
| bob   | 20 |
| carol | 30 |
| dave  | 10 |
| eve   | 20 |

c カラムは存在しない

---

### No.10 行数は変わらない

```perl
my $r = query \@base,
    select [qw/a/];
```

**入力テーブル** — `@base`

**期待結果**

戻り値の行数が 5

---

### No.11 except で指定カラムを除外する

```perl
my $r = query \@base,
    select { except => ['c'] };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  |
|-------|----|
| alice | 10 |
| bob   | 20 |
| carol | 30 |
| dave  | 10 |
| eve   | 20 |

a・b は存在する、c は存在しない

---

### No.12 except で複数カラムを除外する

```perl
my $r = query \@base,
    select { except => [qw/b c/] };
```

**入力テーブル** — `@base`

**期待結果**

先頭行のキーが `[a]` のみ

---

### No.13 "*" で全列を返す

```perl
my $r = query \@base,
    select '*';
```

**入力テーブル** — `@base`

**期待結果**

先頭行のキーが `[a, b, c]`（ソート済み）

---

### No.14 引数なしで全列を返す

```perl
my $r = query \@base,
    select;
```

**入力テーブル** — `@base`

**期待結果**

先頭行のキーが `[a, b, c]`（ソート済み）

---

### No.15 _idx は出力に含まれない

```perl
my $r = query \@base,
    select '*';
```

**入力テーブル** — `@base`

**期待結果**

先頭行に `_idx` キーが存在しない

---

### No.16 _idx は明示指定しても出力に含まれない

```perl
my $r = query \@base,
    select [qw/a b c/];
```

**入力テーブル** — `@base`

**期待結果**

先頭行に `_idx` キーが存在しない

---

## 3. where — 基本フィルタ

### No.17 $_ でフィルタする（asなし）

```perl
my $r = query \@base,
    where { $_->{b} == 10 };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |
| dave  | 10 | 150 |

---

### No.18 as で alias 変数を使ってフィルタする

```perl
our $t1;
my $r = query \@base,
    as $t1,
    where { $t1->{b} >= 20 };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| bob   | 20 | 200 |
| carol | 30 | 300 |
| eve   | 20 | 250 |

先頭行の a が `'bob'`（3行）

---

### No.19 as を指定しても $_ で参照できる

```perl
our $t2;
my $r = query \@base,
    as $t2,
    where { $_->{b} == 30 };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| carol | 30 | 300 |

---

### No.20 全行一致した場合は全行返す

```perl
my $r = query \@base,
    where { $_->{b} > 0 };
```

**入力テーブル** — `@base`

**期待結果**

戻り値の行数が 5（全行一致）

---

### No.21 条件を満たす行がない場合は空配列

```perl
my $r = query \@base,
    where { $_->{b} > 999 };
```

**入力テーブル** — `@base`

**期待結果**

`[]` と等価（行数 0）

---

### No.22 _idx で行番号を使ってフィルタできる

```perl
my $r = query \@base,
    where { $_->{_idx} == 2 };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| carol | 30 | 300 |

`_idx` は 0始まりのインデックスで、2 = 3行目（carol）

---

## 4. where — like / not_like

### No.23 like 前方一致

```perl
my $r = query \@base,
    where { $_->{a}->like('a%') };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |

---

### No.24 like 後方一致

```perl
my $r = query \@base,
    where { $_->{a}->like('%e') };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |
| dave  | 10 | 150 |
| eve   | 20 | 250 |

---

### No.25 like 中間一致

```perl
my $r = query \@base,
    where { $_->{a}->like('%li%') };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |

---

### No.26 like \_ ワイルドカード（1文字）

```perl
my $r = query \@base,
    where { $_->{a}->like('b__') };
```

**入力テーブル** — `@base`

**期待結果**

| a   | b  | c   |
|-----|----|-----|
| bob | 20 | 200 |

`'b__'` は 'b' で始まる3文字（`_` は任意の1文字）

---

### No.27 like 完全一致

```perl
my $r = query \@base,
    where { $_->{a}->like('carol') };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| carol | 30 | 300 |

---

### No.28 like undefはfalseを返す

```perl
my $r = query \@null_tbl,
    where { $_->{val}->like('%') };
```

**入力テーブル** — `@null_tbl`

**期待結果**

| name | val     |
|------|---------|
| y    | 42      |
| z    | (空文字) |

val が undef の行（name='x'）は false となり除外される（2行）

---

### No.29 not_like 否定条件

```perl
my $r = query \@base,
    where { $_->{a}->not_like('a%') };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| bob   | 20 | 200 |
| carol | 30 | 300 |
| dave  | 10 | 150 |
| eve   | 20 | 250 |

alice を含まない 4行

---

### No.30 not_like undefはtrueを返す

```perl
my $r = query \@null_tbl,
    where { $_->{val}->not_like('%') };
```

**入力テーブル** — `@null_tbl`

**期待結果**

| name | val     |
|------|---------|
| x    | (undef) |

val が undef の行（name='x'）のみが true（1行）

---

## 5. where — between

### No.31 between 境界値を含む（通常範囲）

```perl
my $r = query \@base,
    where { $_->{b}->between(10, 20) };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |
| bob   | 20 | 200 |
| dave  | 10 | 150 |
| eve   | 20 | 250 |

b=10 と b=20 の全行（4行）、境界値を含む

---

### No.32 between 境界値ちょうどで一致する（下限）

```perl
my $r = query \@base,
    where { $_->{b}->between(10, 10) };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |
| dave  | 10 | 150 |

すべて b=10（2行）

---

### No.33 between 下限排他（! 付き）

```perl
my $r = query \@base,
    where { $_->{b}->between('10!', 30) };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| bob   | 20 | 200 |
| carol | 30 | 300 |
| eve   | 20 | 250 |

b > 10 かつ b <= 30（b=10 の行を含まない、3行）

---

### No.34 between 上限排他（! 付き）

```perl
my $r = query \@base,
    where { $_->{b}->between(10, '20!') };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |
| dave  | 10 | 150 |

b >= 10 かつ b < 20（b=10 のみ、2行）

---

### No.35 between 両端排他

```perl
my $r = query \@base,
    where { $_->{b}->between('10!', '30!') };
```

**入力テーブル** — `@base`

**期待結果**

| a   | b  | c   |
|-----|----|-----|
| bob | 20 | 200 |
| eve | 20 | 250 |

b > 10 かつ b < 30（b=20 のみ、2行）

---

### No.36 between undefはfalseを返す

```perl
my $r = query \@null_tbl,
    where { $_->{val}->between(0, 100) };
```

**入力テーブル** — `@null_tbl`

**期待結果**

| name | val |
|------|-----|
| y    | 42  |

val が undef の行（name='x'）は false となり除外される（1行）

---

## 6. where — in / not_in

### No.37 in 配列リファレンスで一致

```perl
my $r = query \@base,
    where { $_->{a}->in(['alice', 'carol']) };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |
| carol | 30 | 300 |

---

### No.38 in フラットリストでも一致する

```perl
my $r = query \@base,
    where { $_->{a}->in('alice', 'carol') };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |
| carol | 30 | 300 |

フラットリストでも配列リファレンスと同じ結果（2行）

---

### No.39 in 空リストはすべてfalse

```perl
my $r = query \@base,
    where { $_->{a}->in([]) };
```

**入力テーブル** — `@base`

**期待結果**

`[]` と等価（行数 0）

---

### No.40 in undefはfalseを返す

```perl
my $r = query \@null_tbl,
    where { $_->{val}->in([42]) };
```

**入力テーブル** — `@null_tbl`

**期待結果**

| name | val |
|------|-----|
| y    | 42  |

val が undef の行（name='x'）は false（1行）

---

### No.41 not_in 配列リファレンスで除外

```perl
my $r = query \@base,
    where { $_->{a}->not_in(['alice', 'carol']) };
```

**入力テーブル** — `@base`

**期待結果**

| a    | b  | c   |
|------|----|-----|
| bob  | 20 | 200 |
| dave | 10 | 150 |
| eve  | 20 | 250 |

alice・carol を含まない 3行

---

### No.42 not_in フラットリストでも除外できる

```perl
my $r = query \@base,
    where { $_->{a}->not_in('alice', 'carol') };
```

**入力テーブル** — `@base`

**期待結果**

| a    | b  | c   |
|------|----|-----|
| bob  | 20 | 200 |
| dave | 10 | 150 |
| eve  | 20 | 250 |

フラットリストでも配列リファレンスと同じ結果（3行）

---

## 7. where — asNull

### No.43 asNull undef をデフォルト値に置換する

```perl
my $r = query \@null_tbl,
    where { $_->{val}->asNull(0) == 0 };
```

**入力テーブル** — `@null_tbl`

**期待結果**

| name | val     |
|------|---------|
| x    | (undef) |
| z    | (空文字) |

undef と空文字がデフォルト値 0 に置換され `== 0` でマッチ（2行）

---

### No.44 asNull 空文字をデフォルト値に置換する

```perl
my $r = query \@null_tbl,
    where { $_->{val}->asNull('none') eq 'none' };
```

**入力テーブル** — `@null_tbl`

**期待結果**

| name | val     |
|------|---------|
| x    | (undef) |
| z    | (空文字) |

undef と空文字がデフォルト値 `'none'` に置換され `eq 'none'` でマッチ（2行）

---

### No.45 asNull 値が存在する場合は元の値を返す

```perl
my $r = query \@null_tbl,
    where { $_->{val}->asNull(0) == 42 };
```

**入力テーブル** — `@null_tbl`

**期待結果**

| name | val |
|------|-----|
| y    | 42  |

val=42 は asNull の影響を受けず元の値でマッチ（1行）

---

## 8. grep_concat

### No.46 一致しない行は空文字を返す

```perl
my $r = query \@log_tbl,
    where { grep_concat('msg', qr/ERROR/, 0, 0) ne '' };
```

**入力テーブル** — `@log_tbl`

**期待結果**

| line | msg                     |
|------|-------------------------|
| 2    | ERROR connection failed |
| 4    | ERROR timeout           |

ERROR にマッチしない行（INFO で始まる行）は grep_concat が空文字を返し除外される（2行）

---

### No.47 $start=0 $end=0 で現在行のみ取得

```perl
my @out;
query \@log_tbl,
    where {
        my $s = grep_concat('msg', qr/ERROR/, 0, 0);
        push @out, $s if $s ne '';
        1;
    };
```

**入力テーブル** — `@log_tbl`

**期待結果**

`@out` に 2件収集される。各結果に `"ERROR connection failed"` が含まれ `"INFO"` は含まれない

---

### No.48 前後行を含むコンテキストを取得

```perl
my @out;
query \@log_tbl,
    where {
        my $s = grep_concat('msg', qr/ERROR/, -1, 1);
        push @out, $s if $s ne '';
        1;
    };
```

**入力テーブル** — `@log_tbl`

**期待結果**

`@out` に 2件収集される。最初の結果（line=2 の ERROR 行）が以下をすべて含む:
- `"INFO  start"`（前の行）
- `"ERROR connection failed"`（現在行）
- `"INFO  retrying"`（次の行）

---

### No.49 先頭行での $start=-1 は境界でクランプされる

```perl
my @out;
query \@edge_log,
    where {
        my $s = grep_concat('msg', qr/ERROR first/, -1, 1);
        push @out, $s if $s ne '';
        1;
    };
```

**入力テーブル** — `@edge_log`

**期待結果**

`@out` に 1件収集される。結果が以下を満たす:
- `"ERROR first"` を含む
- `"INFO  second"` を含む（次の行）
- `"INFO  third"` は含まない（+2行目は範囲外）

---

### No.50 末尾行での $end=1 は境界でクランプされる

```perl
my @out;
query \@edge_log,
    where {
        my $s = grep_concat('msg', qr/ERROR last/, -1, 1);
        push @out, $s if $s ne '';
        1;
    };
```

**入力テーブル** — `@edge_log`

**期待結果**

`@out` に 1件収集される。結果が以下を満たす:
- `"INFO  fourth"` を含む（前の行）
- `"ERROR last"` を含む
- `"INFO  third"` は含まない（-2行目は範囲外）

---

### No.51 $start 省略時は 0（現在行）

```perl
my @out;
query \@log_tbl,
    where {
        my $s = grep_concat('msg', qr/ERROR/);
        push @out, $s if $s ne '';
        1;
    };
```

**入力テーブル** — `@log_tbl`

**期待結果**

`@out` に 2件収集される。各結果を改行で split すると行数が 1（現在行のみ含む）

---

### No.52 undef カラムは空文字を返す

```perl
my $r = query \@null_tbl,
    where { grep_concat('val', qr/.+/, 0, 0) ne '' };
```

**入力テーブル** — `@null_tbl`

**期待結果**

| name | val |
|------|-----|
| y    | 42  |

val=undef と val=空文字は grep_concat が空文字を返し除外される（1行）

---

### No.53 _idx は連結文字列に含まれない

```perl
my @out;
query \@log_tbl,
    where {
        my $s = grep_concat('msg', qr/ERROR/, 0, 0);
        push @out, $s if $s ne '';
        1;
    };
```

**入力テーブル** — `@log_tbl`

**期待結果**

`@out` に 2件収集される。全結果に `"_idx"` が含まれない

---

## 9. having — count_by

### No.54 count_by で1件グループを除外する

```perl
my $r = query \@base,
    having { count_by('b') > 1 };
```

**入力テーブル** — `@base`

グループ（b 値）ごとの件数:

| b  | count | > 1 |
|----|-------|-----|
| 10 | 2     | ○   |
| 20 | 2     | ○   |
| 30 | 1     | ×   |

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |
| bob   | 20 | 200 |
| dave  | 10 | 150 |
| eve   | 20 | 250 |

carol（b=30）は 1件グループのため除外（4行）

---

### No.55 count_by 複数キーでグループ化

```perl
my $r = query \@tbl,
    having { count_by(qw/a b/) > 1 };
```

**入力テーブル**

| a | b |
|---|---|
| x | 1 |
| x | 1 |
| x | 2 |
| y | 1 |

グループ（a+b）ごとの件数:

| a | b | count | > 1 |
|---|---|-------|-----|
| x | 1 | 2     | ○   |
| x | 2 | 1     | ×   |
| y | 1 | 1     | ×   |

**期待結果**

| a | b |
|---|---|
| x | 1 |
| x | 1 |

(a='x', b=1) グループのみ count > 1（2行）。b=2 と y の行は除外

---

### No.56 count_by の集計対象は where 後のテーブル

```perl
our $th2;
my $r = query \@base,
    as $th2,
    select '*',
    where  { $th2->{b} <= 20 },
    having { count_by('b') > 1 };
```

**入力テーブル** — `@base`

where 適用後の中間テーブル（carol は除外済み）:

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |
| bob   | 20 | 200 |
| dave  | 10 | 150 |
| eve   | 20 | 250 |

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |
| bob   | 20 | 200 |
| dave  | 10 | 150 |
| eve   | 20 | 250 |

where で carol（b=30）が除外された後、残りの b=10（2件）・b=20（2件）はすべて count > 1（4行）

---

## 10. having — max_by / min_by

### No.57 max_by でグループ最大値が条件を満たす行を残す

```perl
my $r = query \@base,
    having { max_by('c', 'b') > 200 };
```

**入力テーブル** — `@base`

グループ（b 値）ごとの max(c):

| b  | max(c) | > 200 |
|----|--------|-------|
| 10 | 150    | ×     |
| 20 | 250    | ○     |
| 30 | 300    | ○     |

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| bob   | 20 | 200 |
| carol | 30 | 300 |
| eve   | 20 | 250 |

b=10 グループ（alice, dave）は max(c)=150 で条件を満たさず除外（3行）

---

### No.58 min_by でグループ最小値が条件を満たす行を残す

```perl
my $r = query \@base,
    having { min_by('c', 'b') < 200 };
```

**入力テーブル** — `@base`

グループ（b 値）ごとの min(c):

| b  | min(c) | < 200 |
|----|--------|-------|
| 10 | 100    | ○     |
| 20 | 200    | ×     |
| 30 | 300    | ×     |

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |
| dave  | 10 | 150 |

b=10 グループのみ残存（2行）

---

### No.59 max_by グループ内に有効値がない場合 undef を返す

```perl
my $r = query \@tbl,
    having { !defined max_by('v', 'g') };
```

**入力テーブル**

| g | v       |
|---|---------|
| a | (undef) |
| b | 10      |

**期待結果**

| g | v       |
|---|---------|
| a | (undef) |

g='a' グループは v が全て undef のため max_by が undef を返し、`!defined` が真（1行）

---

### No.60 min_by グループ内に有効値がない場合 undef を返す

```perl
my $r = query \@tbl,
    having { !defined min_by('v', 'g') };
```

**入力テーブル**

| g | v       |
|---|---------|
| a | (undef) |
| b | 10      |

**期待結果**

| g | v       |
|---|---------|
| a | (undef) |

g='a' グループのみ（1行）

---

## 11. having — first_by / last_by

### No.61 first_by でグループ先頭行のみ残す

```perl
my $r = query \@base,
    having { first_by('b') };
```

**入力テーブル** — `@base`

グループ（b 値）ごとの先頭行:

| b  | 先頭行 |
|----|--------|
| 10 | alice  |
| 20 | bob    |
| 30 | carol  |

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |
| bob   | 20 | 200 |
| carol | 30 | 300 |

---

### No.62 last_by でグループ末尾行のみ残す

```perl
my $r = query \@base,
    having { last_by('b') };
```

**入力テーブル** — `@base`

グループ（b 値）ごとの末尾行:

| b  | 末尾行 |
|----|--------|
| 10 | dave   |
| 20 | eve    |
| 30 | carol  |

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| carol | 30 | 300 |
| dave  | 10 | 150 |
| eve   | 20 | 250 |

---

### No.63 first_by 1件グループは先頭かつ末尾

```perl
my $r_first = query \@tbl, having { first_by('g') };
my $r_last  = query \@tbl, having { last_by('g')  };
```

**入力テーブル**

| g    | v |
|------|---|
| solo | 1 |
| duo  | 2 |
| duo  | 3 |

**期待結果**

両クエリとも g='solo' の行が含まれる（1件グループは先頭かつ末尾）

---

### No.64 first_by 複数キーでグループ化

```perl
my $r = query \@tbl,
    having { first_by(qw/a b/) };
```

**入力テーブル**

| a | b | v      |
|---|---|--------|
| x | 1 | first  |
| x | 1 | second |
| x | 2 | only   |

**期待結果**

| a | b | v     |
|---|---|-------|
| x | 1 | first |
| x | 2 | only  |

(a='x', b=1) グループの先頭（v='first'）と (a='x', b=2) の先頭（v='only'）の 2行。v='second' は除外

---

## 12. having — エラーケース

### No.65 count_by を having 外で呼ぶとdieする

```perl
eval { count_by('a') };
```

**入力テーブル**

なし（having スコープ外での直接呼び出し）

**期待結果**

`"having"` を含むエラーメッセージで die する

---

### No.66 max_by を having 外で呼ぶとdieする

```perl
eval { max_by('a', 'b') };
```

**入力テーブル**

なし（having スコープ外での直接呼び出し）

**期待結果**

`"having"` を含むエラーメッセージで die する

---

### No.67 min_by を having 外で呼ぶとdieする

```perl
eval { min_by('a', 'b') };
```

**入力テーブル**

なし（having スコープ外での直接呼び出し）

**期待結果**

`"having"` を含むエラーメッセージで die する

---

### No.68 first_by を having 外で呼ぶとdieする

```perl
eval { first_by('a') };
```

**入力テーブル**

なし（having スコープ外での直接呼び出し）

**期待結果**

`"having"` を含むエラーメッセージで die する

---

### No.69 last_by を having 外で呼ぶとdieする

```perl
eval { last_by('a') };
```

**入力テーブル**

なし（having スコープ外での直接呼び出し）

**期待結果**

`"having"` を含むエラーメッセージで die する

---

## 13. having — as との組み合わせ

### No.70 as で alias 変数を使って行の値を参照できる

```perl
our $th1;
my $r = query \@base,
    as $th1,
    select '*',
    having { $th1->{b} == 10 and count_by('b') > 1 };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |
| dave  | 10 | 150 |

b=10 かつ count_by('b') > 1 を満たす行（2行）

---

### No.71 as なしでも $_ で行の値を参照できる

```perl
my $r = query \@base,
    having { $_->{b} == 10 and count_by('b') > 1 };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |
| dave  | 10 | 150 |

---

## 14. DSL 順序独立性

### No.72 select を where より前に書いても同じ結果

```perl
# パターン 1: select → where
my $r1 = query \@base,
    select([qw/a b/]),
    where { $_->{b} == 10 };

# パターン 2: where → select
my $r2 = query \@base,
    where { $_->{b} == 10 },
    select [qw/a b/];
```

**入力テーブル** — `@base`

**期待結果**

`$r1` と `$r2` が等価

| a     | b  |
|-------|----|
| alice | 10 |
| dave  | 10 |

---

### No.73 having を where より前に書いても同じ結果

```perl
# パターン 1: having → where
my $r1 = query \@base,
    having { count_by('b') > 1 },
    where  { $_->{b} <= 20 };

# パターン 2: where → having
my $r2 = query \@base,
    where  { $_->{b} <= 20 },
    having { count_by('b') > 1 };
```

**入力テーブル** — `@base`

**期待結果**

`$r1` と `$r2` が等価

---

### No.74 as を後ろに書いても動作する

```perl
our $td1;
my $r = query \@base,
    where { $td1->{b} == 10 },
    as $td1;
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |
| dave  | 10 | 150 |

---

## 15. 組み合わせ

### No.75 where + select

```perl
our $tc75;
my $r = query \@base,
    as $tc75,
    select [qw/a/],
    where  { $tc75->{b} == 10 };
```

**入力テーブル** — `@base`

**期待結果**

| a     |
|-------|
| alice |
| dave  |

キーが `[a]` のみ（2行）

---

### No.76 where + select（except）

```perl
our $tc76;
my $r = query \@base,
    as $tc76,
    select { except => ['b'] },
    where  { $tc76->{b} == 10 };
```

**入力テーブル** — `@base`

**期待結果**

| a     | c   |
|-------|-----|
| alice | 100 |
| dave  | 150 |

a・c は存在する、b は存在しない（2行）

---

### No.77 where + having + select

```perl
our $tc1;
my $r = query \@base,
    as $tc1,
    select [qw/a b/],
    where  { $tc1->{b} <= 20 },
    having { count_by('b') > 1 };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  |
|-------|----|
| alice | 10 |
| bob   | 20 |
| dave  | 10 |
| eve   | 20 |

c カラムは存在しない（4行）

---

### No.78 grep_concat + where で条件絞り込み

```perl
my $r = query \@log_tbl,
    select [qw/line msg/],
    where  { grep_concat('msg', qr/ERROR/, 0, 0) ne '' };
```

**入力テーブル** — `@log_tbl`

**期待結果**

| line | msg                     |
|------|-------------------------|
| 2    | ERROR connection failed |
| 4    | ERROR timeout           |

---

### No.79 where + having（having は where 後のテーブルを集計）

```perl
our $tc79;
my $r = query \@base,
    as $tc79,
    select '*',
    where  { $tc79->{a} ne 'carol' },
    having { count_by('b') > 1 };
```

**入力テーブル** — `@base`

where 適用後の中間テーブル（carol は除外済み）:

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |
| bob   | 20 | 200 |
| dave  | 10 | 150 |
| eve   | 20 | 250 |

**期待結果**

| a     | b  | c   |
|-------|----|-----|
| alice | 10 | 100 |
| bob   | 20 | 200 |
| dave  | 10 | 150 |
| eve   | 20 | 250 |

where で carol が除外された後、残り 4行はすべて count > 1 を満たす（b=10: 2件, b=20: 2件）

---

### No.80 スペック記載のフルサンプル

```perl
our $tf1;
my $r = query \@base,
    as $tf1,
    select { except => ['c'] },
    where {
        $tf1->{a} gt 'abc'
        and $tf1->{b} >= 10
        and $tf1->{b} <= 20
    },
    having {
        $tf1->{b} >= 10
        and count_by('b') > 1
        and max_by('c', 'b') > 100
    };
```

**入力テーブル** — `@base`

**期待結果**

| a     | b  |
|-------|----|
| alice | 10 |
| bob   | 20 |
| dave  | 10 |
| eve   | 20 |

c カラムは存在しない。a のソート済みリストが `[alice, bob, dave, eve]`

---

## 16. grep_concat — WHERE句での正規表現マッチング活用

`grep_concat` はマッチした行を起点に前後の行を連結した文字列を返す。
返却された文字列に対して `=~` または `!~` で正規表現マッチングを行うことで、
周囲の行の内容を条件としたフィルタリングが実現できる。

**コンテキスト文字列の形式**: 指定カラム（`$col`）の値のみを各行ごとに改行区切りで連結する。
例: `grep_concat('msg', qr/ERROR/, -1, 0)` の line=2 の行 → `"INFO  start\nERROR connection failed\n"`

---

### No.81 =~ で直前コンテキストにマッチするERROR行を抽出

ERROR行のうち、直前行の内容が特定パターンに一致するものだけを絞り込む例。

```perl
my $r = query \@log_tbl,
    where { grep_concat('msg', qr/ERROR/, -1, 0) =~ /start/ };
```

**入力テーブル** — `@log_tbl`

ERROR行のコンテキスト（-1行 〜 現在行）の内容:

| line | msg                     | コンテキスト文字列（msg カラムのみ）                     | =~ /start/ |
|------|-------------------------|-----------------------------------------------------------|------------|
| 2    | ERROR connection failed | `"INFO  start\nERROR connection failed\n"`                | ○          |
| 4    | ERROR timeout           | `"INFO  retrying\nERROR timeout\n"`                       | ×          |

非ERRORの行は `grep_concat` が `''` を返すため `=~ /start/` が偽となり自動的に除外される。

**期待結果**

| line | msg                     |
|------|-------------------------|
| 2    | ERROR connection failed |

---

### No.82 =~ で直後コンテキストにERRORを含むINFO行を抽出

INFO行のうち、直後行がERRORである行だけを抽出する例。

```perl
my $r = query \@log_tbl,
    where { grep_concat('msg', qr/INFO/, 0, 1) =~ /ERROR/ };
```

**入力テーブル** — `@log_tbl`

INFO行のコンテキスト（現在行 〜 +1行）の内容:

| line | msg            | コンテキスト文字列（msg カラムのみ）                      | =~ /ERROR/ |
|------|----------------|-----------------------------------------------------------|------------|
| 1    | INFO  start    | `"INFO  start\nERROR connection failed\n"`                | ○          |
| 3    | INFO  retrying | `"INFO  retrying\nERROR timeout\n"`                       | ○          |
| 5    | INFO  done     | `"INFO  done\n"`（末尾のため次行なし）                    | ×          |

非INFOの行は `grep_concat` が `''` を返すため `=~ /ERROR/` が偽となり自動的に除外される。

**期待結果**

| line | msg            |
|------|----------------|
| 1    | INFO  start    |
| 3    | INFO  retrying |

---

### No.83 !~ でリトライなしのERROR行を抽出

ERROR行のうち、直後行に "retrying" が現れないもの（リトライなし）だけを抽出する例。
`ne ''` でERROR行のみに絞り込んだ上で `!~` を適用する。

```perl
my $r = query \@log_tbl,
    where {
        my $ctx = grep_concat('msg', qr/ERROR/, 0, 1);
        $ctx ne '' && $ctx !~ /retrying/
    };
```

**入力テーブル** — `@log_tbl`

ERROR行のコンテキスト（現在行 〜 +1行）の内容:

| line | msg                     | コンテキスト文字列（msg カラムのみ）                   | ne '' かつ !~ /retrying/ |
|------|-------------------------|-------------------------------------------------------|--------------------------|
| 2    | ERROR connection failed | `"ERROR connection failed\nINFO  retrying\n"`         | × （retrying が含まれる） |
| 4    | ERROR timeout           | `"ERROR timeout\nINFO  done\n"`                       | ○                         |

**期待結果**

| line | msg           |
|------|---------------|
| 4    | ERROR timeout |

---

### No.84 !~ でコンテキストの内容でERROR行を区別する

前後のコンテキスト内に特定キーワードを含まないERROR行のみを抽出する例。
先頭行のクランプと `!~` の組み合わせも確認する。

```perl
my $r = query \@edge_log,
    where {
        my $ctx = grep_concat('msg', qr/ERROR/, -1, 1);
        $ctx ne '' && $ctx !~ /fourth/
    };
```

**入力テーブル** — `@edge_log`

ERROR行のコンテキスト（-1行 〜 +1行）の内容:

| line | msg         | コンテキスト文字列（msg カラムのみ）                      | ne '' かつ !~ /fourth/    |
|------|-------------|----------------------------------------------------------|---------------------------|
| 1    | ERROR first | `"ERROR first\nINFO  second\n"`（先頭のためクランプ）    | ○                          |
| 5    | ERROR last  | `"INFO  fourth\nERROR last\n"`                           | × （fourth が含まれる）    |

`!~` 単独では非ERRORの行（`''` を返す）も `'' !~ /fourth/` が真になるため、
`ne ''` で ERROR行のみに絞り込んでから適用する。

**期待結果**

| line | msg         |
|------|-------------|
| 1    | ERROR first |

---

## 17. 実用テスト — SQL順序（as → select → where → having）

クエリは SQL の記述順序を意識し、`as`（テーブルエイリアス）→ `select`（列指定）→ `where`（行条件）→ `having`（集計条件）の順で記述する。

---

### No.85 リードのみ絞り込んでチームと名前を取得

```perl
our $m1;
my $r = query \@members,
    as $m1,
    select [qw/team name/],
    where  { $m1->{role} eq 'lead' };
```

**入力テーブル** — `@members`

| team  | name  | role   | score |
|-------|-------|--------|-------|
| alpha | alice | lead   | 90    |
| alpha | bob   | member | 75    |
| alpha | carol | member | 82    |
| beta  | dave  | lead   | 88    |
| beta  | eve   | member | 70    |
| gamma | frank | lead   | 95    |

**期待結果**

| team  | name  |
|-------|-------|
| alpha | alice |
| beta  | dave  |
| gamma | frank |

score・role カラムは存在しない（3行）

---

### No.86 チームの最高スコアが90以上のチームのメンバーを取得

```perl
our $m2;
my $r = query \@members,
    as $m2,
    select [qw/team name score/],
    having { max_by('score', 'team') >= 90 };
```

**入力テーブル** — `@members`

グループ（team）ごとの max(score):

| team  | max(score) | >= 90 |
|-------|------------|-------|
| alpha | 90         | ○     |
| beta  | 88         | ×     |
| gamma | 95         | ○     |

**期待結果**

| team  | name  | score |
|-------|-------|-------|
| alpha | alice | 90    |
| alpha | bob   | 75    |
| alpha | carol | 82    |
| gamma | frank | 95    |

beta チームは除外（4行）

---

### No.87 スコア75以上かつチームに2人以上いるメンバーを取得

```perl
our $m3;
my $r = query \@members,
    as $m3,
    select [qw/team name score/],
    where  { $m3->{score} >= 75 },
    having { count_by('team') >= 2 };
```

**入力テーブル** — `@members`

where 適用後の中間テーブル（score >= 75）:

| team  | name  | score |
|-------|-------|-------|
| alpha | alice | 90    |
| alpha | bob   | 75    |
| alpha | carol | 82    |
| beta  | dave  | 88    |
| gamma | frank | 95    |

グループ（team）ごとの件数:

| team  | count | >= 2 |
|-------|-------|------|
| alpha | 3     | ○    |
| beta  | 1     | ×    |
| gamma | 1     | ×    |

**期待結果**

| team  | name  | score |
|-------|-------|-------|
| alpha | alice | 90    |
| alpha | bob   | 75    |
| alpha | carol | 82    |

---

### No.88 スコア75以上のメンバーからチームごとの先頭を取得

```perl
our $m4;
my $r = query \@members,
    as $m4,
    select [qw/team name score/],
    where  { $m4->{score} >= 75 },
    having { first_by('team') };
```

**入力テーブル** — `@members`

where 適用後の中間テーブル（score >= 75）とチームごとの先頭:

| team  | name  | score | 先頭 |
|-------|-------|-------|------|
| alpha | alice | 90    | ○    |
| alpha | bob   | 75    | ×    |
| alpha | carol | 82    | ×    |
| beta  | dave  | 88    | ○    |
| gamma | frank | 95    | ○    |

**期待結果**

| team  | name  | score |
|-------|-------|-------|
| alpha | alice | 90    |
| beta  | dave  | 88    |
| gamma | frank | 95    |

---

## 18. WHERE 用関数 — grep_concat

`grep_concat` は独立した WHERE 専用関数である。チェーンメソッドとしては使用できない。

### 関数シグネチャ

```perl
grep_concat($col, $pattern, $start, $end)
```

| 引数 | 型 | 省略 | 説明 |
|---|---|---|---|
| `$col` | 文字列 | 不可 | 対象カラム名 |
| `$pattern` | Regexp | 不可 | マッチングパターン |
| `$start` | 整数 | 可（デフォルト: 0） | 現在行からの開始オフセット |
| `$end` | 整数 | 可（デフォルト: `$start`） | 現在行からの終了オフセット |

### 仕様

- `$col` で指定したカラムの値が `$pattern` にマッチした場合、当該行を起点に `$start`〜`$end` の範囲の行を収集する
- 収集した各行について、**`$col` カラムの値のみ**を改行区切りで連結して返す
- **他カラムの値が結果文字列に含まれてはならない**
- `$col` カラムの値が `undef` または空文字の場合は空文字を返す
- WHERE ブロック外で呼び出した場合は `die` する

### カテゴリ分類：WHERE 専用の根拠

`grep_concat` は行の位置的関係に基づく探索・抽出処理であり、グループ集計を担う `having` 用関数（`count_by` / `max_by` 等）とは責務が異なる。`where` 内での行フィルタリングに特化した関数として独立カテゴリに分類する。

### 使用例

```perl
# msg カラムに ERROR を含む行を起点に、前後1行を含むコンテキストの msg 値を連結
where { grep_concat('msg', qr/ERROR/, -1, 1) ne '' }
```

戻り値の例（`@log_tbl` の line=2 の場合）:

```
INFO  start
ERROR connection failed
INFO  retrying
```

他カラム（`line` 等）の値は含まれない。

---

## 19. grep_concat — 指定カラムのみが返ることの検証

`grep_concat` が指定カラムの値のみを返し、他カラムの値が混入しないことを確認するテスト。

---

### No.89 指定カラムの値のみが結果に含まれる（単一行・2カラムテーブル）

```perl
my @results;
query \@log_tbl,
    where {
        my $s = grep_concat('msg', qr/ERROR/, 0, 0);
        push @results, $s if $s ne '';
        1;
    };
```

**入力テーブル** — `@log_tbl`

| line | msg                     |
|------|-------------------------|
| 1    | INFO  start             |
| 2    | ERROR connection failed |
| 3    | INFO  retrying          |
| 4    | ERROR timeout           |
| 5    | INFO  done              |

**期待結果**

- `@results` に 2件収集される
- 各結果が数値で始まらない（`line` カラムの値が混入していない）

---

### No.90 コンテキスト行でも指定カラムのみが含まれる

```perl
my @results;
query \@log_tbl,
    where {
        my $s = grep_concat('msg', qr/ERROR/, -1, 1);
        push @results, $s if $s ne '';
        1;
    };
```

**入力テーブル** — `@log_tbl`

**期待結果**

- `@results` に 2件収集される
- 各結果の全行が数値で始まらない（コンテキスト行にも `line` の値が混入していない）
- 例: `"INFO  start\nERROR connection failed\nINFO  retrying\n"`

---

### No.91 多カラムテーブルで指定カラム以外の値が混入しない

```perl
my @results;
query \@members,
    where {
        my $s = grep_concat('name', qr/alice/, 0, 0);
        push @results, $s if $s ne '';
        1;
    };
```

**入力テーブル** — `@members`（4カラム: team / name / role / score）

| team  | name  | role   | score |
|-------|-------|--------|-------|
| alpha | alice | lead   | 90    |
| alpha | bob   | member | 75    |
| ...   | ...   | ...    | ...   |

**期待結果**

- `@results` に 1件収集される
- `$results[0]` が `"alice\n"` と等しい（`name` カラムの値のみ）

---

### No.92 指定カラムの値と等値比較できること

```perl
my @results;
query \@members,
    where {
        my $s = grep_concat('name', qr/dave/, 0, 0);
        push @results, $s if $s ne '';
        1;
    };
```

**入力テーブル** — `@members`

**期待結果**

- `@results` に 1件収集される
- `$results[0]` が `"dave\n"` と等しい（`eq` による等値比較が成立する）
