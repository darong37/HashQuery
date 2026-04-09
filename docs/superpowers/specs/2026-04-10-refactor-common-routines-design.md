# 変更仕様書: 共通ルーチン導入リファクタリング

Date: 2026-04-10

## 変更の目的

`design-concept.md` の `To Do` セクションに定義されている3つの共通ルーチン（`_build_result` / `_set_alias` / `_filter_rows`）が現在の実装に存在しない。これらを追加し、`SELECT` / `DELETE` / `UPDATE` の各メソッドから呼ぶよう変更することで、コンセプトと実装を一致させる。内部の論理的な処理は変えない。

## 変更内容

### 1. `_build_result($rows, $meta)` の追加

返却 AoH の組み立て責務を統一し、あわせて `meta` の `count` を結果 rows 件数に合わせてセットする。

```perl
sub _build_result {
    my ($rows, $meta) = @_;

    $meta->{'#'}{count} = scalar @$rows if $meta;
    return [] unless @$rows;
    return attach($rows, $meta);
}
```

**現状:** `SELECT` / `DELETE` / `UPDATE` それぞれで `attach(...)` を直接呼んでいる。`count` のセットは行っていない。
**変更後:** 各メソッドの返却箇所を `_build_result($result, $meta)` に置き換える。`count` は `_build_result` の中で自動的に確定するため、各メソッドで意識する必要はない。

---

### 2. `_set_alias($alias, $meta, $affect)` の追加

alias 変数への格納責務を統一し、format を design-concept 準拠に変更する。

```perl
sub _set_alias {
    my ($alias, $meta, $affect) = @_;

    return unless $alias;

    $$alias = {
        '#'    => $meta->{'#'},
        affect => $affect,
    };
}
```

**現状:** 各メソッドで直接 `${ $self->{alias} } = { count => N, affect => N }` を代入している。
**変更後:** `_set_alias($self->{alias}, $out_meta, $affect)` の呼び出しに統一する。

`_set_alias` は `_build_result` の呼び出し後に行う。`_build_result` の中で `$meta->{'#'}{count}` が確定するため、その値が alias にも正しく反映される。

#### alias の format 変更

| | 変更前 | 変更後 |
|---|---|---|
| alias の内容 | `{ count => N, affect => N }` | `{ '#' => { attrs => {...}, count => N, order => [...] }, affect => N }` |

`count` はメタ情報の `'#'->{count}` として格納される。`affect` は引き続き同じ意味を持つ。

#### 0件時の alias 挙動

結果 rows が 0 件のとき、返却値は `[]` だが、alias は hashref のまま返す。`'#'->{count}` は 0 とし、`affect` は各メソッドで定義された意味に従う。`_build_result` の中で `count` が 0 にセットされた meta を `_set_alias` に渡すことで実現する。

各メソッドの `$out_meta` は `_build_result` で使う meta を共用する。`SELECT` では列射影後の meta、`DELETE` / `UPDATE` では元の meta を使う。

---

### 3. `_filter_rows($rows, $alias, @dsls)` の追加

DSL の解釈と `where` / `having` の適用責務を統一する。

```perl
sub _filter_rows {
    my ($rows, $alias, @dsls) = @_;
    my ($whr, $hvg);
    for my $dsl (@dsls) {
        if    (exists $dsl->{where})  { $whr = $dsl }
        elsif (exists $dsl->{having}) { $hvg = $dsl }
        else  { die 'invalid DSL part' }
    }
    $rows = _run_where($rows, $alias, $whr) if $whr;
    $rows = _run_having($rows, $alias, $hvg) if $hvg;
    return $rows;
}
```

**現状:** `SELECT` / `DELETE` / `UPDATE` それぞれで DSL 解釈ループと `_run_where` / `_run_having` の呼び出しを個別に持っている。
**変更後:** `_filter_rows($tbl, $self->{alias}, @dsls)` の呼び出しに統一する。既存の `_run_where` / `_run_having` は変更しない。

---

## 各メソッドの処理順序（変更後）

### SELECT

1. 出力列リストを確定する
2. rows を clone して `_idx` を付加する
3. `_filter_rows` で where / having を適用する
4. `_run_select` で列射影する
5. 射影後の列に合わせて `$out_meta` を確定する
6. `_build_result($result, $out_meta)` で返却値を組み立てる（`count` もここで確定）
7. `_set_alias($self->{alias}, $out_meta, $affect)` で alias をセットする

### DELETE

1. rows を clone して `_idx` を付加する
2. `_filter_rows` で削除対象行を特定する
3. `_run_delete` で残存行を組み立てる
4. `$out_meta` は元の meta をそのまま使う
5. `_build_result($result, $out_meta)` で返却値を組み立てる（`count` もここで確定）
6. `_set_alias($self->{alias}, $out_meta, $affect)` で alias をセットする

### UPDATE

1. 更新カラムの検証を行う
2. rows を clone して `_idx` を付加する
3. `_filter_rows` で更新対象行を特定する
4. `_run_update` で更新済み全行を組み立てる
5. `$out_meta` は元の meta をそのまま使う
6. `_build_result($result, $out_meta)` で返却値を組み立てる（`count` もここで確定）
7. `_set_alias($self->{alias}, $out_meta, $affect)` で alias をセットする

---

## 変更しないもの

- `_run_where` / `_run_having` の実装
- `_check_cols` / `_run_select` / `_run_delete` / `_run_update` の実装
- `HashQuery::RowHash` / `HashQuery::Value` / `HashQuery::WhereContext` / `HashQuery::HavingContext` の実装

## テストへの影響

- alias の format が変わるため、alias の内容を検証しているテストケースは修正が必要
  - `count` の参照先: `$alias->{count}` → `$alias->{'#'}{count}`
  - `affect` の参照先: 変更なし（`$alias->{affect}` のまま）
- 0件時に alias が設定されることを検証するテストケースは新たに追加が必要
- 論理的な動作は変わらないため、alias 以外のテストはそのまま通る想定
