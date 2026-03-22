# HashQuery Spec

## 0. 最重要前提（絶対条件）

- 実行可能なのは **`query` のみ**
- `select` / `as` / `where` / `having` は実行関数ではない
- これらは **`query` に渡すための DSLノード値** を表す
- `select ...` / `as ...` / `where { ... }` / `having { ... }` のような
  **DSLノード生成関数とその引数を合わせたもの** を **DSL部品** と呼ぶ
- DSL部品の戻り値は、すべて **深さ1のハッシュリファレンス** で統一する
- DSL部品の戻り値は、必ず自分自身のキーで構成する
- 各DSL部品は、**括弧なし** で記述することを最重要前提とする
- `select(...)` のような括弧付き記法を前提に設計しない
- `select` / `as` / `where` / `having` は、
  プロトタイプにより括弧なしで表現できることを前提にする
- `select` の引数は、配列そのものではなく **配列リファレンス** で渡す
- 実行は必ずこの形のみ

```perl
query $table, DSL部品...
```

- 外部エンジン・別実行層は一切存在しない

## 1. 提供関数

- `query`   `# 唯一の実行関数`
- `as`
- `select`
- `where`
- `having`

## 2. 基本原則

- 入出力はすべて **AOH（Array of Hash）**
- `query` の第一引数には、必ず **Table** を指定する
- ここでいう **Table** とは、AOH をデータテーブルとして扱うときの呼称である
- 第一引数の後には、各DSL部品を並べて指定する
- 行数制御は `where` / `having` のみ
- `select` は列制御のみ（行数は変えない）
- `from` は廃止する

```perl
my $table  = ...;
my $tbl;
my $result = query $table, DSL部品...;
my $cnt    = scalar @$result;
```

## 3. DSL構文ルール

- Perlプロトタイプで成立させる
- 各DSL部品は括弧なしで書けることを前提とする

```perl
sub query ($@);
sub as (\$);
sub select ($);
sub where (&);
sub having (&);
```

- DSL部品は即時評価しない
- 実行は `query` のみが行う

## 4. 基本構文

```perl
query
    $table,
    as $tbl,
    select [qw/a b c/],
    where  { ... },
    having { ... };
```

- `as` は Table に対する指定なので、Table の直後に置く
- 実行順序は表示順とは別である

## 5. 実行順序

1. `as`
2. `select` / `except` の解釈と出力カラム確定
3. `where`
4. `having`（前計算 → 評価）
5. `select`（列射影）

- DSL記述順には依存しない

## 6. query

```perl
query $table,
    DSL部品...;
```

- 第一引数
  - Table

- 第二引数以降
  - 各種DSL部品

- 戻り値
  - AOH

- 役割
  - 第一引数の Table を対象に、後続の各種DSL部品を解釈して実行する

## 7. as

```perl
my $tbl;
as $tbl;
```

- 戻り値

```perl
{
  alias => REF
}
```

- 役割
  - `where` / `having` 内で利用する Table のエイリアス変数を指定する

- 仕様
  - `as` は単なるノード値であり、実行しない
  - エイリアスという考え方は従来のものを踏襲する
  - `as` は、文字列ではなく変数参照として受け取る
  - `as $tbl` と指定した場合、`where` / `having` の中では `$tbl` によって現在行を参照できる
  - `where` / `having` において主役になるのは、`as` で指定したエイリアス変数である
  - `as` に渡した変数には、現在行の hash リファレンスが入るものとして扱う
  - `as` による alias 変数は、`where` と `having` の両方で同じ考え方で使えるようにする

## 8. select

```perl
select [qw/a b c/];
```

- 戻り値

```perl
{
  select => [qw/a b c/]
}
```

- 役割
  - 出力に含めるカラムを指定する

- 仕様
  - `select` は単なるノード値であり、実行しない
  - 行数は変えない
  - `select` の受け方は次の3種類とする
    - 配列リファレンス
    - `except` を持つハッシュリファレンス
    - スカラー `'*'`
  - スカラーで受ける場合は `'*'` のみ許可する
  - `query` は初期段階で、第一引数の Table を見て出力カラムを確定する
  - `select` / `except` のどちらで指定された場合も、出力カラムの最終確定は `query` が行う

- 明示指定

```perl
select [qw/a b c/];
```

- 戻り値

```perl
{
  select => [qw/a b c/]
}
```

- `except` 指定

```perl
select {
    except => [ 'c' ]
};
```

- 戻り値

```perl
{
  except => [ 'c' ]
}
```

- 仕様
  - `except` は `select` の中でのみ使う
  - `except` が指定された場合は、`query` 実行時に Table の全列からその列を除外した結果を出力カラムとして確定する
  - 明示カラム指定は、配列リファレンスで渡す
  - `select` / `except` は、`query` から Table を見える前提で実装する
  - `select` のために mode や node 単位の追跡情報を別途持つことを前提にしない
  - `query` は `select` または `except` を受け取った時点で出力カラムを確定し、その確定結果を後続処理でも利用できるようにする

- 全列

```perl
select;
select '*';
```

- 仕様
  - `select` または `select '*'` は全列指定を表す
  - `select` に何も指定しない場合と `select '*'` は同義とする
  - 実際の全列の確定は query の初期段階で Table を基準に行う

## 9. where

```perl
where {
    $tbl->{a} > 10
};
```

- 戻り値

```perl
{
  where => CODE
}
```

- 仕様
  - Table を1行ずつ評価する
  - trueのみ残す
  - `as` が指定されている場合は、その alias に対応する変数が主役になる
  - `as` がある場合は alias を優先し、`$_` は主役にしない
  - 例: `as $tbl` が指定されている場合、`where` の中で `$tbl->{a}` と書ける
  - `as` を指定しなかった場合に限り、`$_` によって現在行を参照する
  - `$tbl` や `$_` は、plain な hash リファレンスではなく `HashQuery::WhereContext` に接続された view として扱う
  - `$tbl->{a}` や `$_->{a}` が返す値は、`like` / `between` / `in` などを呼べる値オブジェクトでなければならない
  - `where` 実行時の現在行は `HashQuery::WhereContext` に保持させる
  - `where` の実装では、`as` で受けた変数参照に対して現在行の hash リファレンスを割り当てる形を前提とする
  - `where` 実行時には、`HashQuery::WhereContext` に保持された現在行と同じ行を、`as` で受けた変数参照にも割り当てる
  - `as` を指定しない場合でも、`$_` には `HashQuery::WhereContext` に接続された同等の view を割り当てる
  - `where` の拡張関数は `HashQuery::WhereContext` に保持された現在行を基準に評価する
  - `where` のために caller package や node package のような追跡機構を前提にしない

- whereで使用できる関数

```perl
$tbl->{name}->like('ab%')
$tbl->{score}->between(10, 20)
$tbl->{kind}->in([ 'x', 'y' ])
$tbl->{kind}->not_in([ 'x', 'y' ])
```

- 仕様
  - `where` では、tie された値に対して関数的な条件指定を使える
  - 現時点で使用可能な関数は次のとおり
    - `like`
    - `between`
    - `in`
    - `not_in`
    - `not_like`
    - `asNull`
  - 拡張予定の関数として、少なくとも次を想定する
    - `is_empty`
    - `is_blank`
  - `is_` が付く関数は、真偽値を返す関数として扱う
  - `asNull` は真偽値関数ではなく、対象が Null だった場合の出力を扱う別種の関数として区別する
  - `between` には拡張案がある
    - `A, B` は通常の範囲指定
    - `A!, B!` のように値の後ろへ `!` を付けることで、その境界値を含むか含まないかを指定できる形を検討する
    - この `!` は演算子ではなく、文字列指定として扱う
  - これらは SQL の演算子に対応する条件指定として扱う

## 10. having

```perl
having {
    count_by(qw/a b/) > 1
};
```

- 戻り値

```perl
{
  having => CODE
}
```

- 仕様
  - `having` が返すのは、`having` というキーを持つ深さ1のハッシュリファレンスである
  - `where` 後の Table を対象に評価する
  - 行単位で評価する
  - 条件成立行のみ残す
  - `having` 内で使う集約関数は、条件式で評価可能なスカラー値を返す
  - `as` が指定されている場合は、`having` の中でも `$tbl->{a}` のように現在行を参照できる
  - `having` の実装でも、`as` で受けた変数参照に対して現在行の hash リファレンスを割り当てる形を前提とする
  - `having` における `$tbl` や `$_` も、plain な hash リファレンスではなく context に接続された view として扱う
  - `having` でも `$tbl->{a}` や `$_->{a}` が返す値は、`like` / `between` / `in` などを呼べる値オブジェクトでなければならない
  - `having` 実行時の現在行、および集約関数が参照する Table は `HashQuery::HavingContext` に保持させる
  - `having` 実行時には、`HashQuery::HavingContext` に保持された現在行と同じ行を、`as` で受けた変数参照にも割り当てる
  - `as` を指定しない場合でも、`$_` には current row に対応した同等の view を割り当てる
  - `having` の実装は、集約関数と alias 変数で完結させる
  - `having` のために caller package や node package のような追跡機構を前提にしない

- 使用可
  - 集約関数
  - `count_by`, `max_by`, `min_by`, `first_by`, `last_by` は明示的に export して利用可能にする
  - `as` が指定されている場合の alias 変数

## 11. 集約仕様

```perl
count_by(qw/a b/)
```

- 現在行のa,b値をキーとして
- `where` 後の Table 全体から一致件数を取得する
- 集約関数は、現在行に対応する集約値をスカラーとして返す

## 12. 集約対象

- 必ず `where` 後の Table
- `query` の入力直後を直接集約対象にはしない

## 13. 集約最適化

- `having` 前に一度だけ前計算
- 例：
  - a,bごとの件数mapを生成しキャッシュ

## 14. 集約関数

```perl
count_by(qw/a b/)
max_by('c', qw/a b/)
min_by('c', qw/a b/)
first_by(qw/a b/)
last_by(qw/a b/)
```

- **having内のみ使用可**
- 返り値の考え方
  - `count_by` は件数を返す
  - `max_by` は最大値を返す
  - `min_by` は最小値を返す
  - `first_by` は現在行に対応する先頭側の値を返すための評価値として使う
  - `last_by` は現在行に対応する末尾側の値を返すための評価値として使う

## 15. フィルタ整理

- `where`  : 行フィルタ
- `having` : 集約フィルタ
- `select` : 列制御のみ

## 16. 設計制約

- `from`        : なし
- `group_by`    : なし
- `distinct`    : なし
- 集約          : `having`のみ
- 実行主体      : `query`のみ
- 外部実行層    : なし

## 17. ネームスペース

- 基本パッケージ名は `HashQuery` とする
- `where` で使う tie 変数や拡張関数は、`HashQuery` の内部パッケージとして定義してよい
- `having` の集約関数も、`HashQuery` の内部パッケージとして定義してよい
- `HashQuery::WhereContext` は、`where` 実行時の現在行を保持する役割を持つ
- `where` で使う alias 変数は、`HashQuery::WhereContext` が保持している現在行と同じ行を参照するように割り当てる
- `having` の集約関数は export で提供し、`where` / `having` の alias 変数は `as` で受けた変数参照に対して割り当てる
- `HashQuery::HavingContext` は、`having` 実行時の現在行と `where` 後の Table を保持する役割を持つ
- `having` で使う alias 変数は、`HashQuery::HavingContext` が保持している現在行と同じ行を参照するように割り当てる
- caller package や node package のような追跡機構を実装前提にしない
- パッケージ名の提案は次のとおり
  - `HashQuery`
    - 実行主体本体
  - `HashQuery::WhereContext`
    - `where` 用の tie 変数、拡張値、条件関数を扱う
  - `HashQuery::HavingContext`
    - `having` 用の集約関数を扱う

## 18. query責務

- 第一引数の Table 受け取り
- 第二引数のノード解釈
- `as`解釈
- `select` / `except` 解釈
- 出力カラム確定
- `where`実行
- `having`前計算
- `having`実行
- `select`列射影
- AOH返却

## 19. フル例

```perl
my $tbl;
my $result = query
    $table,
    as $tbl,
    select {
        except => [ 'c' ]
    },
    where {
        $tbl->{a} gt 'abc'
        and $tbl->{b} >= 10
        and $tbl->{b} <= 20
    },
    having {
        $tbl->{c} > 100
        and
        count_by(qw/a b/) > 1
        and max_by('c', qw/a b/) > 100
    };

my $cnt = scalar @$result;
```
