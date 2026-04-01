# HashQuery delete サポート 設計書

**日付:** 2026-04-01

---

## 概要

`DELETE` を `SELECT` と同列の DSL 部品として追加する。`query` に `DELETE` を渡すと削除モードで動作し、`where` / `having` にマッチした行を削除対象として残存行を AOH で返す。`SELECT` と `DELETE` は対称的な操作であり、同じ条件をそのまま差し替えることで「確認 → 削除」のワークフローが成立する。

```perl
# SELECT で削除対象を確認
my $preview = query $table, SELECT, where { $_->{b} > 10 };

# DELETE に差し替えて実行
my $result = query $table, DELETE, where { $_->{b} > 10 };
```

---

## 1. `DELETE` DSL

**シグネチャ:**

```perl
sub DELETE ();
```

**戻り値:**

```perl
{ delete => 1 }
```

引数なし。`query` に渡すことで削除モードを宣言するフラグとして機能する。`SELECT` と同様にプロトタイプで括弧なし記述を可能にする。Perl 組み込みの `delete` との名前衝突は、`SELECT` と同様に大文字名にすることで回避する。

---

## 2. `as` 変数の変更

クエリ完了後に `as` 変数へ格納する値を**スカラーからハッシュリファレンスに変更**する。

```perl
our $tbl;
query $table, as $tbl, where { $tbl->{b} > 10 };

# クエリ完了後
# $tbl->{count}  => 結果 AOH の行数
# $tbl->{affect} => 実際に変化した行数
```

| 操作 | `count` | `affect` |
|---|---|---|
| `select`（または省略） | 結果行数 | 結果行数（count と同値） |
| `delete` | 残存行数 | 削除行数 |

`as` を指定しない場合はこれまで通り動作する。`as` 変数をクエリ間で使い回した場合も、完了後にプレーンなハッシュリファレンスが上書きされるため tie の影響が残らない。

---

## 3. 実行モデル

### SELECT モード（変更後）

1. `as` 解釈
2. `SELECT` / `except` 解釈（出力カラム確定）
3. 各行への `_row` 付加
4. `where` 評価
5. `having` 前計算 → 評価
6. `SELECT` 列射影
7. 結果 AOH を返す
8. `as` 変数に `{ count => N, affect => N }` を格納

### DELETE モード（新規）

1. `as` 解釈
2. 各行への `_row` 付加
3. `where` 評価（削除候補を特定）
4. `having` 前計算 → 評価（削除候補をさらに絞り込み）
5. 削除対象行を除いた残存行を AOH として返す
6. `as` 変数に `{ count => 残存行数, affect => 削除行数 }` を格納

`DELETE` モードでは `SELECT` / `except` の列射影は行わない（全列を返す）。

---

## 4. エラーハンドリング

| 状況 | エラーメッセージ（含む文字列） |
|---|---|
| `SELECT` と `DELETE` を同時に指定 | `"select and delete cannot be used together"` |

---

## 5. 制約・注意事項

- 元の `$table` は変更しない（非破壊的操作）
- `SELECT` と `DELETE` は排他であり、同時指定は die する
- `DELETE` モードでは `having` も使用可能（`where` 後のテーブルを集計対象とする点は SELECT モードと同じ）
- `DELETE` モードでは列射影を行わないため `SELECT` / `except` は無視される
