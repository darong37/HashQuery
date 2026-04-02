# 変更履歴

## [未リリース]

### 新機能
- `DELETE` DSL を追加。`where` / `having` にマッチした行を削除し、残存行を AOH で返す
- `SELECT` と `DELETE` は対称的な操作であり、同じ条件で差し替えることで「確認 → 削除」のワークフローが成立する
- `UPDATE` DSL を追加。`where` / `having` にマッチした行の指定カラムを固定値で上書きし、全行を AOH で返す

### 変更
- `SELECT` / `DELETE` / `UPDATE` の DSL 関数名を大文字に統一（Perl 組み込みの `select` / `delete` との衝突を回避するため）
- `as` 変数の戻り値をスカラー（行数）から `{ count => N, affect => M }` ハッシュリファレンスに変更
  - `count`：結果 AOH の行数
  - `affect`：実際に変化した行数（`SELECT` では `count` と同値、`DELETE` では削除行数、`UPDATE` では更新行数）
- 競合エラーの対象を `DELETE + UPDATE` のみに変更（`SELECT` は省略可能な内部仕様に変更）

### ドキュメント
- `docs/spec.md` に設計思想（`FROM` 不要の理由、`where` / `having` の概念的区別）を追記
- `docs/notes.md` 新規作成（技術的背景メモ：`as` と tie の関係、`_idx` 内部カラム、`SELECT`/`DELETE` 大文字化の理由）
- `README.ja.md` 新規作成（日本語版 README）
- テスト数：93 → 104

---

## [初期実装]

### 新機能
- `query`、`as`、`SELECT`、`where`、`having` による AOH クエリ DSL
- カラム値メソッド：`like`、`not_like`、`between`、`in`、`not_in`、`asNull`
- `having` 専用集約関数：`count_by`、`max_by`、`min_by`、`first_by`、`last_by`
- `where` 専用関数：`grep_concat`（前後行の値を連結して返す）
