# HashQuery OOP 再設計 設計書

**日付:** 2026-04-02

---

## 概要

HashQuery を関数ベースの DSL からオブジェクト指向 API に再設計する。`HashQuery->new(\@table)` でインスタンスを生成し、`SELECT` / `DELETE` / `UPDATE` をメソッドとして呼び出す形に変更する。後方互換性は持たない（現行の `query` 関数ベース API は完全廃止）。

---

## 1. コンストラクタ

```perl
my $hq = HashQuery->new(\@table);
my $hq = HashQuery->new(\@table, as $tbl);
my $hq = HashQuery->new(\@table, { as => \$tbl });
```

- 第一引数: AOH（必須）
- 第二引数: オプションのハッシュリファレンス（現時点では `as` のみ）
- `as $tbl` は `{ as => \$tbl }` を返す syntax sugar（プロトタイプ `\$` で実現）
- コンストラクタ内で `_check_cols` を実行し、全カラムリスト `@all` をインスタンスに保持する
- 元の AOH は `clone` してインスタンス内部に保持する（非破壊）

---

## 2. メソッド

### SELECT

```perl
$hq->SELECT('*', where { ... }, having { ... })
$hq->SELECT([qw/a b/], where { ... })
$hq->SELECT(except('c', 'd'), where { ... })
```

- 第一引数（必須）: `'*'`・配列リファレンス・`except(...)` の戻り値のいずれか。`undef` は die する
- 第二引数以降（省略可）: `where { }` / `having { }` DSL ノード（順不同）
- 戻り値: AOH（条件にマッチした行を指定列で射影したもの）
- `as` を指定した場合、完了後に `$tbl->{count}` = 結果行数、`$tbl->{affect}` = 結果行数（SELECT では同値）

### DELETE

```perl
$hq->DELETE(where { ... })
$hq->DELETE(having { ... })
$hq->DELETE(where { ... }, having { ... })
```

- 引数（省略可）: `where { }` / `having { }` DSL ノード（順不同）。省略時は何も削除されず全行を返す
- 戻り値: AOH（マッチ行を除いた残存行）
- `as` を指定した場合、完了後に `$tbl->{count}` = 残存行数、`$tbl->{affect}` = 削除行数

### UPDATE

```perl
$hq->UPDATE({ score => 60, grade => 'C' }, where { ... })   # ハッシュリファレンス形式
$hq->UPDATE(set(score => 60, grade => 'C'), where { ... })  # set 関数形式
$hq->UPDATE({ col => val, ... })                             # 全行更新
```

- 第一引数（必須）: 更新内容のハッシュリファレンス、または `set(...)` の戻り値（存在しないカラムを指定すると die）
- 第二引数以降（省略可）: `where { }` / `having { }` DSL ノード（順不同）
- 戻り値: AOH（全行。マッチ行は更新済み）
- `as` を指定した場合、完了後に `$tbl->{count}` = 全行数、`$tbl->{affect}` = 更新行数

---

## 3. エクスポート関数の変更

| 関数 | 変更 |
|---|---|
| `query` | **廃止** |
| `SELECT` | **廃止**（メソッドに移行） |
| `DELETE` | **廃止**（メソッドに移行） |
| `UPDATE` | **廃止**（メソッドに移行） |
| `except` | **新規追加** |
| `set` | **新規追加** |
| `as` | 継続（戻り値を `{ as => \$var }` に変更） |
| `where` | 継続 |
| `having` | 継続 |
| `count_by` | 継続 |
| `max_by` | 継続 |
| `min_by` | 継続 |
| `first_by` | 継続 |
| `last_by` | 継続 |
| `grep_concat` | 継続 |

---

## 4. `as` 関数の仕様変更

**現行:** `as(\$)` → `{ alias => \$var }`

**新仕様:** `as(\$)` → `{ as => \$var }`

プロトタイプは変わらず `\$`。`new` の第二引数として渡すためにキー名を `alias` から `as` に変更する。

`where` / `having` ブロック実行中にエイリアス変数が現在行（`HashQuery::RowHash`）を指す動作は従来通り。

---

## 5. `except` 関数

```perl
sub except (@) {
    return { except => [@_] };
}
```

- 引数: 除外するカラム名（1個以上）
- 戻り値: `{ except => [...] }`
- `SELECT` メソッドの第一引数として渡すと、インスタンスが保持する `@all` から指定列を除外した列リストで射影する

---

## 6. `set` 関数

```perl
sub set (@) {
    my %h = @_;
    return \%h;
}
```

- 引数: `col => val` のペアリスト
- 戻り値: ハッシュリファレンス（`UPDATE` の第一引数として渡す）
- `{ col => val }` と完全に同義。波括弧なしで UPDATE の更新内容を記述するための syntax sugar

---

## 7. 複数回呼び出し

同一インスタンスに対して `SELECT` / `DELETE` / `UPDATE` を複数回呼び出すことができる。インスタンスは内部に `clone` した AOH を保持しており、各メソッド呼び出しはその clone に対して独立して実行される（互いに影響しない）。

```perl
our $tbl;
my $hq = HashQuery->new(\@table, as $tbl);

my $preview = $hq->SELECT('*', where { $tbl->{score} < 60 });
# $tbl->{count} == 2

my $updated = $hq->UPDATE({ score => 60 }, where { $tbl->{score} < 60 });
# $tbl->{affect} == 2

my $deleted = $hq->DELETE(where { $tbl->{score} < 60 });
# $tbl->{affect} == 2
```

---

## 8. 内部設計

- `HashQuery` オブジェクトは以下を保持する:
  - `table`: clone した AOH（各メソッドの実行元）
  - `all`: 全カラムリスト（`_check_cols` の結果）
  - `alias`: alias 変数への参照（`as` 指定時のみ）
- `HashQuery::RowHash`、`HashQuery::Value`、`HashQuery::WhereContext`、`HashQuery::HavingContext` は内部パッケージとして継続使用
- `_run_where`、`_run_having`、`_run_select`、`_run_delete`、`_run_update` の内部関数は継続使用（シグネチャは適宜調整）
- ファイル構成: `src/HashQuery.pm` の1ファイルに全パッケージを収める

---

## 9. エラーハンドリング

| 状況 | エラーメッセージ |
|---|---|
| `new` の第一引数が AOH でない | `"HashQuery->new requires an Array of Hash"` |
| テーブルのカラム構成が不一致 | `"table columns are not consistent"` |
| `SELECT` の第一引数が不正 | `"SELECT requires '*', arrayref, or except(...)"` |
| `UPDATE` の第一引数がハッシュリファレンスでない | `"UPDATE requires a hash reference"` |
| `UPDATE` に存在しないカラム名を指定 | `"unknown column in UPDATE: <カラム名>"` |
| `except` に0個の引数 | `"except requires at least one column name"` |
