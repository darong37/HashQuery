# HashQuery

Perl の AOH（Array of Hash）データを SQL に似た DSL 構文でクエリするためのシンタックスシュガーです。([English](README.md)) SQL に忠実な構文を採用しているため、SQL を知っている開発者がそのまま直感的に読み書きできます。

`HashQuery->new(\@table)` で AOH からインスタンスを生成し、`SELECT` / `DELETE` / `UPDATE` をインスタンスメソッドとして呼び出します。`where` は行を個別にフィルタし、`having` はテーブル全体を対象とした集約条件でフィルタします。これは SQL の `WHERE` / `HAVING` の区別に対応しています。

TableTools 形式のメタ情報付き配列（先頭要素に `{ '#' => { attrs, order } }` を持つ配列）も受け取れます。メタが存在する場合、`SELECT` は出力列に射影したメタを返し、`DELETE` / `UPDATE` は元のメタをそのまま返します。

## 動作環境

- Perl 5.x
- [Clone](https://metacpan.org/pod/Clone)

## 依存ライブラリ

| モジュール | 入手方法 |
|---|---|
| [TableTools](https://github.com/darong37/TableTools) | `src/TableTools.pm` を `lib/` に配置してからテストを実行 |

## インストール

```bash
cpanm Clone
```

`HashQuery.pm` を `@INC` 上のディレクトリに配置してから:

```perl
use HashQuery;
```

## クイックスタート

```perl
use HashQuery;

my @table = (
    { name => 'alice', score => 90, grade => 'A' },
    { name => 'bob',   score => 75, grade => 'B' },
    { name => 'carol', score => 85, grade => 'A' },
);

our $row;
my $hq = HashQuery->new(\@table, as $row);

my $result = $hq->SELECT(
    [qw/name score/],
    where  { $row->{score} >= 80 },
    having { count_by('grade') > 1 },
);
```

### メタ情報付き配列（TableTools 形式）

```perl
my $table = [
    { '#' => { attrs => { name => 'str', score => 'num' }, order => [qw/name score/] } },
    { name => 'alice', score => 90 },
    { name => 'bob',   score => 75 },
];

my $hq = HashQuery->new($table);

# SELECT は出力列に射影したメタを返す
my $r = $hq->SELECT([qw/name/]);
# $r->[0]{'#'} => { attrs => { name => 'str' }, order => ['name'] }
# $r->[1]      => { name => 'alice' }

# DELETE / UPDATE は元のメタをそのまま返す
my $r2 = $hq->DELETE(where { $_->{score} < 80 });
# $r2->[0]{'#'} => { attrs => { name => 'str', score => 'num' }, order => [qw/name score/] }
```

詳細な API リファレンスは [docs/spec.md](docs/spec.md) を参照してください。

## 機能一覧

**コンストラクタ:**

```perl
my $hq = HashQuery->new(\@table);
my $hq = HashQuery->new(\@table, as $tbl);
my $hq = HashQuery->new($meta_table);   # TableTools 形式も受け取れる
```

**インスタンスメソッド:**

| メソッド | 役割 |
|---|---|
| `SELECT('*', ...)` | 列射影。`where` / `having` にマッチした行を返す。メタがあれば出力列に射影して返す。 |
| `DELETE(...)` | `where` / `having` にマッチした行を削除し、残存行を返す。メタがあれば元のまま返す。 |
| `UPDATE(\%set, ...)` | `where` / `having` にマッチした行の指定列を上書きし、全行を返す。メタがあれば元のまま返す。 |

**DSL ヘルパー関数:**

| 関数 | 役割 |
|---|---|
| `as` | `where` / `having` ブロック内で使うエイリアス変数を指定する（`new` に渡す） |
| `except` | `SELECT` の第一引数として除外列を指定する |
| `set` | `UPDATE` の第一引数の syntax sugar（key/value リスト → ハッシュリファレンス） |
| `where` | 条件ブロックで行フィルタを指定する |
| `having` | `count_by` / `max_by` 等を使う集約フィルタを指定する |

**カラム値のメソッド（`$row->{col}`）:**

| メソッド | 役割 |
|---|---|
| `like($pattern)` | SQL LIKE マッチ（`%` = 任意文字列、`_` = 任意1文字） |
| `not_like($pattern)` | LIKE の否定 |
| `between($min, $max)` | 範囲チェック（境界に `!` を付けると排他） |
| `in(@list)` | 集合に含まれるか |
| `not_in(@list)` | 集合に含まれないか |
| `asNull($default)` | `undef` または空文字をデフォルト値に置き換える |

**`having` 専用集計関数:**

| 関数 | 役割 |
|---|---|
| `count_by($key, ...)` | 同じグループキーを持つ行数 |
| `max_by($col, $key, ...)` | グループ内の `$col` の最大値 |
| `min_by($col, $key, ...)` | グループ内の `$col` の最小値 |
| `first_by($key, ...)` | 現在行がグループの先頭行なら真 |
| `last_by($key, ...)` | 現在行がグループの末尾行なら真 |

**`where` 専用スタンドアロン関数:**

| 関数 | 役割 |
|---|---|
| `grep_concat($col, $pattern, $start, $end)` | マッチした行を起点に `$start`〜`$end` の範囲の `$col` 値を改行区切りで連結して返す。`$pattern` には `(?s)` が自動付与される。 |

## ドキュメント

| ファイル | 内容 |
|---|---|
| [docs/spec.md](docs/spec.md) | 機能仕様・API リファレンス |
| [docs/test-spec.md](docs/test-spec.md) | テストケース定義 |

## テスト実行

```bash
perl test/hashquery.t
```

出力例:

```
1..74
ok 1 - as: { as => \$var } を返す
ok 2 - except: { except => [...] } を返す
...
ok 74 - UPDATE: プレーン入力は従来どおりメタなしで返る
```
