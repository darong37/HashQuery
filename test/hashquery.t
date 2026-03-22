use strict;
use warnings;

use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../src";

use HashQuery;

# --- テストデータ ---

my @table = (
    { a => 'alice', b => 10, c => 100 },
    { a => 'bob',   b => 20, c => 200 },
    { a => 'carol', b => 30, c => 300 },
    { a => 'dave',  b => 10, c => 150 },
    { a => 'eve',   b => 20, c => 250 },
);

# --- query 基本 ---

subtest 'query: DSLなしで全行全列を返す' => sub {
    my $result = query \@table;
    is scalar @$result, 5;
    is_deeply $result->[0], { a => 'alice', b => 10, c => 100 };
};

subtest 'query: 空テーブルを渡すと空配列を返す' => sub {
    my $result = query [];
    is_deeply $result, [];
};

subtest 'query: テーブル以外を渡すとdieする' => sub {
    eval { query {} };
    like $@, qr/Array of Hash/;
};

subtest 'query: 行の構造が不一致だとdieする' => sub {
    eval { query [ { a => 1 }, { a => 1, b => 2 } ] };
    like $@, qr/consistent/;
};

# --- select ---

subtest 'select: 列を明示指定する' => sub {
    my $result = query \@table, select [qw/a b/];
    is scalar @$result, 5;
    is_deeply $result->[0], { a => 'alice', b => 10 };
    ok !exists $result->[0]{c};
};

subtest 'select: except で指定列を除外する' => sub {
    my $result = query \@table, select { except => ['c'] };
    is scalar @$result, 5;
    ok exists $result->[0]{a};
    ok exists $result->[0]{b};
    ok !exists $result->[0]{c};
};

subtest 'select: "*" で全列を返す' => sub {
    my $result = query \@table, select '*';
    is scalar @$result, 5;
    is_deeply [ sort keys %{ $result->[0] } ], [qw/a b c/];
};

subtest 'select: 引数なしで全列を返す' => sub {
    my $result = query \@table, select;
    is scalar @$result, 5;
    is_deeply [ sort keys %{ $result->[0] } ], [qw/a b c/];
};

# --- where ---

subtest 'where: $_ でフィルタする（asなし）' => sub {
    my $result = query \@table, where { $_->{b} == 10 };
    is scalar @$result, 2;
    is $result->[0]{a}, 'alice';
    is $result->[1]{a}, 'dave';
};

subtest 'where: as で alias 変数を使ってフィルタする' => sub {
    our $tbl;
    my $result = query \@table, as $tbl, where { $tbl->{b} >= 20 };
    is scalar @$result, 3;
    is $result->[0]{a}, 'bob';
};

subtest 'where: 条件を満たす行がない場合は空配列' => sub {
    my $result = query \@table, where { $_->{b} > 999 };
    is_deeply $result, [];
};

# --- where: like / not_like ---

subtest 'where: like で前方一致' => sub {
    my $result = query \@table, where { $_->{a}->like('a%') };
    is scalar @$result, 1;
    is $result->[0]{a}, 'alice';
};

subtest 'where: like で後方一致' => sub {
    my $result = query \@table, where { $_->{a}->like('%e') };
    is scalar @$result, 3;
    is $result->[0]{a}, 'alice';
    is $result->[1]{a}, 'dave';
    is $result->[2]{a}, 'eve';
};

subtest 'where: like で _ ワイルドカード' => sub {
    my $result = query \@table, where { $_->{a}->like('b__') };
    is scalar @$result, 1;
    is $result->[0]{a}, 'bob';
};

subtest 'where: not_like' => sub {
    my $result = query \@table, where { $_->{a}->not_like('a%') };
    is scalar @$result, 4;
    ok !grep { $_->{a} eq 'alice' } @$result;
};

# --- where: between ---

subtest 'where: between 通常範囲（境界含む）' => sub {
    my $result = query \@table, where { $_->{b}->between(10, 20) };
    is scalar @$result, 4;
};

subtest 'where: between 排他境界 下限' => sub {
    my $result = query \@table, where { $_->{b}->between('10!', 30) };
    is scalar @$result, 3;
    ok !grep { $_->{b} == 10 } @$result;
};

subtest 'where: between 排他境界 上限' => sub {
    my $result = query \@table, where { $_->{b}->between(10, '20!') };
    is scalar @$result, 2;  # b >= 10 AND b < 20 → alice(b=10), dave(b=10)
    ok !grep { $_->{b} == 20 } @$result;
};

# --- where: in / not_in ---

subtest 'where: in でリスト一致' => sub {
    my $result = query \@table, where { $_->{a}->in(['alice', 'carol']) };
    is scalar @$result, 2;
};

subtest 'where: not_in でリスト除外' => sub {
    my $result = query \@table, where { $_->{a}->not_in(['alice', 'carol']) };
    is scalar @$result, 3;
    ok !grep { $_->{a} eq 'alice' } @$result;
    ok !grep { $_->{a} eq 'carol' } @$result;
};

# --- where: asNull ---

subtest 'where: asNull でundef/空文字をデフォルト値に置換' => sub {
    my @tbl = (
        { a => 'x', b => undef },
        { a => 'y', b => 42    },
        { a => 'z', b => ''    },
    );
    my $result = query \@tbl, select [qw/a b/];
    is $result->[0]{b}, undef;

    my $result2 = query \@tbl, where { $_->{b}->asNull(0) == 0 };
    is scalar @$result2, 2;
};

# --- having: count_by ---

subtest 'having: count_by で重複グループをフィルタ' => sub {
    my $result = query \@table, having { count_by('b') > 1 };
    is scalar @$result, 4;
    ok !grep { $_->{a} eq 'carol' } @$result;
};

# --- having: max_by / min_by ---

subtest 'having: max_by でグループ最大値を条件にする' => sub {
    # b=10グループ max(c)=150, b=20グループ max(c)=250, b=30グループ max(c)=300
    my $result = query \@table, having { max_by('c', 'b') > 200 };
    is scalar @$result, 3;  # b=20(bob,eve), b=30(carol) が通過
    ok !grep { $_->{b} == 10 } @$result;
};

subtest 'having: min_by でグループ最小値を条件にする' => sub {
    # b=10グループ min(c)=100, b=20グループ min(c)=200, b=30グループ min(c)=300
    my $result = query \@table, having { min_by('c', 'b') < 200 };
    is scalar @$result, 2;  # b=10(alice,dave) のみ通過
    ok !grep { $_->{b} == 20 } @$result;
};

# --- having: first_by / last_by ---

subtest 'having: first_by でグループ先頭行のみ残す' => sub {
    my $result = query \@table, having { first_by('b') };
    is scalar @$result, 3;
    is $result->[0]{a}, 'alice';
    is $result->[1]{a}, 'bob';
    is $result->[2]{a}, 'carol';
};

subtest 'having: last_by でグループ末尾行のみ残す' => sub {
    # テーブル順: alice,bob,carol,dave,eve
    # b=10グループ末尾=dave, b=20グループ末尾=eve, b=30グループ末尾=carol
    # having はテーブル順に評価 → carol,dave,eve の順で残る
    my $result = query \@table, having { last_by('b') };
    is scalar @$result, 3;
    is $result->[0]{a}, 'carol';
    is $result->[1]{a}, 'dave';
    is $result->[2]{a}, 'eve';
};

# --- having: 集計関数はhaving外でdieする ---

subtest 'having: count_by を having 外で呼ぶとdieする' => sub {
    eval { count_by(qw/a/) };
    like $@, qr/having/;
};

# --- 組み合わせ ---

subtest '組み合わせ: where + having + select' => sub {
    # where(b<=20): alice,bob,dave,eve(4行) → having対象は4行
    # count_by('b'): b=10→2件, b=20→2件 → 全4行が>1を満たす
    our $tbl2;
    my $result = query
        \@table,
        as $tbl2,
        select [qw/a b/],
        where  { $tbl2->{b} <= 20 },
        having { count_by('b') > 1 };

    is scalar @$result, 4;
    ok !exists $result->[0]{c};

    my @names = sort map { $_->{a} } @$result;
    is_deeply \@names, [qw/alice bob dave eve/];
};

subtest '組み合わせ: where + select（except）' => sub {
    my $result = query
        \@table,
        select { except => ['b'] },
        where  { $_->{b} == 10 };

    is scalar @$result, 2;
    ok exists $result->[0]{a};
    ok exists $result->[0]{c};
    ok !exists $result->[0]{b};
};

subtest '組み合わせ: スペック記載のフルサンプル' => sub {
    # where(a gt 'abc' AND b in [10,20]): alice,bob,dave,eve(4行) → having対象は4行
    # having: b>=10(全4行) AND count_by('b')>1(b=10→2,b=20→2) AND max_by('c','b')>100(b=10→150,b=20→250)
    # → 全4行通過
    our $tbl3;
    my $result = query
        \@table,
        as $tbl3,
        select { except => ['c'] },
        where {
            $tbl3->{a} gt 'abc'
            and $tbl3->{b} >= 10
            and $tbl3->{b} <= 20
        },
        having {
            $tbl3->{b} >= 10
            and count_by('b') > 1
            and max_by('c', 'b') > 100
        };

    my @names = sort map { $_->{a} } @$result;
    is_deeply \@names, [qw/alice bob dave eve/];
    ok !exists $result->[0]{c};
};

done_testing;
