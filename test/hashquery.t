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

done_testing;
