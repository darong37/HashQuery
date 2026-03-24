# HashQuery

Perl の AOH（Array of Hash）をインメモリで DSL 的に操作するモジュール。

---

## 概要

`HashQuery` は、AOH をテーブルとして扱い、`where` / `having` / `select` を Perl の構文として自然に書けるようにしたモジュールです。外部エンジンや実行レイヤーは存在せず、`query` だけが実行関数です。

```perl
use HashQuery;

my $tbl;
my $result = query
    $table,
    as   $tbl,
    select [qw/name score/],
    where  { $tbl->{score} >= 80 },
    having { count_by('grade') > 1 };
```

---

## 主な機能

| 関数 | 役割 |
|---|---|
| `query` | 唯一の実行関数。AOH を受け取り、DSL を解釈して AOH を返す |
| `as` | `where` / `having` 内で使う行エイリアス変数を指定する |
| `select` | 出力列を絞る（行数は変わらない） |
| `where` | 行フィルタ。条件が真の行だけを残す |
| `having` | 集計フィルタ。`count_by` 等の集計関数と組み合わせる |

### having 専用の集計関数

`having` ブロック内でのみ使用できます。ブロック外で呼ぶと `die` します。

| 関数 | 役割 |
|---|---|
| `count_by($key, ...)` | グループ内の件数を返す |
| `max_by($col, $key, ...)` | グループ内の指定列の最大値を返す |
| `min_by($col, $key, ...)` | グループ内の指定列の最小値を返す |
| `first_by($key, ...)` | 現在行がグループ先頭なら真を返す |
| `last_by($key, ...)` | 現在行がグループ末尾なら真を返す |

### where / having で使用できるメソッド

行の値（`$_->{col}` または `$alias->{col}`）に対してチェーン呼び出しできます。

| メソッド | 役割 |
|---|---|
| `like($pattern)` | SQL LIKE パターンマッチング（`%` は任意文字列、`_` は任意1文字） |
| `not_like($pattern)` | `like` の否定 |
| `between($min, $max)` | 範囲比較（値の後ろに `!` を付けると境界を排他にできる） |
| `in(@list)` | リスト内一致（配列リファレンスでも可） |
| `not_in(@list)` | `in` の否定 |
| `asNull($default)` | `undef` または空文字のときデフォルト値を返す |

### where 専用の独立関数

`where` ブロック内でのみ使用できます。ブロック外で呼ぶと `die` します。

| 関数 | 役割 |
|---|---|
| `grep_concat($col, $pattern, $start, $end)` | `$col` の値が `$pattern` にマッチした行を起点に、前後の行の `$col` 値を改行区切りで連結した文字列を返す。`$pattern` には内部で `s` フラグが自動付与される |

---

## インストール

依存モジュールをインストール後、`HashQuery.pm` を `@INC` の通ったパスに配置して使います。

```bash
cpanm Clone
```

```perl
use HashQuery;
```

---

## 使用方法

### 基本

```perl
use HashQuery;

my $table = [
    { name => 'alice', score => 90, grade => 'A' },
    { name => 'bob',   score => 75, grade => 'B' },
    { name => 'carol', score => 85, grade => 'A' },
];

# where で行フィルタ
my $result = query $table, where { $_->{score} >= 80 };
# => alice, carol

# select で列を絞る
my $result = query $table, select [qw/name score/];

# select '*' または select で全列
my $result = query $table, select '*';

# select except で指定列だけ除外
my $result = query $table, select { except => ['grade'] };
```

### as でエイリアス変数を使う

```perl
our $row;
my $result = query $table, as $row, where { $row->{score} >= 80 };
```

`as` を使った場合、`where` / `having` 内では `$row` が現在行を指します。`as` を省略した場合は `$_` を使います。

### where の条件メソッド

```perl
# like（% は任意文字列、_ は任意1文字）
where { $_->{name}->like('al%') }

# not_like
where { $_->{name}->not_like('%ob') }

# between（境界含む）
where { $_->{score}->between(80, 90) }

# between（排他境界、値の後ろに ! を付ける）
where { $_->{score}->between('80!', '90!') }  # 80 < score < 90

# in
where { $_->{grade}->in(['A', 'B']) }

# not_in
where { $_->{grade}->not_in(['C']) }

# asNull（undef または空文字のときデフォルト値を返す）
where { $_->{score}->asNull(0) >= 80 }
```

### where の独立関数

```perl
# grep_concat（パターンにマッチした行の前後コンテキストを指定列のみ連結）
# 第1引数: 対象列名、第2引数: 正規表現（s フラグ自動付与）、第3引数: 開始オフセット（省略時0）、第4引数: 終了オフセット（省略時=$start）
where { grep_concat('msg', qr/error/, 0, 1) }
# msg 列が /error/ にマッチした行とその次の行の msg 値を改行区切りで返す
# マッチしない行は '' を返す（空文字は偽なので自動的に除外される）
# パターン中の . は改行にもマッチする（s フラグ自動付与のため）
```

`grep_concat` は `where` ブロック外で呼ぶと `die` します。

### having で集計フィルタ

```perl
our $row;
my $result = query
    $table,
    as $row,
    having { count_by('grade') > 1 };
# grade ごとの件数が 1 より多いグループに属する行を残す

# max_by / min_by
having { max_by('score', 'grade') >= 85 }
having { min_by('score', 'grade') >= 75 }

# first_by / last_by（グループの先頭・末尾行だけを残す）
having { first_by('grade') }
having { last_by('grade') }
```

集計関数のグループキーは `count_by(qw/a b/)` のように複数列指定も可能です。

### where + having + select の組み合わせ

```perl
our $row;
my $result = query
    $table,
    as   $row,
    select { except => ['grade'] },
    where  { $row->{score} >= 75 },
    having { count_by('grade') > 1 };
```

記述順序と実行順序は独立しています。実行は常に `as → select解析 → where → having集計 → having評価 → select射影` の順です。

---

## テスト

```bash
perl test/hashquery.t
```

`Test::More` を使っています。

```
1..30
ok 1 - query: DSLなしで全行全列を返す
ok 2 - query: 空テーブルを渡すと空配列を返す
...
ok 30 - 組み合わせ: スペック記載のフルサンプル
```

### テストの構成

| 対象 | 内容 |
|---|---|
| `query` 基本 | DSLなし・空テーブル・不正入力 die・列不一致 die |
| `select` | 明示列・except・`'*'`・引数なし |
| `where` | `$_` フィルタ・`as` + alias・like / not_like・between（境界含む/排他）・in / not_in・asNull |
| `having` | count_by・max_by・min_by・first_by・last_by・having 外呼び出し die |
| 組み合わせ | where + having + select・except との組み合わせ・フルサンプル |

---

## プロジェクト構成

```
.
├── src/
│   └── HashQuery.pm       # モジュール本体
├── test/
│   └── hashquery.t        # テストコード
├── examples/
│   └── sample_usage.pl    # 使用例
├── docs/
│   ├── HashQuery_Spec.md  # 仕様書
│   └── CodingRule.md      # コーディングルール
└── README.md
```

---

## 設計方針

[docs/HashQuery_Spec.md](docs/HashQuery_Spec.md) に基づきます。主な方針は以下のとおりです。

- **実行できるのは `query` だけ。** `select` / `as` / `where` / `having` は DSL キー・値を返す関数であり、自身は何も実行しない。
- **入出力はすべて AOH。** `query` の第一引数も戻り値も AOH。
- **括弧なしで書けること。** 各 DSL 部分はプロトタイプにより括弧なしで記述できる。
- **外部実行レイヤーなし。** `from` / `group_by` / `distinct` は存在しない。
- **集計は `having` 内のみ。** `count_by` 等は `having` ブロックの外では使えない。
- **集計対象は `where` 後のテーブル。** 入力直後のテーブルを直接集計対象にはしない。

---

## コーディングルール

[docs/CodingRule.md](docs/CodingRule.md) に基づきます。要点は以下のとおりです。

- 変数名は小文字基本、役割を直接表す名前を使う（`ref` ではなく `alias`、`part` ではなく `dsl`）
- 複数要素は複数形（`@dsls`、`@rows`、`@cols`）
- 仕様上の用語をそのまま使う（`dsl`、`alias`、`select`、`where`、`having`）
- 短くても文脈と一致することを優先する

---

## 制約・注意点

- 入力テーブルの全行は同じキーセットを持つ必要がある。異なる場合は `die` する。
- `count_by` / `max_by` / `min_by` / `first_by` / `last_by` は `having` ブロック外で呼ぶと `die` する。
- `grep_concat` は `where` ブロック外で呼ぶと `die` する。返す値は指定列のみであり、他の列は含まれない。
- `as` に渡す変数は `our`（パッケージ変数）で宣言する必要がある。`my` では動作しない。
- `select` の引数は配列リファレンスで渡す（配列そのものではない）。
- `having` の集計対象は `where` 後のテーブルであり、元の入力テーブルではない。
