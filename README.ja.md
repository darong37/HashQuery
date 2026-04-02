# HashQuery

Perl の AOH（Array of Hash）を SQL に似た DSL 構文で操作するためのシンタックスシュガーです。DSL の構文は SQL をできるだけ忠実に模倣しており、SQL の知識がある開発者がそのまま直感的に読み書きできることを目指しています。

`HashQuery->new(\@table)` でインスタンスを生成し、`SELECT` / `DELETE` / `UPDATE` をメソッドとして呼び出します。`where` は行単位のフィルター、`having` はテーブル全体を見た集約フィルターであり、SQL の `WHERE` / `HAVING` の概念をそのまま Perl の構文として表現しています。

## 要件

- Perl 5.x
- [Clone](https://metacpan.org/pod/Clone)

## インストール

```bash
cpanm Clone
```

`HashQuery.pm` を `@INC` の通ったディレクトリに配置して使います。

```perl
use HashQuery;
```

## クイックスタート

```perl
use HashQuery;

my $table = [
    { name => 'alice', score => 90, grade => 'A' },
    { name => 'bob',   score => 75, grade => 'B' },
    { name => 'carol', score => 85, grade => 'A' },
];

our $row;
my $hq = HashQuery->new(\@table, as $row);

my $result = $hq->SELECT(
    [qw/name score/],
    where  { $row->{score} >= 80 },
    having { count_by('grade') > 1 },
);
```

詳細な API リファレンスは [docs/spec.md](docs/spec.md) を参照してください。

## 主な機能

**コンストラクタ:**

```perl
my $hq = HashQuery->new(\@table);
my $hq = HashQuery->new(\@table, as $tbl);
```

**インスタンスメソッド:**

| メソッド | 役割 |
|---|---|
| `SELECT('*', ...)` | 出力列を指定する。`where` / `having` にマッチした行を返す |
| `DELETE(...)` | `where` / `having` にマッチした行を削除し、残存行を返す |
| `UPDATE(\%set, ...)` | `where` / `having` にマッチした行の指定カラムを上書きし、全行を返す |

**DSL ヘルパー関数:**

| 関数 | 役割 |
|---|---|
| `as` | `where` / `having` ブロック内で使うエイリアス変数を指定する（`new` に渡す） |
| `except` | `SELECT` の第一引数として除外カラムを指定する |
| `set` | `UPDATE` の第一引数として key/value リストをハッシュリファレンスに変換する syntax sugar |
| `where` | 条件ブロックで行をフィルターする |
| `having` | `count_by` / `max_by` 等を使った集約フィルター |

**カラム値に対するメソッド（`$row->{col}`）:**

| メソッド | 役割 |
|---|---|
| `like($pattern)` | SQL LIKE パターンマッチ（`%` は任意文字列、`_` は任意1文字） |
| `not_like($pattern)` | LIKE の否定 |
| `between($min, $max)` | 範囲比較（境界値を排他にするには末尾に `!` を付ける） |
| `in(@list)` | 候補集合への一致判定 |
| `not_in(@list)` | 候補集合への一致の否定 |
| `asNull($default)` | `undef` または空文字をデフォルト値に置き換える |

**`having` 専用の集約関数:**

| 関数 | 役割 |
|---|---|
| `count_by($key, ...)` | 同じグループキーを持つ行数を返す |
| `max_by($col, $key, ...)` | グループ内の `$col` の最大値を返す |
| `min_by($col, $key, ...)` | グループ内の `$col` の最小値を返す |
| `first_by($key, ...)` | 現在行がグループの先頭行であれば真を返す |
| `last_by($key, ...)` | 現在行がグループの末尾行であれば真を返す |

**`where` 専用の独立関数:**

| 関数 | 役割 |
|---|---|
| `grep_concat($col, $pattern, $start, $end)` | マッチした行を起点に前後の行の `$col` 値を改行区切りで連結して返す。`$pattern` には `s` フラグが自動付与される |

## ドキュメント

| ファイル | 説明 |
|---|---|
| [docs/spec.md](docs/spec.md) | 機能仕様・API リファレンス |
| [docs/test-spec.md](docs/test-spec.md) | テストケース定義 |

## テスト

```bash
perl test/hashquery.t
```

出力例:

```
1..60
ok 1 - as: { as => \$var } を返す
ok 2 - except: { except => [...] } を返す
...
ok 60 - 実用: スコア75以上かつチームに2人以上いるメンバーを取得
```
