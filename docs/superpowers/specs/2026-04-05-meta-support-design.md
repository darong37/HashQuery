# HashQuery メタ情報付き配列対応 設計ドキュメント

Date: 2026-04-05

## 概要

TableTools が生成するメタ情報付き配列（先頭要素に `{ '#' => { attrs, order } }` を持つ配列）を HashQuery が入力として受け取り、SELECT/DELETE/UPDATE の結果にも適切なメタ情報を付与して返す。

## 背景

TableTools の `validate` 等が返す配列はメタ情報を先頭要素として持つ。現状の HashQuery はこの形式を受け取れず、`_check_cols` でエラーになる。

## データ形式

```perl
# プレーン（従来形式）
[
    { a => 1, b => 'foo' },
    { a => 2, b => 'bar' },
]

# メタ付き（TableTools 形式）
[
    { '#' => { attrs => { a => 'num', b => 'str' }, order => ['a', 'b'] } },
    { a => 1, b => 'foo' },
    { a => 2, b => 'bar' },
]
```

## 設計方針

- TableTools の `detach`/`attach` を使ってメタとデータ行を分離・再付与する
- `$self->{meta}` にメタを保持し、出力時に操作種別に応じてメタを処理して付与する
- メタが `undef`（プレーン入力）の場合は `attach` がそのまま返すため既存動作と完全互換
- attrs の型情報は変更・再判定しない（TableTools/SQL が正とする）

## 操作別のメタ返却方針

| 操作   | 列集合の変化 | メタの扱い |
|--------|------------|------------|
| DELETE | 変化なし   | 元メタをそのまま返す |
| UPDATE | 変化なし   | 元メタをそのまま返す |
| SELECT | 減る可能性 | 出力列 `$cols` に合わせて attrs/order をその場で作り直す |

## 変更箇所

### `new()` — メタ分離と列情報の確定（インライン分岐）

```perl
use TableTools qw(detach attach);

sub new {
    my ($class, $table, $opts) = @_;
    die 'HashQuery->new requires an Array of Hash'
        unless ref $table eq 'ARRAY';

    my ($rows, $meta) = detach($table);

    my @all;
    if (@$rows) {
        @all = _check_cols($rows);                              # 行があれば従来どおり
    } elsif ($meta && $meta->{'#'}{order}) {
        @all = @{ $meta->{'#'}{order} };                       # 空行・order あり
    } elsif ($meta && $meta->{'#'}{attrs}) {
        @all = sort keys %{ $meta->{'#'}{attrs} };             # 空行・attrs あり
    }
    # どちらもなければ @all は空のまま

    my $alias;
    if ($opts && ref $opts eq 'HASH') {
        $alias = $opts->{as};
    }

    return bless {
        table => clone($rows),
        all   => \@all,
        alias => $alias,
        meta  => $meta,
    }, $class;
}
```

### `SELECT` の戻り値 — 出力列に合わせてメタをその場で作り直す

新しいヘルパー関数は作らず、SELECT の返却直前にインラインで処理する。

```perl
my $out_meta;
if ($self->{meta}) {
    my $base_attrs = $self->{meta}{'#'}{attrs} // {};
    $out_meta = { '#' => {
        attrs => { map { $_ => $base_attrs->{$_} } @$cols },
        order => [@$cols],
    }};
}
return attach($result, $out_meta);
```

- `$cols` は SELECT で確定した返却列リスト（`'*'`・arrayref・`except` いずれの場合も確定済み）
- `order` は `@$cols` の順序そのもの
- `attrs` は `$cols` に含まれる列のみを元 `attrs` から抽出（存在しないキーは `undef` になるが、元メタに定義されている列しか `$cols` に入らないため実際は問題ない）
- メタが `undef`（プレーン入力）なら `$out_meta` は `undef` のまま、`attach` はそのまま返す

### `DELETE` / `UPDATE` の戻り値 — 元メタをそのまま返す

```perl
return attach($result, $self->{meta});
```

## テスト方針

**メタ付き入力の基本動作**
- メタ付き配列を `new()` に渡せること
- DELETE / UPDATE の結果に元メタがそのまま付与されること

**SELECT のメタ射影**
- `SELECT '*'` の結果に全列の attrs/order が付与されること
- `SELECT ['a']` の結果に `a` だけの attrs/order が付与されること
- `SELECT except('b')` の結果に `b` を除いた attrs/order が付与されること

**空行のメタ付き入力**
- rows が空で `order` がある場合、`@all` が復元され SELECT/UPDATE の列検証が機能すること
- rows が空で `order` がなく `attrs` だけある場合も同様に機能すること

**互換性**
- プレーン入力では既存の全テストが引き続き通ること

## 非対応（将来課題）

- UPDATE 後の attrs 型再判定（将来オプションとして検討）
