use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../src";

use HashQuery;

sub data_rows {
    my ($aoh) = @_;
    return [ grep { !exists $_->{'#'} } @$aoh ];
}

sub meta_row {
    my ($aoh) = @_;
    return undef unless @$aoh;
    return $aoh->[0]{'#'} ? $aoh->[0] : undef;
}

sub assert_result_meta {
    my ($aoh, $expected_count, $expected_attrs, $expected_order) = @_;

    my $meta_row = meta_row($aoh);
    ok defined $meta_row, 'メタ行がある';
    ok exists $meta_row->{'#'}{attrs}, 'attrs がある';
    ok exists $meta_row->{'#'}{count}, 'count がある';
    is $meta_row->{'#'}{count}, $expected_count, 'count が正しい';

    if ($expected_attrs) {
        is_deeply $meta_row->{'#'}{attrs}, $expected_attrs, 'attrs が正しい';
    }

    if ($expected_order) {
        is_deeply $meta_row->{'#'}{order}, $expected_order, 'order が正しい';
    }

    return $meta_row->{'#'};
}

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

my $base_attrs    = { a => 'str', b => 'num', c => 'num' };
my $base_ab_attrs = { a => 'str', b => 'num' };
my $base_a_attrs  = { a => 'str' };
my $team_name_score_attrs = { team => 'str', name => 'str', score => 'num' };
my $team_name_attrs       = { team => 'str', name => 'str' };
my $log_attrs   = { line => 'num', msg => 'str' };
my $null_attrs  = { name => 'str', val => 'num' };
my $member_attrs = { team => 'str', name => 'str', role => 'str', score => 'num' };

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

subtest 'except: 引数なしで die する' => sub {
    eval { except() };
    like $@, qr/except requires at least one column name/;
};

subtest 'set: ハッシュリファレンスを返す' => sub {
    my $node = set(score => 99, grade => 'A');
    is_deeply $node, { score => 99, grade => 'A' };
};

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
    like $@, qr/column|unexpected column|count mismatch/;
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

# ===========================================================================
# SELECT メソッド
# ===========================================================================

subtest 'SELECT: * で全列・全行を返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*');
    my $rows = data_rows($r);
    assert_result_meta($r, 5, $base_attrs);
    is scalar @$rows, 5;
    ok exists $rows->[0]{a};
    ok exists $rows->[0]{b};
    ok exists $rows->[0]{c};
};

subtest 'SELECT: 配列リファレンスで列を指定できる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT([qw/a b/]);
    my $rows = data_rows($r);
    assert_result_meta($r, 5, $base_ab_attrs, [qw/a b/]);
    is scalar @$rows, 5;
    ok  exists $rows->[0]{a};
    ok  exists $rows->[0]{b};
    ok !exists $rows->[0]{c};
};

subtest 'SELECT: except で列を除外できる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT(except('c'));
    my $rows = data_rows($r);
    assert_result_meta($r, 5, $base_ab_attrs, [qw/a b/]);
    is scalar @$rows, 5;
    ok  exists $rows->[0]{a};
    ok  exists $rows->[0]{b};
    ok !exists $rows->[0]{c};
};

subtest 'SELECT: except で複数列を除外できる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT(except('b', 'c'));
    my $rows = data_rows($r);
    assert_result_meta($r, 5, $base_a_attrs, ['a']);
    ok  exists $rows->[0]{a};
    ok !exists $rows->[0]{b};
    ok !exists $rows->[0]{c};
};

subtest 'SELECT: _idx は出力に含まれない' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*');
    my $rows = data_rows($r);
    ok !exists $rows->[0]{_idx};
};

subtest 'SELECT: undef を渡すと die する' => sub {
    my $hq = HashQuery->new(\@base);
    eval { $hq->SELECT(undef) };
    like $@, qr/SELECT requires/;
};

subtest 'SELECT: where で行をフィルタできる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', where { $_->{b} == 10 });
    my $rows = data_rows($r);
    assert_result_meta($r, 2, $base_attrs);
    is scalar @$rows, 2;
    my @names = sort map { $_->{a} } @$rows;
    is_deeply \@names, [qw/alice dave/];
};

subtest 'SELECT: having で集約フィルタできる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', having { count_by('b') > 1 });
    my $rows = data_rows($r);
    assert_result_meta($r, 4, $base_attrs);
    is scalar @$rows, 4;
    ok !grep { $_->{a} eq 'carol' } @$rows;
};

subtest 'SELECT: where と having を組み合わせられる' => sub {
    my $hq = HashQuery->new(\@members);
    my $r = $hq->SELECT(
        [qw/team name score/],
        where  { $_->{score} >= 75 },
        having { count_by('team') >= 2 },
    );
    my $rows = data_rows($r);
    assert_result_meta($r, 3, $team_name_score_attrs, [qw/team name score/]);
    is scalar @$rows, 3;
    ok !grep { $_->{team} ne 'alpha' } @$rows;
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
    is scalar @{ data_rows($r1) }, 2;
    is scalar @{ data_rows($r2) }, 2;
};

subtest 'SELECT: 元テーブルは変更されない' => sub {
    my @orig = ({ a => 1, b => 2 }, { a => 3, b => 4 });
    my @copy = map { +{ %$_ } } @orig;
    my $hq = HashQuery->new(\@orig);
    $hq->SELECT('*');
    is_deeply \@orig, \@copy;
};

subtest 'SELECT: as - 結果が 0 件でも alias は hashref を返す' => sub {
    our $s_zero;
    my $hq = HashQuery->new(\@base, as $s_zero);
    $hq->SELECT('*', where { $_->{b} > 9999 });
    is ref($s_zero), 'HASH';
    is $s_zero->{count}, 0;
    is $s_zero->{affect}, 0;
};

# ===========================================================================
# DELETE メソッド
# ===========================================================================

subtest 'DELETE: where にマッチした行を削除して残りを返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->DELETE(where { $_->{b} == 10 });
    my $rows = data_rows($r);
    assert_result_meta($r, 3, $base_attrs);
    is scalar @$rows, 3;
    my @names = sort map { $_->{a} } @$rows;
    is_deeply \@names, [qw/bob carol eve/];
};

subtest 'DELETE: 条件なしで全行を返す（何も削除しない）' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->DELETE();
    assert_result_meta($r, 5, $base_attrs);
    is scalar @{ data_rows($r) }, 5;
};

subtest 'DELETE: 一致なしで全行残る' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->DELETE(where { $_->{b} > 999 });
    assert_result_meta($r, 5, $base_attrs);
    is scalar @{ data_rows($r) }, 5;
};

subtest 'DELETE: having と組み合わせて削除できる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->DELETE(having { count_by('b') > 1 });
    my $rows = data_rows($r);
    assert_result_meta($r, 1, $base_attrs);
    is scalar @$rows, 1;
    is $rows->[0]{a}, 'carol';
};

subtest 'DELETE: _idx は出力に含まれない' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->DELETE(where { $_->{b} > 999 });
    my $rows = data_rows($r);
    ok !exists $rows->[0]{_idx};
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
    is scalar @{ data_rows($selected) } + scalar @{ data_rows($deleted) }, 5;
};

subtest 'DELETE: as - 全件削除で結果 0 件でも alias は hashref を返す' => sub {
    our $d_zero;
    my $hq = HashQuery->new(\@base, as $d_zero);
    $hq->DELETE(where { $_->{b} >= 0 });
    is ref($d_zero), 'HASH';
    is $d_zero->{count}, 0;
    is $d_zero->{affect}, 5;
};

# ===========================================================================
# UPDATE メソッド
# ===========================================================================

subtest 'UPDATE: where にマッチした行を更新して全行返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->UPDATE({ b => 99 }, where { $_->{b} == 10 });
    my $rows = data_rows($r);
    assert_result_meta($r, 5, $base_attrs);
    is scalar @$rows, 5;
    my @updated = grep { $_->{b} == 99 } @$rows;
    my @names   = sort map { $_->{a} } @updated;
    is_deeply \@names, [qw/alice dave/];
};

subtest 'UPDATE: set 関数形式でも更新できる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->UPDATE(set(b => 99), where { $_->{b} == 10 });
    my $rows = data_rows($r);
    assert_result_meta($r, 5, $base_attrs);
    is scalar @$rows, 5;
    my @updated = grep { $_->{b} == 99 } @$rows;
    is scalar @updated, 2;
};

subtest 'UPDATE: 条件なしで全行更新する' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->UPDATE({ b => 0 });
    my $rows = data_rows($r);
    assert_result_meta($r, 5, $base_attrs);
    is scalar @$rows, 5;
    my @vals = map { $_->{b} } @$rows;
    is_deeply \@vals, [0, 0, 0, 0, 0];
};

subtest 'UPDATE: 一致なしで全行そのまま返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->UPDATE({ b => 0 }, where { $_->{b} > 999 });
    my $rows = data_rows($r);
    assert_result_meta($r, 5, $base_attrs);
    is scalar @$rows, 5;
    my @vals = map { $_->{b} } @$rows;
    is_deeply \@vals, [10, 20, 30, 10, 20];
};

subtest 'UPDATE: having と組み合わせて更新できる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->UPDATE({ b => 0 }, having { count_by('b') > 1 });
    my $rows = data_rows($r);
    assert_result_meta($r, 5, $base_attrs);
    my @zeroed = grep { $_->{b} == 0 } @$rows;
    is scalar @zeroed, 4;
    my @intact = grep { $_->{b} != 0 } @$rows;
    is $intact[0]{a}, 'carol';
};

subtest 'UPDATE: 複数カラムを同時に更新できる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->UPDATE({ b => 0, c => 0 }, where { $_->{a} eq 'alice' });
    assert_result_meta($r, 5, $base_attrs);
    my ($alice) = grep { $_->{a} eq 'alice' } @{ data_rows($r) };
    is $alice->{b}, 0;
    is $alice->{c}, 0;
};

subtest 'UPDATE: _idx は出力に含まれない' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->UPDATE({ b => 0 });
    my $rows = data_rows($r);
    ok !exists $rows->[0]{_idx};
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

# ===========================================================================
# 条件メソッド（HashQuery::Value）
# ===========================================================================

subtest 'like: パターンマッチする' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', where { $_->{a}->like('a%') });
    my $rows = data_rows($r);
    assert_result_meta($r, 1, $base_attrs);
    is scalar @$rows, 1;
    is $rows->[0]{a}, 'alice';
};

subtest 'like: % で複数文字にマッチする' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', where { $_->{a}->like('%e') });
    assert_result_meta($r, 3, $base_attrs);
    my @names = sort map { $_->{a} } @{ data_rows($r) };
    is_deeply \@names, [qw/alice dave eve/];
};

subtest 'not_like: パターンに一致しない行を返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', where { $_->{a}->not_like('a%') });
    my $rows = data_rows($r);
    assert_result_meta($r, 4, $base_attrs);
    is scalar @$rows, 4;
    ok !grep { $_->{a} eq 'alice' } @$rows;
};

subtest 'between: 範囲内の行を返す（両端含む）' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', where { $_->{b}->between(10, 20) });
    assert_result_meta($r, 4, $base_attrs);
    is scalar @{ data_rows($r) }, 4;
};

subtest 'between: 排他境界で範囲を絞れる' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', where { $_->{b}->between('10!', '20!') });
    is scalar @{ data_rows($r) }, 0;
};

subtest 'in: リストに含まれる行を返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', where { $_->{b}->in(10, 30) });
    assert_result_meta($r, 3, $base_attrs);
    my @names = sort map { $_->{a} } @{ data_rows($r) };
    is_deeply \@names, [qw/alice carol dave/];
};

subtest 'not_in: リストに含まれない行を返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', where { $_->{b}->not_in(10, 30) });
    assert_result_meta($r, 2, $base_attrs);
    my @names = sort map { $_->{a} } @{ data_rows($r) };
    is_deeply \@names, [qw/bob eve/];
};

subtest 'asNull: undef を デフォルト値に置き換える' => sub {
    my $hq = HashQuery->new(\@null_tbl);
    my $r = $hq->SELECT('*', where { $_->{val}->asNull(0) != 0 });
    my $rows = data_rows($r);
    assert_result_meta($r, 1, $null_attrs);
    is scalar @$rows, 1;
    is $rows->[0]{name}, 'y';
};

# ===========================================================================
# having 集計関数
# ===========================================================================

subtest 'count_by: グループ内の行数を返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', having { count_by('b') == 2 });
    my $rows = data_rows($r);
    assert_result_meta($r, 4, $base_attrs);
    is scalar @$rows, 4;
    ok !grep { $_->{a} eq 'carol' } @$rows;
};

subtest 'max_by: グループ内の最大値を返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', having { max_by('c', 'b') == 250 });
    assert_result_meta($r, 2, $base_attrs);
    my @names = sort map { $_->{a} } @{ data_rows($r) };
    is_deeply \@names, [qw/bob eve/];
};

subtest 'min_by: グループ内の最小値を返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', having { min_by('c', 'b') == 100 });
    assert_result_meta($r, 2, $base_attrs);
    my @names = sort map { $_->{a} } @{ data_rows($r) };
    is_deeply \@names, [qw/alice dave/];
};

subtest 'first_by: グループ内の先頭行を返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', having { first_by('b') });
    assert_result_meta($r, 3, $base_attrs);
    my @names = sort map { $_->{a} } @{ data_rows($r) };
    is_deeply \@names, [qw/alice bob carol/];
};

subtest 'last_by: グループ内の末尾行を返す' => sub {
    my $hq = HashQuery->new(\@base);
    my $r = $hq->SELECT('*', having { last_by('b') });
    assert_result_meta($r, 3, $base_attrs);
    my @names = sort map { $_->{a} } @{ data_rows($r) };
    is_deeply \@names, [qw/carol dave eve/];
    # carol: b=30（グループ内唯一）、dave: b=10の末尾、eve: b=20の末尾
};

# ===========================================================================
# grep_concat
# ===========================================================================

subtest 'grep_concat: マッチした行の値を返す' => sub {
    my $hq = HashQuery->new(\@log_tbl);
    my $r = $hq->SELECT('*', where { grep_concat('msg', qr/ERROR/) ne '' });
    my $rows = data_rows($r);
    assert_result_meta($r, 2, $log_attrs);
    is scalar @$rows, 2;
    ok !grep { $_->{msg} !~ /ERROR/ } @$rows;
};

subtest 'grep_concat: 前後行の値を連結した文字列を返す' => sub {
    my $hq = HashQuery->new(\@log_tbl);
    my $r = $hq->SELECT('*', where { grep_concat('msg', qr/ERROR/, -1, 1) ne '' });
    # grep_concat は現在行がマッチした場合のみ非空文字列を返す（ERROR行のみ選択）
    my $rows = data_rows($r);
    assert_result_meta($r, 2, $log_attrs);
    is scalar @$rows, 2;
    ok !grep { $_->{msg} !~ /ERROR/ } @$rows;
};

subtest 'grep_concat: 指定カラムの値のみ連結する' => sub {
    my $hq = HashQuery->new(\@log_tbl);
    my $r = $hq->SELECT('*', where {
        my $ctx = grep_concat('msg', qr/ERROR connection/, 0, 1);
        $ctx =~ /ERROR connection failed/ && $ctx =~ /retrying/;
    });
    my $rows = data_rows($r);
    assert_result_meta($r, 1, $log_attrs);
    is scalar @$rows, 1;
    is $rows->[0]{line}, 2;
};

# ===========================================================================
# 実用例
# ===========================================================================

subtest '実用: as を使って where でフィルタする' => sub {
    our $m1;
    my $hq = HashQuery->new(\@members, as $m1);
    my $r = $hq->SELECT([qw/team name/], where { $m1->{role} eq 'lead' });
    my $rows = data_rows($r);
    assert_result_meta($r, 3, $team_name_attrs, [qw/team name/]);
    is scalar @$rows, 3;
    ok !grep { $_->{role} } @$rows;   # 出力列に role は含まれない
};

subtest '実用: スコア75以上かつチームに2人以上いるメンバーを取得' => sub {
    our $m2;
    my $hq = HashQuery->new(\@members, as $m2);
    my $r = $hq->SELECT(
        [qw/team name score/],
        where  { $m2->{score} >= 75 },
        having { count_by('team') >= 2 },
    );
    my $rows = data_rows($r);
    assert_result_meta($r, 3, $team_name_score_attrs, [qw/team name score/]);
    is scalar @$rows, 3;
    is_deeply [sort map { $_->{name} } @$rows], [qw/alice bob carol/];
};

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
    my @rows = grep { !exists $_->{'#'} } @$r;
    is scalar @rows, 3;
    ok  exists $rows[0]{a};
};

subtest 'new: rows が空でメタに order がある場合、列を復元できる' => sub {
    my $hq = HashQuery->new(\@meta_empty_with_order);
    isa_ok $hq, 'HashQuery';
    my $r = $hq->SELECT('*');
    is_deeply $r, [], '結果 rows が 0 件なら [] を返す';
};

subtest 'new: rows が空でメタに attrs のみある場合、列を辞書順で復元できる' => sub {
    my $hq = HashQuery->new(\@meta_empty_attrs_only);
    isa_ok $hq, 'HashQuery';
    my $r = $hq->SELECT('*');
    is_deeply $r, [], '結果 rows が 0 件なら [] を返す';
};

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

subtest 'SELECT: メタ付き入力で列順を入れ替えると order が返却列順に一致する' => sub {
    my $hq = HashQuery->new(\@meta_base);
    my $r  = $hq->SELECT([qw/b a/]);
    my $m  = $r->[0]{'#'};
    ok defined $m, 'メタが付いている';
    is_deeply $m->{order}, [qw/b a/], 'order が返却列順 [b, a] と一致する';
    is_deeply $m->{attrs}, { b => 'num', a => 'str' };
    ok !exists $m->{attrs}{c}, 'c は attrs に含まれない';
};

subtest 'SELECT: メタ付き入力で except を使うと attrs/order が射影される' => sub {
    my $hq = HashQuery->new(\@meta_base);
    my $r  = $hq->SELECT(except('c'));
    my $m  = $r->[0]{'#'};
    ok defined $m, 'メタが付いている';
    is_deeply $m->{order}, [qw/a b/];
    is_deeply $m->{attrs}, { a => 'str', b => 'num' };
    ok !exists $m->{attrs}{c}, 'c は attrs に含まれない';
};

subtest 'SELECT: プレーン入力も meta 付き AoH で返る' => sub {
    my $hq = HashQuery->new(\@base);
    my $r  = $hq->SELECT('*');
    ok exists $r->[0]{'#'}, 'メタ行がある';
    is scalar @$r, 6;
};

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

subtest 'DELETE: プレーン入力も meta 付き AoH で返る' => sub {
    my $hq = HashQuery->new(\@base);
    my $r  = $hq->DELETE(where { $_->{b} == 10 });
    ok exists $r->[0]{'#'}, 'メタ行がある';
};

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

subtest 'UPDATE: プレーン入力も meta 付き AoH で返る' => sub {
    my $hq = HashQuery->new(\@base);
    my $r  = $hq->UPDATE({ b => 99 }, where { $_->{b} == 10 });
    ok exists $r->[0]{'#'}, 'メタ行がある';
};

done_testing;
