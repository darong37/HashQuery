# HashQuery UPDATE サポート 設計書

**日付:** 2026-04-01

---

## 概要

`UPDATE` を `SELECT` / `DELETE` と同列の DSL 部品として追加する。`query` に `UPDATE` を渡すと更新モードで動作し、`where` / `having` にマッチした行の指定カラムを固定値で上書きし、全行を AOH で返す。

```perl
# SELECT で更新対象を確認
my $preview = query $table, SELECT, where { $_->{score} < 60 };

# UPDATE に差し替えて実行
my $result = query $table, UPDATE { score => 60, grade => 'C' }, where { $_->{score} < 60 };
```

---

## 1. `UPDATE` DSL

**シグネチャ:**

```perl
sub UPDATE ($);
```

**戻り値:**

```perl
{ update => { col => val, ... } }
```

ハッシュリファレンスを受け取る。各キーが更新対象のカラム名、値が代入する固定値。

**コード例:**

```perl
# 単一カラム更新
query $table, UPDATE { score => 0 }, where { $_->{score} < 0 };

# 複数カラム同時更新
query $table, UPDATE { score => 100, grade => 'A' }, where { $_->{grade} eq 'S' };
```

---

## 2. `SELECT` / `DELETE` / `UPDATE` の排他ルール

`SELECT`・`DELETE`・`UPDATE` はこの3つだけが大文字の DSL であり、「操作の種類を宣言する排他的な DSL」である。2つ以上同時に指定すると die する。

| 操作 | 説明 |
|---|---|
| `SELECT` | 列射影（行数変化なし） |
| `DELETE` | 条件マッチ行を削除し残存行を返す |
| `UPDATE` | 条件マッチ行のカラムを上書きし全行を返す |

---

## 3. `as` 変数

`as` を指定した場合、クエリ完了後にハッシュリファレンスが格納される。

| 操作 | `count` | `affect` |
|---|---|---|
| `SELECT` | 結果行数 | 結果行数（count と同値） |
| `DELETE` | 残存行数 | 削除行数 |
| `UPDATE` | 全行数 | 更新行数 |

---

## 4. 実行モデル

### UPDATE モード

1. 各行への `_idx` 付加（0 始まりの行番号）
2. `where` 評価（更新候補を特定）
3. `having` 前計算 → 評価（更新候補をさらに絞り込み）
4. 更新候補の各行に対して `UPDATE` ハッシュの値を代入
5. 全行（更新済み行・未更新行を含む）を AOH として返す（`_idx` を除外）
6. `as` 変数に `{ count => 全行数, affect => 更新行数 }` を格納

`UPDATE` モードでは `SELECT` / `except` による列射影は行わない（全列を返す）。元のテーブルは変更しない（非破壊的操作）。

---

## 5. エラーハンドリング

| 状況 | エラーメッセージ（含む文字列） |
|---|---|
| `SELECT` / `DELETE` / `UPDATE` を2つ以上同時指定 | `"SELECT, DELETE, and UPDATE cannot be used together"` |
| `UPDATE` に存在しないカラム名を指定 | `"unknown column in UPDATE: <カラム名>"` |
| `UPDATE` の引数がハッシュリファレンスでない | `"UPDATE requires a hash reference"` |

---

## 6. 制約・注意事項

- 元の `$table` は変更しない（非破壊的操作）
- `SELECT`・`DELETE`・`UPDATE` は排他であり、同時指定は die する
- `UPDATE` モードでは `having` も使用可能
- `UPDATE` モードでは列射影を行わないため `SELECT` / `except` との同時指定は die する
- 動的値（現在行の値を参照した計算）はサポートしない。固定値のみ
- `UPDATE` の引数に存在しないカラムを指定した場合は die する
