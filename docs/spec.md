# HashQuery 仕様書

## 0. 設計原則

HashQuery は、Perl の AOH（Array of Hash）をテーブルとして扱い、SQL に似た構文で操作するためのシンタックスシュガーである。DSL の構文は SQL をできるだけ忠実に模倣しており、SQL の知識がある開発者がそのまま直感的に読み書きできることを目指している。

`from` を持たない理由は、JOIN を前提としない単一テーブル操作においては対象テーブルを `query` の第一引数として固定することで `from` の役割を代替できるからである。また将来 UPDATE・DELETE に対応する場合、SQL では `SELECT`・`DELETE` には `FROM` があるが `UPDATE` にはないというアンバランスな文法になる。第一引数でテーブルを統一指定する設計にすることで、操作の種類によらず文法を一貫させることができる。

`where` と `having` の役割は明確に分離している。`where` は行単位のフィルター条件であり、現在行のみを見て評価する。`having` はテーブル全体を見た集約フィルターであり、重複排除・最大値・先頭行といった「全体の中での位置づけ」を条件にできる。この2つを分離することで、SQL の `WHERE` / `HAVING` の概念をそのまま Perl の構文として表現している。

- 実行できるのは **`query` のみ**
- `SELECT` / `DELETE` / `as` / `where` / `having` は **`query` に渡す DSL ノード値**を返す関数であり、自身は何も実行しない
- DSL 部品の戻り値はすべて**深さ1のハッシュリファレンス**とする
- 各 DSL 部品は**括弧なし**で記述することを前提とする（プロトタイプで実現）
- `SELECT` の引数は配列そのものではなく**配列リファレンス**で渡す
- 入出力はすべて **AOH（Array of Hash）**
- 外部エンジン・別実行層は存在しない
- `from` / `group_by` / `distinct` は存在しない

## 1. 提供関数一覧

| 関数 | 分類 | 役割 |
|---|---|---|
| `query` | 実行関数 | 唯一の実行関数。AOH を受け取り DSL を解釈して AOH を返す |
| `as` | DSL | `where` / `having` 内で使うエイリアス変数を指定する |
| `SELECT` | DSL | 出力列を指定する（行数は変えない） |
| `DELETE` | DSL | 削除モードを宣言する（`where` / `having` と組み合わせて使う） |
| `where` | DSL | 行フィルタ条件を指定する |
| `having` | DSL | 集約フィルタ条件を指定する |

## 2. DSL 構文

**プロトタイプ定義:**

```perl
sub query ($@);
sub as (\$);
sub SELECT (;$);
sub DELETE ();
sub where (&);
sub having (&);
```

**基本構文:**

```perl
query
    $table,
    as $tbl,
    SELECT [qw/a b c/],
    where  { ... },
    having { ... };
```

- `as` は Table の直後に置く（意味的に Table に対する指定のため）
- DSL の記述順序と実行順序は独立している

## 3. 各関数リファレンス

### query

**シグネチャ:**

```perl
query $table, DSL部品...;
```

**動作説明:**

第一引数に Table（AOH）を受け取り、後続の DSL 部品を解釈して実行する。戻り値は AOH。Table の全行は同一のカラム構成を持つ必要がある（列名・列数が一致しない場合は die する）。実行時に各行へ内部カラム `_idx`（0 始まりの行番号）を自動付加する。`_idx` は `where` / `having` の評価中に `$tbl->{_idx}` として参照可能。最終出力には含まれない。

**コード例:**

```perl
my $tbl;
my $result = query $table, as $tbl, where { $tbl->{b} > 10 };
my $cnt    = scalar @$result;
```

### as

**シグネチャ:**

```perl
my $tbl;
as $tbl;
```

**戻り値:**

```perl
{ alias => \$var }
```

**動作説明:**

`where` / `having` 内で現在行を参照するためのエイリアス変数を指定する。`as $tbl` と指定した場合、`where` / `having` の中で `$tbl->{col}` によって現在行のカラム値を参照できる。`as` を指定しない場合は `$_` で参照する。`as` を指定した場合も `$_` は同じ値を持つ。引数はスカラー変数への参照（`\$var` 形式）として受け取る。クエリ完了後、指定した変数にはハッシュリファレンス `{ count => N, affect => M }` が格納される。`count` は結果 AOH の行数、`affect` は実際に変化した行数（SELECT モードでは count と同値、DELETE モードでは削除行数）。

**コード例:**

```perl
our $tbl;
my $result = query $table, as $tbl, where { $tbl->{score} >= 80 };
# クエリ完了後 $tbl->{count} には結果行数、$tbl->{affect} には変化行数が格納される
```

### SELECT

**シグネチャ:**

```perl
SELECT [qw/a b c/];          # 明示指定
SELECT { except => ['c'] };   # 除外指定
SELECT '*';                   # 全列
SELECT;                       # 全列（'*' と同義）
```

**戻り値:**

```perl
{ select => [qw/a b c/] }   # 明示指定
{ except => ['c'] }          # 除外指定
```

**動作説明:**

出力に含めるカラムを指定する。行数は変えない。引数なし・`'*'` はともに全列指定で、実際の列は `query` が Table を基準に確定する。`except` を指定した場合は全列からその列を除外した結果を出力カラムとする。内部カラム `_idx` は常に出力から除外される。

**コード例:**

```perl
query $table, SELECT [qw/a b/];
query $table, SELECT { except => ['c'] };
query $table, SELECT '*';
query $table, SELECT;
```

### DELETE

**シグネチャ:**

```perl
DELETE;
```

**戻り値:**

```perl
{ delete => 1 }
```

**動作説明:**

`query` に渡すことで削除モードを宣言する。`where` / `having` にマッチした行を削除対象とし、残存行を AOH で返す。元のテーブルは変更しない。`SELECT` / `except` と同時に指定した場合は die する。`SELECT` と対称的な操作であり、同じ条件で `SELECT` ↔ `DELETE` を差し替えることで削除対象の確認と実行を切り替えられる。

**コード例:**

```perl
# SELECT で確認
my $preview = query $table, SELECT, where { $_->{b} > 10 };

# DELETE に差し替えて実行
my $result = query $table, DELETE, where { $_->{b} > 10 };
```

### where

**シグネチャ:**

```perl
where { 条件式 };
```

**戻り値:**

```perl
{ where => CODE }
```

**動作説明:**

Table を1行ずつ評価し、条件式が真の行のみを残す。`as` が指定されている場合はそのエイリアス変数が現在行を指す。`as` なしの場合は `$_` で参照する。`$tbl->{col}` や `$_->{col}` が返す値は `HashQuery::Value` のインスタンスであり、`like` / `between` / `in` などの条件メソッドを呼び出せる。

**コード例:**

```perl
# $_ を使う場合
query $table, where { $_->{score} >= 80 };

# as でエイリアスを使う場合
our $tbl;
query $table, as $tbl, where { $tbl->{score} >= 80 };
```

### having

**シグネチャ:**

```perl
having { 条件式 };
```

**戻り値:**

```perl
{ having => CODE }
```

**動作説明:**

`where` 後の Table を対象に行単位で条件を評価し、真の行のみを残す。`as` が指定されている場合はそのエイリアス変数が現在行を指す。集約関数（`count_by` / `max_by` / `min_by` / `first_by` / `last_by`）を条件式内で使用できる。集約対象は常に `where` 後の Table であり、入力直後の Table ではない。集約関数の前計算は `having` 評価前に一度だけ行われる。

**コード例:**

```perl
our $tbl;
query $table,
    as $tbl,
    having { count_by('grade') > 1 };
```

## 4. 条件メソッド（where / having 共通）

`$tbl->{col}` や `$_->{col}` が返す `HashQuery::Value` インスタンスに対してチェーン呼び出しする。

### like

```perl
$tbl->{col}->like($pattern)
```

- `$pattern`: パターン文字列（`%` は任意文字列、`_` は任意1文字）
- 戻り値: 真偽値（一致すれば 1、しなければ 0）
- `undef` の場合は 0 を返す

```perl
where { $tbl->{name}->like('ab%') }
```

### not_like

```perl
$tbl->{col}->not_like($pattern)
```

- `like` と同じ規則で評価した結果を反転して返す
- `undef` の場合、`like` が 0 のため `not_like` は 1 を返す

```perl
where { $tbl->{name}->not_like('%error%') }
```

### between

```perl
$tbl->{col}->between($min, $max)
```

- `$min` / `$max`: 数値または文字列スカラー。末尾に `!` を付けると排他境界
- 戻り値: 真偽値（範囲内であれば 1）
- `undef` の場合は 0 を返す

```perl
where { $tbl->{score}->between(10, 20) }    # 10以上20以下
where { $tbl->{score}->between(10, '20!') } # 10以上20未満
```

### in

```perl
$tbl->{col}->in([ $v1, $v2, ... ])
$tbl->{col}->in($v1, $v2, ...)
```

- 引数: 配列リファレンス、またはフラットなリスト
- 戻り値: 真偽値（候補集合に含まれれば 1）
- `undef` の場合は 0 を返す

```perl
where { $tbl->{kind}->in([ 'x', 'y' ]) }
```

### not_in

```perl
$tbl->{col}->not_in([ $v1, $v2, ... ])
$tbl->{col}->not_in($v1, $v2, ...)
```

- `in` と同じ引数形式を受け付ける
- `in` の評価結果を反転して返す

```perl
where { $tbl->{kind}->not_in([ 'x', 'y' ]) }
```

### asNull

```perl
$tbl->{col}->asNull($default)
```

- `$default`: 置き換え後のデフォルト値（スカラー値）
- 対象値が `undef` または空文字の場合は `$default` を返す
- 対象値が存在する場合は対象値そのものを返す
- 真偽値関数ではなく変換・加工関数として扱う

```perl
where { $tbl->{name}->asNull('N/A') ne 'N/A' }
```

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

現在行の `$col` カラム値が `$pattern` に一致した場合に、`$start` 〜 `$end` の範囲の行の `$col` カラム値を改行区切りで連結した文字列を返す。一致しない場合、または `$col` の値が `undef` / 空文字の場合は空文字を返す。連結する値は `$col` カラムのみであり、他カラムの値は含まれない。`$start` 〜 `$end` の範囲はテーブルの境界でクランプする。`where` ブロック外で呼び出した場合は die する。エクスポートされた独立関数として提供し、チェーンメソッドではない。`HashQuery::WhereContext` に保持されたコンテキストを参照して動作する。

**コード例:**

```perl
# msg カラムに ERROR を含む行とその前後1行の msg 値を連結して取得
where { grep_concat('msg', qr/ERROR/, -1, 1) ne '' }
```

## 6. having 専用集計関数

`having` ブロック内でのみ使用できる。ブロック外で呼び出した場合は die する。`HashQuery::HavingContext` に保持された現在行と `where` 後の Table を参照して動作する。

### count_by

```perl
count_by($col1, $col2, ...)
```

- 入力: グループキーとなる1個以上のカラム名（文字列リスト）
- 戻り値: 現在行と同じグループキーを持つレコード数（整数）

```perl
having { count_by(qw/a b/) > 1 }
```

### max_by

```perl
max_by($target, $col1, $col2, ...)
```

- `$target`: 最大値を求める対象カラム名（第一引数）
- `$col1, ...`: グループキー（第二引数以降）
- 戻り値: グループ内の `$target` の最大値。有効値がなければ `undef`
- 比較は数値演算子（`>`）で行う。文字列型カラムには使用しないこと

```perl
having { max_by('c', qw/a b/) > 100 }
```

### min_by

```perl
min_by($target, $col1, $col2, ...)
```

- `max_by` と同様の引数形式で最小値を返す
- グループ内に有効値が存在しない場合は `undef`
- 比較は数値演算子（`<`）で行う

```perl
having { min_by('c', qw/a b/) >= 0 }
```

### first_by

```perl
first_by($col1, $col2, ...)
```

- 入力: グループキーとなるカラム名（1個以上）
- 戻り値: 現在行がグループ内の先頭行であれば 1、そうでなければ 0

```perl
having { first_by(qw/a b/) }
```

### last_by

```perl
last_by($col1, $col2, ...)
```

- 入力: グループキーとなるカラム名（1個以上）
- 戻り値: 現在行がグループ内の末尾行であれば 1、そうでなければ 0

```perl
having { last_by(qw/a b/) }
```

## 7. 実行モデル

### SELECT モード

`query` の実行は以下の順序で行われる。DSL の記述順序には依存しない。

1. `as` 解釈（エイリアス変数の確定）
2. `SELECT` / `except` 解釈（出力カラムの確定）
3. 各行への `_idx` 付加（0 始まりの行番号）
4. `where` 評価（行フィルタ）
5. `having` 前計算（集約マップのキャッシュ生成）
6. `having` 評価（集約フィルタ）
7. `SELECT` 列射影（`_idx` を除外して AOH 返却）
8. `as` 変数に `{ count => N, affect => N }` を格納

### DELETE モード

1. `as` 解釈（エイリアス変数の確定）
2. 各行への `_row` 付加（0 始まりの行番号）
3. `where` 評価（削除候補を特定）
4. `having` 前計算 → 評価（削除候補をさらに絞り込み）
5. 削除対象行を除いた残存行を AOH として返す（`_idx` を除外）
6. `as` 変数に `{ count => 残存行数, affect => 削除行数 }` を格納

### 内部パッケージ

| パッケージ | 役割 |
|---|---|
| `HashQuery` | 実行主体本体 |
| `HashQuery::RowHash` | `$tbl` / `$_` の実体。`tie` によるハッシュアクセスを提供し、カラム添字で `HashQuery::Value` を返す。内部に現在行・テーブル全体・行インデックスを保持する |
| `HashQuery::Value` | カラム値を保持する値オブジェクト。条件メソッド・変換メソッドおよび数値/文字列/真偽値オーバーロードを持つ |
| `HashQuery::WhereContext` | `where` 実行時の現在行と対象 Table を保持し、`grep_concat` に実行コンテキストを提供する |
| `HashQuery::HavingContext` | `having` 実行時の現在行と `where` 後の Table を保持し、集約関数に計算コンテキストを提供する |

## 8. 制約・注意事項

- `query` のみが実行関数。`SELECT` / `DELETE` / `as` / `where` / `having` は DSL ノード値を返すだけで何も実行しない
- 入力 Table の全行は同一のカラム構成を持つ必要がある（不一致の場合は die する）
- `count_by` / `max_by` / `min_by` / `first_by` / `last_by` は `having` ブロック外で呼ぶと die する
- `grep_concat` は `where` ブロック外で呼ぶと die する。返す値は指定カラムのみであり、他カラムは含まれない
- `as` に渡す変数は `our`（パッケージ変数）で宣言する必要がある（`my` では動作しない）
- `SELECT` の引数は配列リファレンスで渡す（配列そのものではない）
- `having` の集約対象は `where` 後の Table であり、元の入力 Table ではない
- `_idx` カラムは最終出力に含まれない
- `SELECT`（または `except`）と `DELETE` を同時に指定すると die する
- `DELETE` モードでは列射影を行わない（全列を返す）
- `DELETE` モードでも元テーブルは変更されない（非破壊的操作）
