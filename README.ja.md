# HashQuery

Perl の AOH（Array of Hash）を SQL に似た DSL 構文で操作するためのシンタックスシュガーです。DSL の構文は SQL をできるだけ忠実に模倣しており、SQL の知識がある開発者がそのまま直感的に読み書きできることを目指しています。

`query` の第一引数が対象テーブルを指定します。これは SQL の `FROM` 句の役割を果たすと同時に、将来の UPDATE・DELETE 操作においても対象テーブルの指定方法を統一するための設計です。`where` は行単位のフィルター、`having` はテーブル全体を見た集約フィルターであり、SQL の `WHERE` / `HAVING` の概念をそのまま Perl の構文として表現しています。

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
my $result = query $table,
    as   $row,
    select [qw/name score/],
    where  { $row->{score} >= 80 },
    having { count_by('grade') > 1 };
```

詳細な API リファレンスは [docs/spec.md](docs/spec.md) を参照してください。

## 主な機能

**コア関数:**

| 関数 | 役割 |
|---|---|
| `query` | 唯一の実行関数。AOH テーブルと DSL 部品を受け取り AOH を返す |
| `as` | `where` / `having` ブロック内で使うエイリアス変数を指定する |
| `select` | 出力列を指定する（行数は変わらない） |
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
| [docs/CodingRule.md](docs/CodingRule.md) | コーディング規約 |

## テスト

```bash
perl test/hashquery.t
```

出力例:

```
1..93
ok 1 - query: DSLなしで全行全列を返す
ok 2 - query: 空テーブルを渡すと空配列を返す
...
ok 93 - as: クエリ完了後にレコード数が格納される
```
