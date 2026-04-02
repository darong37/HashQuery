# HashQuery OOP 再設計 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** HashQuery を関数ベース DSL からオブジェクト指向 API に完全再設計し、`HashQuery->new(\@table)` でインスタンスを生成して `SELECT`/`DELETE`/`UPDATE` をメソッドとして呼び出せるようにする

**Architecture:** `src/HashQuery.pm` を全面書き換えし、`HashQuery` クラスに `new`/`SELECT`/`DELETE`/`UPDATE` を追加する。内部実装（`_run_where`/`_run_having`/`_run_select`/`_run_delete`/`_run_update`/`HashQuery::RowHash`/`HashQuery::Value`/`HashQuery::WhereContext`/`HashQuery::HavingContext`）は引き続き使用するが、`$as` DSL ノードの受け渡しを廃止し `$alias`（スカラーリファレンス）を直接受け渡す形に変更する。後方互換性なし、`query` 関数は完全廃止。

**Tech Stack:** Perl, Test::More, Clone

---

## ファイル構成

- Modify: `src/HashQuery.pm` — 全面書き換え（1ファイル構成は維持）
- Modify: `test/hashquery.t` — 全面書き換え（新 API に対応）

---

### Task 1: ブランチ作成・`@EXPORT` 更新・`as`/`except`/`set` 実装

**Files:**
- Modify: `src/HashQuery.pm`（`@EXPORT`、`as`、`except`、`set`）
- Modify: `test/hashquery.t`（テストデータ＋ヘルパー関数テスト）

- [ ] **Step 1: ブランチを作成する**

```bash
cd /Users/darong/PRJDEV/HashQuery
git checkout -b feature/oop-redesign
```

期待: `Switched to a new branch 'feature/oop-redesign'`

- [ ] **Step 2: テストファイルをヘルパー関数テストのみに書き換える**

`test/hashquery.t` を以下で完全置き換え:

```perl
use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../src";

use HashQuery;

# ===========================================================================
# テストデータ
# ===========================================================================

my @base = (
    { a => 'alice', b => 10, c => 100 },
    { a => 'bob',   b => 20, c => 200 },
    { a => 'carol', b => 30, c => 300 },
    { a => 'dave',  b => 10, c => 150 },
    { a => 'eve',   b => 20, c => 250 },
);

my @null_tbl = (
    { name => 'x', val => undef },
    { name => 'y', val => 42    },
    { name => 'z', val => ''    },
);

my @log_tbl = (
    { line => 1, msg => 'INFO  start'             },
    { line => 2, msg => 'ERROR connection failed' },
    { line => 3, msg => 'INFO  retrying'          },
    { line => 4, msg => 'ERROR timeout'           },
    { line => 5, msg => 'INFO  done'              },
);

my @edge_log = (
    { line => 1, msg => 'ERROR first'  },
    { line => 2, msg => 'INFO  second' },
    { line => 3, msg => 'INFO  third'  },
    { line => 4, msg => 'INFO  fourth' },
    { line => 5, msg => 'ERROR last'   },
);

my @members = (
    { team => 'alpha', name => 'alice', role => 'lead',   score => 90 },
    { team => 'alpha', name => 'bob',   role => 'member', score => 75 },
    { team => 'alpha', name => 'carol', role => 'member', score => 82 },
    { team => 'beta',  name => 'dave',  role => 'lead',   score => 88 },
    { team => 'beta',  name => 'eve',   role => 'member', score => 70 },
    { team => 'gamma', name => 'frank', role => 'lead',   score => 95 },
    { team => 'gamma', name => 'grace', role => 'member', score => 60 },
);

# ===========================================================================
# as / except / set
# ===========================================================================

subtest 'as: { as => \$var } を返す' => sub {
    our $v;
    my $node = as $v;
    is ref $node, 'HASH';
    is $node->{as}, \$v;
};

subtest 'except: { except => [...] } を返す' => sub {
    my $node = except('c');
    is_deeply $node, { except => ['c'] };
};

subtest 'except: 複数カラムを指定できる' => sub {
    my $node = except('b', 'c');
    is_deeply $node, { except => ['b', 'c'] };
};

subtest 'set: ハッシュリファレンスを返す' => sub {
    my $node = set(score => 99, grade => 'A');
    is_deeply $node, { score => 99, grade => 'A' };
};

done_testing;
```

- [ ] **Step 3: テストが失敗することを確認する**

```bash
cd /Users/darong/PRJDEV/HashQuery && perl -Ilib -Isrc test/hashquery.t 2>&1 | tail -10
```

期待: `as`/`except`/`set` 関数未定義でエラー

- [ ] **Step 4: `@EXPORT`・`as`・`except`・`set` を実装する**

`src/HashQuery.pm` の `@EXPORT` を以下に更新:

```perl
our @EXPORT = qw(
    as
    except
    set
    where
    having
    count_by
    max_by
    min_by
    first_by
    last_by
    grep_concat
);
```

`sub as` を以下に変更（戻り値キーを `alias` から `as` に変更）:

```perl
sub as (\$) {
    my ($var) = @_;
    return { as => $var };
}
```

`sub except` を追加（`sub as` の直後）:

```perl
sub except (@) {
    die 'except requires at least one column name' unless @_;
    return { except => [@_] };
}
```

`sub set` を追加（`sub except` の直後）:

```perl
sub set (@) {
    my %h = @_;
    return \%h;
}
```

- [ ] **Step 5: テストが通ることを確認する**

```bash
cd /Users/darong/PRJDEV/HashQuery && perl -Ilib -Isrc test/hashquery.t 2>&1 | tail -5
```

期待: `1..4`、全パス

- [ ] **Step 6: コミット**

```bash
cd /Users/darong/PRJDEV/HashQuery && git add . && git commit -m "feat(oop): ブランチ作成・@EXPORT 更新・as/except/set 実装"
```

---

### Task 2: `HashQuery->new` コンストラクタ実装

**Files:**
- Modify: `src/HashQuery.pm`（`sub new` 追加）
- Modify: `test/hashquery.t`（new テスト追加）

- [ ] **Step 1: `new` のテストを書く**

`test/hashquery.t` の `done_testing;` 直前に追加:

```perl
# ===========================================================================
# HashQuery->new
# ===========================================================================

subtest 'new: インスタンスを生成できる' => sub {
    my $hq = HashQuery->new(\@base);
    ok defined $hq;
    isa_ok $hq, 'HashQuery';
};

subtest 'new: 配列リファレンス以外を渡すと die する' => sub {
    eval { HashQuery->new([]) };
    ok !$@;
    eval { HashQuery->new('string') };
    like $@, qr/HashQuery->new requires an Array of Hash/;
};

subtest 'new: カラム構成が不一致だと die する' => sub {
    my @bad = ({ a => 1 }, { b => 2 });
    eval { HashQuery->new(\@bad) };
    like $@, qr/table columns are not consistent/;
};

subtest 'new: 元テーブルを変更しない' => sub {
    my @orig = ({ a => 1, b => 2 }, { a => 3, b => 4 });
    my @copy = map { +{ %$_ } } @orig;
    HashQuery->new(\@orig);
    is_deeply \@orig, \@copy;
};

subtest 'new: as オプションを受け取れる（as $var 形式）' => sub {
    our $v;
    my $hq = HashQuery->new(\@base, as $v);
    isa_ok $hq, 'HashQuery';
};

subtest 'new: as オプションを受け取れる（ハッシュリファレンス形式）' => sub {
    our $v2;
    my $hq = HashQuery->new(\@base, { as => \$v2 });
    isa_ok $hq, 'HashQuery';
};

subtest 'new: 空テーブルでインスタンスを生成できる' => sub {
    my $hq = HashQuery->new([]);
    isa_ok $hq, 'HashQuery';
};
```

- [ ] **Step 2: テストが失敗することを確認する**

```bash
cd /Users/darong/PRJDEV/HashQuery && perl -Ilib -Isrc test/hashquery.t 2>&1 | grep "not ok"
```

期待: `new` 関連テストが失敗

- [ ] **Step 3: `sub new` を実装する**

`src/HashQuery.pm` の `sub as` の前に追加:

```perl
sub new {
    my ($class, $table, $opts) = @_;

    die 'HashQuery->new requires an Array of Hash'
        unless ref $table eq 'ARRAY';

    my @all = _check_cols($table);

    my $alias;
    if ($opts && ref $opts eq 'HASH') {
        $alias = $opts->{as};
    }

    return bless {
        table => clone($table),
        all   => \@all,
        alias => $alias,
    }, $class;
}
```

- [ ] **Step 4: テストが通ることを確認する**

```bash
cd /Users/darong/PRJDEV/HashQuery && perl -Ilib -Isrc test/hashquery.t 2>&1 | tail -5
```

期待: `1..11`、全パス

- [ ] **Step 5: コミット**

```bash
cd /Users/darong/PRJDEV/HashQuery && git add . && git commit -m "feat(oop): HashQuery->new コンストラクタを実装する"
```

---

### Task 3: `SELECT` メソッド実装

**Files:**
- Modify: `src/HashQuery.pm`（`sub SELECT`、`_run_where`/`_run_having` のシグネチャ更新）
- Modify: `test/hashquery.t`（SELECT テスト追加）

- [ ] **Step 1: SELECT のテストを書く**

`test/hashquery.t` の `done_testing;` 直前に追加:

```perl
# ===========================================================================
# SELECT メソッド
# ===========================================================================

subtest 'SELECT: * で全列・全行を返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*');
    is scalar @$r, 5;
    ok exists $r->[0]{a};
    ok exists $r->[0]{b};
    ok exists $r->[0]{c};
};

subtest 'SELECT: 配列リファレンスで列を指定できる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT([qw/a b/]);
    is scalar @$r, 5;
    ok  exists $r->[0]{a};
    ok  exists $r->[0]{b};
    ok !exists $r->[0]{c};
};

subtest 'SELECT: except で列を除外できる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT(except('c'));
    is scalar @$r, 5;
    ok  exists $r->[0]{a};
    ok  exists $r->[0]{b};
    ok !exists $r->[0]{c};
};

subtest 'SELECT: except で複数列を除外できる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT(except('b', 'c'));
    ok  exists $r->[0]{a};
    ok !exists $r->[0]{b};
    ok !exists $r->[0]{c};
};

subtest 'SELECT: _idx は出力に含まれない' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*');
    ok !exists $r->[0]{_idx};
};

subtest 'SELECT: undef を渡すと die する' => sub {
    my $hq = HashQuery->new(\@base);
    eval { $hq->SELECT(undef) };
    like $@, qr/SELECT requires/;
};

subtest 'SELECT: where で行をフィルタできる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', where { $_->{b} == 10 });
    is scalar @$r, 2;
    my @names = sort map { $_->{a} } @$r;
    is_deeply \@names, [qw/alice dave/];
};

subtest 'SELECT: having で集約フィルタできる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', having { count_by('b') > 1 });
    is scalar @$r, 4;
    ok !grep { $_->{a} eq 'carol' } @$r;
};

subtest 'SELECT: where と having を組み合わせられる' => sub {
    my $hq = HashQuery->new(\@members);
    my $r = $hq->SELECT(
        [qw/team name score/],
        where  { $_->{score} >= 75 },
        having { count_by('team') >= 2 },
    );
    is scalar @$r, 3;
    ok !grep { $_->{team} ne 'alpha' } @$r;
};

subtest 'SELECT: as で count/affect が返る' => sub {
    our $s1;
    my $hq = HashQuery->new(\@base, as $s1);
    $hq->SELECT('*', where { $_->{b} == 10 });
    is $s1->{count},  2;
    is $s1->{affect}, 2;
};

subtest 'SELECT: 同じインスタンスを複数回呼べる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r1 = $hq->SELECT('*', where { $_->{b} == 10 });
    my $r2 = $hq->SELECT('*', where { $_->{b} == 20 });
    is scalar @$r1, 2;
    is scalar @$r2, 2;
};

subtest 'SELECT: 元テーブルは変更されない' => sub {
    my @orig = ({ a => 1, b => 2 }, { a => 3, b => 4 });
    my @copy = map { +{ %$_ } } @orig;
    my $hq = HashQuery->new(\@orig);
    $hq->SELECT('*');
    is_deeply \@orig, \@copy;
};
```

- [ ] **Step 2: テストが失敗することを確認する**

```bash
cd /Users/darong/PRJDEV/HashQuery && perl -Ilib -Isrc test/hashquery.t 2>&1 | grep "not ok" | head -5
```

期待: SELECT 関連テストが失敗

- [ ] **Step 3: `_run_where`・`_run_having` のシグネチャを更新する**

現在の `_run_where` を以下に置き換え（`$as` DSL ノードの代わりに `$alias` スカラーリファレンスを直接受け取る）:

```perl
sub _run_where {
    my ($tbl, $matched, $alias, $whr) = @_;
    my @hit;

    for my $i (@$matched) {
        my $row = $tbl->[$i];
        my $h   = HashQuery::RowHash->new($row, $tbl, $i);
        local $_ = $h;
        local $HashQuery::WhereContext::ROW   = $row;
        local $HashQuery::WhereContext::TABLE = $tbl;

        if ($alias) {
            $$alias = $h;
            push @hit, $i if $whr->{where}->();
        }
        else {
            push @hit, $i if $whr->{where}->();
        }
    }

    return \@hit;
}
```

現在の `_run_having` を以下に置き換え:

```perl
sub _run_having {
    my ($tbl, $matched, $alias, $hvg) = @_;
    my @hit;

    my @matched_rows = map { $tbl->[$_] } @$matched;

    for my $i (@$matched) {
        my $row = $tbl->[$i];
        my $h   = HashQuery::RowHash->new($row, $tbl, $i);
        local $_ = $h;
        local $HashQuery::HavingContext::ROW   = $row;
        local $HashQuery::HavingContext::TABLE = \@matched_rows;

        if ($alias) {
            $$alias = $h;
            push @hit, $i if $hvg->{having}->();
        }
        else {
            push @hit, $i if $hvg->{having}->();
        }
    }

    return \@hit;
}
```

- [ ] **Step 4: `sub SELECT` メソッドを実装する**

`sub new` の直後に追加:

```perl
sub SELECT {
    my ($self, $cols_arg, @dsls) = @_;

    # 列リストを確定する
    my $cols;
    if (!defined $cols_arg) {
        die "SELECT requires '*', arrayref, or except(...)";
    }
    elsif (!ref $cols_arg && $cols_arg eq '*') {
        $cols = $self->{all};
    }
    elsif (ref $cols_arg eq 'ARRAY') {
        $cols = $cols_arg;
    }
    elsif (ref $cols_arg eq 'HASH' && exists $cols_arg->{except}) {
        my %skip = map { $_ => 1 } @{ $cols_arg->{except} };
        $cols = [ grep { !$skip{$_} } @{ $self->{all} } ];
    }
    else {
        die "SELECT requires '*', arrayref, or except(...)";
    }

    # DSL パーツを解釈する
    my ($whr, $hvg);
    for my $dsl (@dsls) {
        if    (exists $dsl->{where})  { $whr = $dsl }
        elsif (exists $dsl->{having}) { $hvg = $dsl }
        else  { die 'invalid DSL part' }
    }

    # 実行
    my $tbl = clone($self->{table});
    for my $i (0 .. $#$tbl) { $tbl->[$i]{_idx} = $i; }

    my $matched = [0 .. $#$tbl];
    $matched = _run_where($tbl, $matched, $self->{alias}, $whr) if $whr;
    $matched = _run_having($tbl, $matched, $self->{alias}, $hvg) if $hvg;

    my $result = _run_select($tbl, $matched, $cols);

    if ($self->{alias}) {
        ${ $self->{alias} } = {
            count  => scalar @$result,
            affect => scalar @$result,
        };
    }

    return $result;
}
```

- [ ] **Step 5: テストが通ることを確認する**

```bash
cd /Users/darong/PRJDEV/HashQuery && perl -Ilib -Isrc test/hashquery.t 2>&1 | tail -5
```

期待: `1..23`、全パス

- [ ] **Step 6: コミット**

```bash
cd /Users/darong/PRJDEV/HashQuery && git add . && git commit -m "feat(oop): SELECT メソッドを実装する"
```

---

### Task 4: `DELETE` メソッド実装

**Files:**
- Modify: `src/HashQuery.pm`（`sub DELETE` メソッド追加）
- Modify: `test/hashquery.t`（DELETE テスト追加）

- [ ] **Step 1: DELETE のテストを書く**

`test/hashquery.t` の `done_testing;` 直前に追加:

```perl
# ===========================================================================
# DELETE メソッド
# ===========================================================================

subtest 'DELETE: where にマッチした行を削除して残りを返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->DELETE(where { $_->{b} == 10 });
    is scalar @$r, 3;
    my @names = sort map { $_->{a} } @$r;
    is_deeply \@names, [qw/bob carol eve/];
};

subtest 'DELETE: 条件なしで全行を返す（何も削除しない）' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->DELETE();
    is scalar @$r, 5;
};

subtest 'DELETE: 一致なしで全行残る' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->DELETE(where { $_->{b} > 999 });
    is scalar @$r, 5;
};

subtest 'DELETE: having と組み合わせて削除できる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->DELETE(having { count_by('b') > 1 });
    is scalar @$r, 1;
    is $r->[0]{a}, 'carol';
};

subtest 'DELETE: _idx は出力に含まれない' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->DELETE(where { $_->{b} > 999 });
    ok !exists $r->[0]{_idx};
};

subtest 'DELETE: 元テーブルは変更されない' => sub {
    my @orig = ({ a => 1, b => 2 }, { a => 3, b => 4 });
    my @copy = map { +{ %$_ } } @orig;
    my $hq = HashQuery->new(\@orig);
    $hq->DELETE(where { $_->{a} == 1 });
    is_deeply \@orig, \@copy;
};

subtest 'DELETE: as で count/affect が返る' => sub {
    our $d1;
    my $hq = HashQuery->new(\@base, as $d1);
    $hq->DELETE(where { $_->{b} == 10 });
    is $d1->{count},  3;
    is $d1->{affect}, 2;
};

subtest 'DELETE: SELECT と対称動作する' => sub {
    my $hq = HashQuery->new(\@base);
    my $selected = $hq->SELECT('*', where { $_->{b} == 10 });
    my $deleted  = $hq->DELETE(where { $_->{b} == 10 });
    is scalar @$selected + scalar @$deleted, 5;
};
```

- [ ] **Step 2: テストが失敗することを確認する**

```bash
cd /Users/darong/PRJDEV/HashQuery && perl -Ilib -Isrc test/hashquery.t 2>&1 | grep "not ok" | head -5
```

期待: DELETE 関連テストが失敗

- [ ] **Step 3: `sub DELETE` メソッドを実装する**

`sub SELECT` の直後に追加:

```perl
sub DELETE {
    my ($self, @dsls) = @_;

    my ($whr, $hvg);
    for my $dsl (@dsls) {
        if    (exists $dsl->{where})  { $whr = $dsl }
        elsif (exists $dsl->{having}) { $hvg = $dsl }
        else  { die 'invalid DSL part' }
    }

    my $tbl = clone($self->{table});
    for my $i (0 .. $#$tbl) { $tbl->[$i]{_idx} = $i; }

    my $matched = [0 .. $#$tbl];
    $matched = _run_where($tbl, $matched, $self->{alias}, $whr) if $whr;
    $matched = _run_having($tbl, $matched, $self->{alias}, $hvg) if $hvg;

    my $result = _run_delete($tbl, $matched);

    if ($self->{alias}) {
        ${ $self->{alias} } = {
            count  => scalar @$result,
            affect => scalar @$matched,
        };
    }

    return $result;
}
```

- [ ] **Step 4: テストが通ることを確認する**

```bash
cd /Users/darong/PRJDEV/HashQuery && perl -Ilib -Isrc test/hashquery.t 2>&1 | tail -5
```

期待: `1..31`、全パス

- [ ] **Step 5: コミット**

```bash
cd /Users/darong/PRJDEV/HashQuery && git add . && git commit -m "feat(oop): DELETE メソッドを実装する"
```

---

### Task 5: `UPDATE` メソッド実装

**Files:**
- Modify: `src/HashQuery.pm`（`sub UPDATE` メソッド追加）
- Modify: `test/hashquery.t`（UPDATE テスト追加）

- [ ] **Step 1: UPDATE のテストを書く**

`test/hashquery.t` の `done_testing;` 直前に追加:

```perl
# ===========================================================================
# UPDATE メソッド
# ===========================================================================

subtest 'UPDATE: where にマッチした行を更新して全行返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->UPDATE({ b => 99 }, where { $_->{b} == 10 });
    is scalar @$r, 5;
    my @updated = grep { $_->{b} == 99 } @$r;
    my @names   = sort map { $_->{a} } @updated;
    is_deeply \@names, [qw/alice dave/];
};

subtest 'UPDATE: set 関数形式でも更新できる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->UPDATE(set(b => 99), where { $_->{b} == 10 });
    is scalar @$r, 5;
    my @updated = grep { $_->{b} == 99 } @$r;
    is scalar @updated, 2;
};

subtest 'UPDATE: 条件なしで全行更新する' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->UPDATE({ b => 0 });
    is scalar @$r, 5;
    my @vals = map { $_->{b} } @$r;
    is_deeply \@vals, [0, 0, 0, 0, 0];
};

subtest 'UPDATE: 一致なしで全行そのまま返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->UPDATE({ b => 0 }, where { $_->{b} > 999 });
    is scalar @$r, 5;
    my @vals = map { $_->{b} } @$r;
    is_deeply \@vals, [10, 20, 30, 10, 20];
};

subtest 'UPDATE: having と組み合わせて更新できる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->UPDATE({ b => 0 }, having { count_by('b') > 1 });
    my @zeroed = grep { $_->{b} == 0 } @$r;
    is scalar @zeroed, 4;
    my @intact = grep { $_->{b} != 0 } @$r;
    is $intact[0]{a}, 'carol';
};

subtest 'UPDATE: 複数カラムを同時に更新できる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->UPDATE({ b => 0, c => 0 }, where { $_->{a} eq 'alice' });
    my ($alice) = grep { $_->{a} eq 'alice' } @$r;
    is $alice->{b}, 0;
    is $alice->{c}, 0;
};

subtest 'UPDATE: _idx は出力に含まれない' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->UPDATE({ b => 0 });
    ok !exists $r->[0]{_idx};
};

subtest 'UPDATE: 元テーブルは変更されない' => sub {
    my @orig = ({ a => 1, b => 2 }, { a => 3, b => 4 });
    my @copy = map { +{ %$_ } } @orig;
    my $hq = HashQuery->new(\@orig);
    $hq->UPDATE({ b => 99 }, where { $_->{a} == 1 });
    is_deeply \@orig, \@copy;
};

subtest 'UPDATE: as で count/affect が返る' => sub {
    our $u1;
    my $hq = HashQuery->new(\@base, as $u1);
    $hq->UPDATE({ b => 0 }, where { $_->{b} == 10 });
    is $u1->{count},  5;
    is $u1->{affect}, 2;
};

subtest 'UPDATE: 存在しないカラムを指定すると die する' => sub {
    my $hq = HashQuery->new(\@base);
    eval { $hq->UPDATE({ nonexistent => 1 }) };
    like $@, qr/unknown column in UPDATE: nonexistent/;
};

subtest 'UPDATE: ハッシュリファレンス以外を渡すと die する' => sub {
    my $hq = HashQuery->new(\@base);
    eval { $hq->UPDATE('invalid') };
    like $@, qr/UPDATE requires a hash reference/;
};
```

- [ ] **Step 2: テストが失敗することを確認する**

```bash
cd /Users/darong/PRJDEV/HashQuery && perl -Ilib -Isrc test/hashquery.t 2>&1 | grep "not ok" | head -5
```

期待: UPDATE 関連テストが失敗

- [ ] **Step 3: `sub UPDATE` メソッドを実装する**

`sub DELETE` の直後に追加:

```perl
sub UPDATE {
    my ($self, $upd_arg, @dsls) = @_;

    die 'UPDATE requires a hash reference'
        unless ref $upd_arg eq 'HASH';

    my %valid    = map { $_ => 1 } @{ $self->{all} };
    my %upd_cols = %$upd_arg;

    for my $col (keys %upd_cols) {
        die "unknown column in UPDATE: $col"
            unless $valid{$col};
    }

    my ($whr, $hvg);
    for my $dsl (@dsls) {
        if    (exists $dsl->{where})  { $whr = $dsl }
        elsif (exists $dsl->{having}) { $hvg = $dsl }
        else  { die 'invalid DSL part' }
    }

    my $tbl = clone($self->{table});
    for my $i (0 .. $#$tbl) { $tbl->[$i]{_idx} = $i; }

    my $matched = [0 .. $#$tbl];
    $matched = _run_where($tbl, $matched, $self->{alias}, $whr) if $whr;
    $matched = _run_having($tbl, $matched, $self->{alias}, $hvg) if $hvg;

    my $result = _run_update($tbl, $matched, { update => \%upd_cols }, $self->{all});

    if ($self->{alias}) {
        ${ $self->{alias} } = {
            count  => scalar @$result,
            affect => scalar @$matched,
        };
    }

    return $result;
}
```

- [ ] **Step 4: テストが通ることを確認する**

```bash
cd /Users/darong/PRJDEV/HashQuery && perl -Ilib -Isrc test/hashquery.t 2>&1 | tail -5
```

期待: `1..42`、全パス

- [ ] **Step 5: コミット**

```bash
cd /Users/darong/PRJDEV/HashQuery && git add . && git commit -m "feat(oop): UPDATE メソッドを実装する"
```

---

### Task 6: 条件メソッド・集計関数・grep_concat テスト追加

**Files:**
- Modify: `test/hashquery.t`（Value メソッド・having 集計・grep_concat・実用例テスト追加）

- [ ] **Step 1: 条件メソッドのテストを書く**

`test/hashquery.t` の `done_testing;` 直前に追加:

```perl
# ===========================================================================
# 条件メソッド（HashQuery::Value）
# ===========================================================================

subtest 'like: パターンマッチする' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', where { $_->{a}->like('a%') });
    is scalar @$r, 1;
    is $r->[0]{a}, 'alice';
};

subtest 'like: % で複数文字にマッチする' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', where { $_->{a}->like('%e') });
    my @names = sort map { $_->{a} } @$r;
    is_deeply \@names, [qw/alice dave eve/];
};

subtest 'not_like: パターンに一致しない行を返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', where { $_->{a}->not_like('a%') });
    is scalar @$r, 4;
    ok !grep { $_->{a} eq 'alice' } @$r;
};

subtest 'between: 範囲内の行を返す（両端含む）' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', where { $_->{b}->between(10, 20) });
    is scalar @$r, 4;
};

subtest 'between: 排他境界で範囲を絞れる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', where { $_->{b}->between('10!', '20!') });
    is scalar @$r, 0;
};

subtest 'in: リストに含まれる行を返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', where { $_->{b}->in(10, 30) });
    my @names = sort map { $_->{a} } @$r;
    is_deeply \@names, [qw/alice carol dave/];
};

subtest 'not_in: リストに含まれない行を返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', where { $_->{b}->not_in(10, 30) });
    my @names = sort map { $_->{a} } @$r;
    is_deeply \@names, [qw/bob eve/];
};

subtest 'asNull: undef を デフォルト値に置き換える' => sub {
    my $hq = HashQuery->new(\@null_tbl);
    my $r = $hq->SELECT('*', where { $_->{val}->asNull(0) != 0 });
    is scalar @$r, 1;
    is $r->[0]{name}, 'y';
};

# ===========================================================================
# having 集計関数
# ===========================================================================

subtest 'count_by: グループ内の行数を返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', having { count_by('b') == 2 });
    is scalar @$r, 4;
    ok !grep { $_->{a} eq 'carol' } @$r;
};

subtest 'max_by: グループ内の最大値を返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', having { max_by('c', 'b') == 250 });
    my @names = sort map { $_->{a} } @$r;
    is_deeply \@names, [qw/bob eve/];
};

subtest 'min_by: グループ内の最小値を返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', having { min_by('c', 'b') == 100 });
    my @names = sort map { $_->{a} } @$r;
    is_deeply \@names, [qw/alice dave/];
};

subtest 'first_by: グループ内の先頭行を返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', having { first_by('b') });
    my @names = sort map { $_->{a} } @$r;
    is_deeply \@names, [qw/alice bob carol/];
};

subtest 'last_by: グループ内の末尾行を返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', having { last_by('b') });
    my @names = sort map { $_->{a} } @$r;
    is_deeply \@names, [qw/bob carol dave/];

    # carol: b=30（グループ内唯一、first_by かつ last_by）
    # bob/eve: b=20、dave: b=10
};

# ===========================================================================
# grep_concat
# ===========================================================================

subtest 'grep_concat: マッチした行の値を返す' => sub {
    my $hq = HashQuery->new(\@log_tbl);
    my $r = $hq->SELECT('*', where { grep_concat('msg', qr/ERROR/) ne '' });
    is scalar @$r, 2;
    ok !grep { $_->{msg} !~ /ERROR/ } @$r;
};

subtest 'grep_concat: 前後行を含めて返す' => sub {
    my $hq = HashQuery->new(\@log_tbl);
    my $r = $hq->SELECT('*', where { grep_concat('msg', qr/ERROR/, -1, 1) ne '' });
    is scalar @$r, 4;
};

subtest 'grep_concat: 指定カラムの値のみ連結する' => sub {
    my $hq = HashQuery->new(\@log_tbl);
    my $r = $hq->SELECT('*', where {
        my $ctx = grep_concat('msg', qr/ERROR connection/, 0, 1);
        $ctx =~ /ERROR connection failed/ && $ctx =~ /retrying/;
    });
    is scalar @$r, 1;
    is $r->[0]{line}, 2;
};

# ===========================================================================
# 実用例
# ===========================================================================

subtest '実用: as を使って where でフィルタする' => sub {
    our $m1;
    my $hq = HashQuery->new(\@members, as $m1);
    my $r = $hq->SELECT([qw/team name/], where { $m1->{role} eq 'lead' });
    is scalar @$r, 3;
    ok !grep { $_->{role} } @$r;   # 出力列に role は含まれない
};

subtest '実用: スコア75以上かつチームに2人以上いるメンバーを取得' => sub {
    our $m2;
    my $hq = HashQuery->new(\@members, as $m2);
    my $r = $hq->SELECT(
        [qw/team name score/],
        where  { $m2->{score} >= 75 },
        having { count_by('team') >= 2 },
    );
    is scalar @$r, 3;
    is_deeply [sort map { $_->{name} } @$r], [qw/alice bob carol/];
};
```

- [ ] **Step 2: テストが全て通ることを確認する**

```bash
cd /Users/darong/PRJDEV/HashQuery && perl -Ilib -Isrc test/hashquery.t 2>&1 | tail -5
```

期待: `1..62`（概算）、全パス

- [ ] **Step 3: コミット**

```bash
cd /Users/darong/PRJDEV/HashQuery && git add . && git commit -m "test(oop): 条件メソッド・集計関数・grep_concat・実用例テストを追加する"
```

---

### Task 7: 旧 API 削除・ドキュメント更新

**Files:**
- Modify: `src/HashQuery.pm`（旧 `query`/`SELECT`/`DELETE`/`UPDATE` 関数を削除）
- Modify: `docs/spec.md`
- Modify: `docs/test-spec.md`
- Modify: `README.md`
- Modify: `README.ja.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: 旧 API 関数を削除する**

`src/HashQuery.pm` から以下を削除する:
- `sub query ($@) { ... }` — 全体を削除
- `sub SELECT (;$) { ... }` — 全体を削除
- `sub DELETE () { ... }` — 全体を削除
- `sub UPDATE ($) { ... }` — 全体を削除

- [ ] **Step 2: テストが全て通ることを確認する**

```bash
cd /Users/darong/PRJDEV/HashQuery && perl -Ilib -Isrc test/hashquery.t 2>&1 | tail -5
```

期待: 全パス（件数変わらず）

- [ ] **Step 3: `docs/spec.md` を更新する**

`docs/spec.md` を OOP 設計書の内容に合わせて全面更新する。変更点:
- セクション 0: `SELECT`/`DELETE`/`UPDATE` をメソッドに記載。`query` 廃止を明記
- セクション 1（提供関数一覧）: `query`/`SELECT`/`DELETE`/`UPDATE` を削除し `except`/`set` を追加
- セクション 2（DSL 構文）: `HashQuery->new`・各メソッドの構文に更新
- セクション 3（各関数リファレンス）: `query` を削除し `new`・`SELECT`・`DELETE`・`UPDATE` メソッドリファレンスに置き換え
- セクション 7（実行モデル）: OOP 方式に更新
- セクション 8（制約）: OOP 方式に更新

- [ ] **Step 4: `docs/test-spec.md` を更新する**

テストケース一覧を新 API 向けに全面更新する。

- [ ] **Step 5: `README.md` / `README.ja.md` を更新する**

使用例・機能テーブルを OOP API に更新する。

- [ ] **Step 6: `CHANGELOG.md` を更新する**

`[未リリース]` セクションに追記:
```markdown
### 変更（破壊的変更）
- HashQuery を OOP API に完全再設計。後方互換性なし
- `query` 関数を廃止。`HashQuery->new(\@table)` でインスタンスを生成する
- `SELECT`/`DELETE`/`UPDATE` を関数からインスタンスメソッドに変更
- `except`/`set` ヘルパー関数を追加
- `as` 関数の戻り値を `{ alias => \$var }` から `{ as => \$var }` に変更
```

- [ ] **Step 7: テストが全て通ることを最終確認する**

```bash
cd /Users/darong/PRJDEV/HashQuery && perl -Ilib -Isrc test/hashquery.t 2>&1 | tail -3
```

期待: 全パス

- [ ] **Step 8: コミット**

```bash
cd /Users/darong/PRJDEV/HashQuery && git add . && git commit -m "feat(oop): 旧 API を削除しドキュメントを OOP 設計に更新する"
```
