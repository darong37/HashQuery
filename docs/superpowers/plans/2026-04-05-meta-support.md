# メタ情報付き配列対応 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** HashQuery が TableTools 形式のメタ情報付き配列を入力として受け取り、SELECT/DELETE/UPDATE の結果にも適切なメタ情報を付与して返す。

**Architecture:** `new()` で `detach()` によりメタとデータ行を分離し `$self->{meta}` に保持。DELETE/UPDATE は `attach($result, $self->{meta})` で元メタをそのまま返す。SELECT は出力列 `$cols` に合わせてメタを射影した `$out_meta` を構築してから `attach` する。

**Tech Stack:** Perl, TableTools (detach/attach), Clone, Test::More

---

## ファイル構成

| ファイル | 変更種別 | 内容 |
|---------|---------|------|
| `.claude/worktrees/feature-meta-support/src/HashQuery.pm` | 修正 | `use TableTools`, `new()`, `SELECT`, `DELETE`, `UPDATE` |
| `.claude/worktrees/feature-meta-support/test/hashquery.t` | 修正 | メタ付きテストケースを追加 |

テストはプロジェクトルートから実行する（`lib/TableTools.pm` を参照するため）:
```bash
perl .claude/worktrees/feature-meta-support/test/hashquery.t
```

---

## Task 1: `new()` — メタ付き配列の受け入れと列情報の確定

**Files:**
- Modify: `.claude/worktrees/feature-meta-support/test/hashquery.t`
- Modify: `.claude/worktrees/feature-meta-support/src/HashQuery.pm`

- [ ] **Step 1: テストデータとテストを追加する**

`test/hashquery.t` の `done_testing;` の直前に以下のブロックを追加する:

```perl
# ===========================================================================
# メタ情報付き配列対応
# ===========================================================================

my @meta_base = (
    { '#' => { attrs => { a => 'str', b => 'num', c => 'num' }, order => [qw/a b c/] } },
    { a => 'alice', b => 10, c => 100 },
    { a => 'bob',   b => 20, c => 200 },
    { a => 'carol', b => 30, c => 300 },
);

my @meta_empty_with_order = (
    { '#' => { attrs => { a => 'str', b => 'num' }, order => [qw/a b/] } },
);

my @meta_empty_attrs_only = (
    { '#' => { attrs => { x => 'num', y => 'str' } } },
);

subtest 'new: メタ付き配列を受け取れる' => sub {
    my $hq = HashQuery->new(\@meta_base);
    isa_ok $hq, 'HashQuery';
};

subtest 'new: メタ付き配列でカラム構成を正しく認識する' => sub {
    my $hq = HashQuery->new(\@meta_base);
    my $r = $hq->SELECT('*');
    # メタ行を除いた3行が返る
    my @rows = grep { !exists $_->{'#'} } @$r;
    is scalar @rows, 3;
};

subtest 'new: rows が空でメタに order がある場合、列を復元できる' => sub {
    my $hq = HashQuery->new(\@meta_empty_with_order);
    isa_ok $hq, 'HashQuery';
    # SELECT '*' が列情報を持って動作する（0件返る）
    my $r = $hq->SELECT('*');
    my @rows = grep { !exists $_->{'#'} } @$r;
    is scalar @rows, 0;
};

subtest 'new: rows が空でメタに attrs のみある場合、列を復元できる' => sub {
    my $hq = HashQuery->new(\@meta_empty_attrs_only);
    isa_ok $hq, 'HashQuery';
    my $r = $hq->SELECT('*');
    my @rows = grep { !exists $_->{'#'} } @$r;
    is scalar @rows, 0;
};
```

- [ ] **Step 2: テストが失敗することを確認する**

```bash
perl .claude/worktrees/feature-meta-support/test/hashquery.t 2>&1 | grep -E 'not ok|ok.*メタ'
```

期待: `not ok` が含まれる（`_check_cols` が `'#'` キーでエラーになる）

- [ ] **Step 3: `src/HashQuery.pm` を実装する**

ファイル冒頭の `use Clone qw(clone);` の直後に追加:
```perl
use TableTools qw(detach attach);
```

`new()` の内部を以下に変更（`die` と `return bless` の間）:

```perl
sub new {
    my ($class, $table, $opts) = @_;

    die 'HashQuery->new requires an Array of Hash'
        unless ref $table eq 'ARRAY';

    my ($rows, $meta) = detach($table);

    my @all;
    if (@$rows) {
        @all = _check_cols($rows);
    } elsif ($meta && $meta->{'#'}{order}) {
        @all = @{ $meta->{'#'}{order} };
    } elsif ($meta && $meta->{'#'}{attrs}) {
        @all = sort keys %{ $meta->{'#'}{attrs} };
    }

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

- [ ] **Step 4: テストが通ることを確認する**

```bash
perl .claude/worktrees/feature-meta-support/test/hashquery.t 2>&1 | tail -5
```

期待: `# Looks like your test is successful.` または `ok` のみ

- [ ] **Step 5: 既存テストが全て通ることを確認する**

```bash
perl .claude/worktrees/feature-meta-support/test/hashquery.t 2>&1 | grep -c 'not ok'
```

期待: `0`

- [ ] **Step 6: コミットする**

```bash
cd .claude/worktrees/feature-meta-support
git add src/HashQuery.pm test/hashquery.t
git commit -m "feat: new() でメタ付き配列を受け取れるようにする"
```

---

## Task 2: `SELECT` — 出力列に射影したメタを返す

**Files:**
- Modify: `.claude/worktrees/feature-meta-support/test/hashquery.t`
- Modify: `.claude/worktrees/feature-meta-support/src/HashQuery.pm`

- [ ] **Step 1: テストを追加する**

Task 1 で追加したブロックの末尾（`done_testing;` の直前）に追加:

```perl
subtest 'SELECT: メタ付き入力で * を指定すると全列の attrs/order が返る' => sub {
    my $hq = HashQuery->new(\@meta_base);
    my $r  = $hq->SELECT('*');
    my $m  = $r->[0]{'#'};
    ok defined $m, 'メタが付いている';
    is_deeply $m->{order}, [qw/a b c/];
    is_deeply $m->{attrs}, { a => 'str', b => 'num', c => 'num' };
    my @rows = @{$r}[1..$#$r];
    is scalar @rows, 3;
};

subtest 'SELECT: メタ付き入力で列を絞ると attrs/order が射影される' => sub {
    my $hq = HashQuery->new(\@meta_base);
    my $r  = $hq->SELECT([qw/a b/]);
    my $m  = $r->[0]{'#'};
    ok defined $m, 'メタが付いている';
    is_deeply $m->{order}, [qw/a b/];
    is_deeply $m->{attrs}, { a => 'str', b => 'num' };
    ok !exists $m->{attrs}{c}, 'c は attrs に含まれない';
};

subtest 'SELECT: メタ付き入力で except を使うと attrs/order が射影される' => sub {
    my $hq = HashQuery->new(\@meta_base);
    my $r  = $hq->SELECT(except('c'));
    my $m  = $r->[0]{'#'};
    ok defined $m, 'メタが付いている';
    is_deeply $m->{order}, [qw/a b/];
    is_deeply $m->{attrs}, { a => 'str', b => 'num' };
};

subtest 'SELECT: プレーン入力は従来どおりメタなしで返る' => sub {
    my $hq = HashQuery->new(\@base);
    my $r  = $hq->SELECT('*');
    ok !exists $r->[0]{'#'}, 'メタ行がない';
    is scalar @$r, 5;
};
```

- [ ] **Step 2: テストが失敗することを確認する**

```bash
perl .claude/worktrees/feature-meta-support/test/hashquery.t 2>&1 | grep -E 'not ok.*SELECT.*メタ'
```

期待: `not ok` が含まれる

- [ ] **Step 3: `SELECT()` の戻り値を変更する**

`src/HashQuery.pm` の `SELECT` メソッド末尾の `return $result;` を以下に差し替える:

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

- [ ] **Step 4: テストが通ることを確認する**

```bash
perl .claude/worktrees/feature-meta-support/test/hashquery.t 2>&1 | grep -c 'not ok'
```

期待: `0`

- [ ] **Step 5: コミットする**

```bash
cd .claude/worktrees/feature-meta-support
git add src/HashQuery.pm test/hashquery.t
git commit -m "feat: SELECT で出力列に射影したメタを返す"
```

---

## Task 3: `DELETE` — 元メタをそのまま返す

**Files:**
- Modify: `.claude/worktrees/feature-meta-support/test/hashquery.t`
- Modify: `.claude/worktrees/feature-meta-support/src/HashQuery.pm`

- [ ] **Step 1: テストを追加する**

```perl
subtest 'DELETE: メタ付き入力は元メタをそのまま返す' => sub {
    my $hq = HashQuery->new(\@meta_base);
    my $r  = $hq->DELETE(where { $_->{b} == 10 });
    my $m  = $r->[0]{'#'};
    ok defined $m, 'メタが付いている';
    is_deeply $m->{order}, [qw/a b c/];
    is_deeply $m->{attrs}, { a => 'str', b => 'num', c => 'num' };
    my @rows = @{$r}[1..$#$r];
    is scalar @rows, 2;
};

subtest 'DELETE: プレーン入力は従来どおりメタなしで返る' => sub {
    my $hq = HashQuery->new(\@base);
    my $r  = $hq->DELETE(where { $_->{b} == 10 });
    ok !exists $r->[0]{'#'}, 'メタ行がない';
};
```

- [ ] **Step 2: テストが失敗することを確認する**

```bash
perl .claude/worktrees/feature-meta-support/test/hashquery.t 2>&1 | grep -E 'not ok.*DELETE.*メタ'
```

- [ ] **Step 3: `DELETE()` の戻り値を変更する**

`src/HashQuery.pm` の `DELETE` メソッド末尾の `return $result;` を以下に差し替える:

```perl
    return attach($result, $self->{meta});
```

- [ ] **Step 4: テストが通ることを確認する**

```bash
perl .claude/worktrees/feature-meta-support/test/hashquery.t 2>&1 | grep -c 'not ok'
```

期待: `0`

- [ ] **Step 5: コミットする**

```bash
cd .claude/worktrees/feature-meta-support
git add src/HashQuery.pm test/hashquery.t
git commit -m "feat: DELETE で元メタをそのまま返す"
```

---

## Task 4: `UPDATE` — 元メタをそのまま返す

**Files:**
- Modify: `.claude/worktrees/feature-meta-support/test/hashquery.t`
- Modify: `.claude/worktrees/feature-meta-support/src/HashQuery.pm`

- [ ] **Step 1: テストを追加する**

```perl
subtest 'UPDATE: メタ付き入力は元メタをそのまま返す' => sub {
    my $hq = HashQuery->new(\@meta_base);
    my $r  = $hq->UPDATE({ b => 99 }, where { $_->{b} == 10 });
    my $m  = $r->[0]{'#'};
    ok defined $m, 'メタが付いている';
    is_deeply $m->{order}, [qw/a b c/];
    is_deeply $m->{attrs}, { a => 'str', b => 'num', c => 'num' };
    my @rows = @{$r}[1..$#$r];
    is scalar @rows, 3;
    my @updated = grep { $_->{b} == 99 } @rows;
    is scalar @updated, 1;
};

subtest 'UPDATE: プレーン入力は従来どおりメタなしで返る' => sub {
    my $hq = HashQuery->new(\@base);
    my $r  = $hq->UPDATE({ b => 99 }, where { $_->{b} == 10 });
    ok !exists $r->[0]{'#'}, 'メタ行がない';
};
```

- [ ] **Step 2: テストが失敗することを確認する**

```bash
perl .claude/worktrees/feature-meta-support/test/hashquery.t 2>&1 | grep -E 'not ok.*UPDATE.*メタ'
```

- [ ] **Step 3: `UPDATE()` の戻り値を変更する**

`src/HashQuery.pm` の `UPDATE` メソッド末尾の `return $result;` を以下に差し替える:

```perl
    return attach($result, $self->{meta});
```

- [ ] **Step 4: テストが全て通ることを確認する**

```bash
perl .claude/worktrees/feature-meta-support/test/hashquery.t 2>&1 | tail -3
```

期待: `not ok` が0件

- [ ] **Step 5: コミットする**

```bash
cd .claude/worktrees/feature-meta-support
git add src/HashQuery.pm test/hashquery.t
git commit -m "feat: UPDATE で元メタをそのまま返す"
```
