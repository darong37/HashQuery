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
    { line => 1, msg => 'INFO  start'              },
    { line => 2, msg => 'ERROR connection failed'  },
    { line => 3, msg => 'INFO  retrying'           },
    { line => 4, msg => 'ERROR timeout'            },
    { line => 5, msg => 'INFO  done'               },
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
);

# ===========================================================================
# 1. query — 基本動作
# ===========================================================================

subtest 'query: DSLなしで全行を返す' => sub {
    my $r = query \@base;
    is scalar @$r, 5;
};

subtest 'query: DSLなしで全列を返す' => sub {
    my $r = query \@base;
    is_deeply [sort keys %{$r->[0]}], [qw/a b c/];
};

subtest 'query: 空テーブルを渡すと空配列を返す' => sub {
    is_deeply query([]), [];
};

subtest 'query: 戻り値は AOH（配列リファレンス）' => sub {
    my $r = query \@base;
    ok ref $r eq 'ARRAY';
    ok ref $r->[0] eq 'HASH';
};

subtest 'query: 配列リファレンス以外を渡すとdieする' => sub {
    eval { query {} };
    like $@, qr/Array of Hash/;
};

subtest 'query: 行のカラム構成が不一致だとdieする' => sub {
    eval { query [{ a => 1 }, { a => 1, b => 2 }] };
    like $@, qr/consistent/;
};

subtest 'query: 無効なDSL部品を渡すとdieする' => sub {
    eval { query \@base, { unknown_key => 1 } };
    like $@, qr/invalid DSL/;
};

subtest 'query: 入力テーブルは変更されない（不変性）' => sub {
    my @orig = ({ a => 1, b => 2 }, { a => 3, b => 4 });
    my @copy = map { +{ %$_ } } @orig;
    query \@orig, where { $_->{a} > 1 };
    is_deeply \@orig, \@copy;
};

# ===========================================================================
# 2. select
# ===========================================================================

subtest 'select: カラム明示指定で指定列のみ返す' => sub {
    my $r = query \@base, SELECT [qw/a b/];
    is_deeply [sort keys %{$r->[0]}], [qw/a b/];
    ok !exists $r->[0]{c};
};

subtest 'select: 行数は変わらない' => sub {
    my $r = query \@base, SELECT [qw/a/];
    is scalar @$r, 5;
};

subtest 'select: except で指定カラムを除外する' => sub {
    my $r = query \@base, SELECT { except => ['c'] };
    ok  exists $r->[0]{a};
    ok  exists $r->[0]{b};
    ok !exists $r->[0]{c};
};

subtest 'select: except で複数カラムを除外する' => sub {
    my $r = query \@base, SELECT { except => [qw/b c/] };
    is_deeply [sort keys %{$r->[0]}], [qw/a/];
};

subtest 'select: "*" で全列を返す' => sub {
    my $r = query \@base, SELECT '*';
    is_deeply [sort keys %{$r->[0]}], [qw/a b c/];
};

subtest 'select: 引数なしで全列を返す' => sub {
    my $r = query \@base, SELECT;
    is_deeply [sort keys %{$r->[0]}], [qw/a b c/];
};

subtest 'select: _idx は出力に含まれない' => sub {
    my $r = query \@base, SELECT '*';
    ok !exists $r->[0]{_idx};
};

subtest 'select: _idx は明示指定しても出力に含まれない' => sub {
    my $r = query \@base, SELECT [qw/a b c/];
    ok !exists $r->[0]{_idx};
};

# ===========================================================================
# 3. where — 基本フィルタ
# ===========================================================================

subtest 'where: $_ でフィルタする（asなし）' => sub {
    my $r = query \@base, where { $_->{b} == 10 };
    is scalar @$r, 2;
    is $r->[0]{a}, 'alice';
    is $r->[1]{a}, 'dave';
};

subtest 'where: as で alias 変数を使ってフィルタする' => sub {
    our $t1;
    my $r = query \@base, as $t1, where { $t1->{b} >= 20 };
    is scalar @$r, 3;
    is $r->[0]{a}, 'bob';
};

subtest 'where: as を指定しても $_ で参照できる' => sub {
    our $t2;
    my $r = query \@base, as $t2, where { $_->{b} == 30 };
    is scalar @$r, 1;
    is $r->[0]{a}, 'carol';
};

subtest 'where: 全行一致した場合は全行返す' => sub {
    my $r = query \@base, where { $_->{b} > 0 };
    is scalar @$r, 5;
};

subtest 'where: 条件を満たす行がない場合は空配列' => sub {
    is_deeply query(\@base, where { $_->{b} > 999 }), [];
};

subtest 'where: _idx で行番号を使ってフィルタできる' => sub {
    my $r = query \@base, where { $_->{_idx} == 2 };
    is scalar @$r, 1;
    is $r->[0]{a}, 'carol';
};

# ===========================================================================
# 4. where — like / not_like
# ===========================================================================

subtest 'where: like 前方一致' => sub {
    my $r = query \@base, where { $_->{a}->like('a%') };
    is scalar @$r, 1;
    is $r->[0]{a}, 'alice';
};

subtest 'where: like 後方一致' => sub {
    my $r = query \@base, where { $_->{a}->like('%e') };
    is_deeply [map { $_->{a} } @$r], [qw/alice dave eve/];
};

subtest 'where: like 中間一致' => sub {
    my $r = query \@base, where { $_->{a}->like('%li%') };
    is scalar @$r, 1;
    is $r->[0]{a}, 'alice';
};

subtest 'where: like _ ワイルドカード（1文字）' => sub {
    my $r = query \@base, where { $_->{a}->like('b__') };
    is scalar @$r, 1;
    is $r->[0]{a}, 'bob';
};

subtest 'where: like 完全一致' => sub {
    my $r = query \@base, where { $_->{a}->like('carol') };
    is scalar @$r, 1;
};

subtest 'where: like undefはfalseを返す' => sub {
    my $r = query \@null_tbl, where { $_->{val}->like('%') };
    is scalar @$r, 2;  # val=42 and val='' match '%'; val=undef does not
    ok !grep { $_->{name} eq 'x' } @$r;
};

subtest 'where: not_like 否定条件' => sub {
    my $r = query \@base, where { $_->{a}->not_like('a%') };
    is scalar @$r, 4;
    ok !grep { $_->{a} eq 'alice' } @$r;
};

subtest 'where: not_like undefはtrueを返す' => sub {
    my $r = query \@null_tbl, where { $_->{val}->not_like('%') };
    is scalar @$r, 1;
    is $r->[0]{name}, 'x';
};

# ===========================================================================
# 5. where — between
# ===========================================================================

subtest 'where: between 境界値を含む（通常範囲）' => sub {
    my $r = query \@base, where { $_->{b}->between(10, 20) };
    is scalar @$r, 4;
};

subtest 'where: between 境界値ちょうどで一致する（下限）' => sub {
    my $r = query \@base, where { $_->{b}->between(10, 10) };
    is scalar @$r, 2;
    ok !grep { $_->{b} != 10 } @$r;
};

subtest 'where: between 下限排他（! 付き）' => sub {
    my $r = query \@base, where { $_->{b}->between('10!', 30) };
    is scalar @$r, 3;
    ok !grep { $_->{b} == 10 } @$r;
};

subtest 'where: between 上限排他（! 付き）' => sub {
    my $r = query \@base, where { $_->{b}->between(10, '20!') };
    is scalar @$r, 2;
    ok !grep { $_->{b} >= 20 } @$r;
};

subtest 'where: between 両端排他' => sub {
    my $r = query \@base, where { $_->{b}->between('10!', '30!') };
    is scalar @$r, 2;
    is $r->[0]{a}, 'bob';
    is $r->[1]{a}, 'eve';
};

subtest 'where: between undefはfalseを返す' => sub {
    my $r = query \@null_tbl, where { $_->{val}->between(0, 100) };
    is scalar @$r, 1;
    is $r->[0]{name}, 'y';
};

# ===========================================================================
# 6. where — in / not_in
# ===========================================================================

subtest 'where: in 配列リファレンスで一致' => sub {
    my $r = query \@base, where { $_->{a}->in(['alice', 'carol']) };
    is scalar @$r, 2;
};

subtest 'where: in フラットリストでも一致する' => sub {
    my $r = query \@base, where { $_->{a}->in('alice', 'carol') };
    is scalar @$r, 2;
};

subtest 'where: in 空リストはすべてfalse' => sub {
    my $r = query \@base, where { $_->{a}->in([]) };
    is scalar @$r, 0;
};

subtest 'where: in undefはfalseを返す' => sub {
    my $r = query \@null_tbl, where { $_->{val}->in([42]) };
    is scalar @$r, 1;
    is $r->[0]{name}, 'y';
};

subtest 'where: not_in 配列リファレンスで除外' => sub {
    my $r = query \@base, where { $_->{a}->not_in(['alice', 'carol']) };
    is scalar @$r, 3;
    ok !grep { $_->{a} eq 'alice' || $_->{a} eq 'carol' } @$r;
};

subtest 'where: not_in フラットリストでも除外できる' => sub {
    my $r = query \@base, where { $_->{a}->not_in('alice', 'carol') };
    is scalar @$r, 3;
};

# ===========================================================================
# 7. where — asNull
# ===========================================================================

subtest 'where: asNull undef をデフォルト値に置換する' => sub {
    my $r = query \@null_tbl, where { $_->{val}->asNull(0) == 0 };
    is scalar @$r, 2;
    my @names = sort map { $_->{name} } @$r;
    is_deeply \@names, [qw/x z/];
};

subtest 'where: asNull 空文字をデフォルト値に置換する' => sub {
    my $r = query \@null_tbl, where { $_->{val}->asNull('none') eq 'none' };
    is scalar @$r, 2;
};

subtest 'where: asNull 値が存在する場合は元の値を返す' => sub {
    my $r = query \@null_tbl, where { $_->{val}->asNull(0) == 42 };
    is scalar @$r, 1;
    is $r->[0]{name}, 'y';
};

# ===========================================================================
# 8. where — grep_concat
# ===========================================================================

subtest 'grep_concat: 一致しない行は空文字を返す' => sub {
    my $r = query \@log_tbl,
        where { grep_concat('msg', qr/ERROR/, 0, 0) ne '' };
    is scalar @$r, 2;
    ok !grep { $_->{msg} =~ /^INFO/ } @$r;
};

subtest 'grep_concat: $start=0 $end=0 で現在行のみ取得' => sub {
    my @out;
    query \@log_tbl,
        where {
            my $s = grep_concat('msg', qr/ERROR/, 0, 0);
            push @out, $s if $s ne '';
            1;
        };
    is scalar @out, 2;
    like $out[0], qr/ERROR connection failed/;
    unlike $out[0], qr/INFO/;
};

subtest 'grep_concat: 前後行を含むコンテキストを取得' => sub {
    my @out;
    query \@log_tbl,
        where {
            my $s = grep_concat('msg', qr/ERROR/, -1, 1);
            push @out, $s if $s ne '';
            1;
        };
    is scalar @out, 2;
    like $out[0], qr/INFO  start/;
    like $out[0], qr/ERROR connection failed/;
    like $out[0], qr/INFO  retrying/;
};

subtest 'grep_concat: 先頭行での $start=-1 は境界でクランプされる' => sub {
    my @out;
    query \@edge_log,
        where {
            my $s = grep_concat('msg', qr/ERROR first/, -1, 1);
            push @out, $s if $s ne '';
            1;
        };
    is scalar @out, 1;
    like $out[0], qr/ERROR first/;
    like $out[0], qr/INFO  second/;
    unlike $out[0], qr/INFO  third/;
};

subtest 'grep_concat: 末尾行での $end=1 は境界でクランプされる' => sub {
    my @out;
    query \@edge_log,
        where {
            my $s = grep_concat('msg', qr/ERROR last/, -1, 1);
            push @out, $s if $s ne '';
            1;
        };
    is scalar @out, 1;
    like $out[0], qr/INFO  fourth/;
    like $out[0], qr/ERROR last/;
    unlike $out[0], qr/INFO  third/;
};

subtest 'grep_concat: $start 省略時は 0（現在行）' => sub {
    my @out;
    query \@log_tbl,
        where {
            my $s = grep_concat('msg', qr/ERROR/);
            push @out, $s if $s ne '';
            1;
        };
    is scalar @out, 2;
    for my $s (@out) {
        my @lines = split /\n/, $s;
        is scalar @lines, 1;
    }
};

subtest 'grep_concat: undef カラムは空文字を返す' => sub {
    my $r = query \@null_tbl,
        where { grep_concat('val', qr/.+/, 0, 0) ne '' };
    is scalar @$r, 1;
    is $r->[0]{name}, 'y';
};

subtest 'grep_concat: _idx は連結文字列に含まれない' => sub {
    my @out;
    query \@log_tbl,
        where {
            my $s = grep_concat('msg', qr/ERROR/, 0, 0);
            push @out, $s if $s ne '';
            1;
        };
    ok !grep { /\b_idx\b/ } @out;
};

# ===========================================================================
# 8b. grep_concat — WHERE句での正規表現マッチング活用
# ===========================================================================

subtest 'grep_concat: =~ で直前コンテキストにマッチするERROR行を抽出' => sub {
    # ERROR行のうち、直前行に "start" を含むものだけを抽出する
    my $r = query \@log_tbl,
        where { grep_concat('msg', qr/ERROR/, -1, 0) =~ /start/ };
    is scalar @$r, 1;
    is $r->[0]{line}, 2;
};

subtest 'grep_concat: =~ で直後コンテキストにERRORを含むINFO行を抽出' => sub {
    # INFO行のうち、直後行がERRORである行だけを抽出する
    my $r = query \@log_tbl,
        where { grep_concat('msg', qr/INFO/, 0, 1) =~ /ERROR/ };
    is scalar @$r, 2;
    is $r->[0]{line}, 1;
    is $r->[1]{line}, 3;
};

subtest 'grep_concat: !~ でリトライなしのERROR行を抽出' => sub {
    # ERROR行のうち、直後行に "retrying" が現れないものだけを抽出する
    my $r = query \@log_tbl,
        where {
            my $ctx = grep_concat('msg', qr/ERROR/, 0, 1);
            $ctx ne '' && $ctx !~ /retrying/
        };
    is scalar @$r, 1;
    is $r->[0]{line}, 4;
};

subtest 'grep_concat: !~ でコンテキストの内容でERROR行を区別する' => sub {
    # ERROR行のうち、前後コンテキストに "fourth" を含まないものだけを抽出する
    my $r = query \@edge_log,
        where {
            my $ctx = grep_concat('msg', qr/ERROR/, -1, 1);
            $ctx ne '' && $ctx !~ /fourth/
        };
    is scalar @$r, 1;
    is $r->[0]{line}, 1;
};

# ===========================================================================
# 9. having — count_by
# ===========================================================================

subtest 'having: count_by で1件グループを除外する' => sub {
    my $r = query \@base, having { count_by('b') > 1 };
    is scalar @$r, 4;
    ok !grep { $_->{a} eq 'carol' } @$r;
};

subtest 'having: count_by 複数キーでグループ化' => sub {
    my @tbl = (
        { a => 'x', b => 1 },
        { a => 'x', b => 1 },
        { a => 'x', b => 2 },
        { a => 'y', b => 1 },
    );
    my $r = query \@tbl, having { count_by(qw/a b/) > 1 };
    is scalar @$r, 2;
    ok !grep { $_->{b} == 2 } @$r;
};

subtest 'having: count_by の集計対象は where 後のテーブル' => sub {
    # where で b<=20 に絞ると carol(b=30) が除外される
    # where後: alice(b=10), bob(b=20), dave(b=10), eve(b=20)
    # b=10→2件, b=20→2件 → すべて count>1 を満たす
    our $th2;
    my $r = query \@base,
        as $th2,
        SELECT '*',
        where  { $th2->{b} <= 20 },
        having { count_by('b') > 1 };
    is scalar @$r, 4;
};

# ===========================================================================
# 10. having — max_by / min_by
# ===========================================================================

subtest 'having: max_by でグループ最大値が条件を満たす行を残す' => sub {
    # b=10グループ: max(c)=150, b=20グループ: max(c)=250, b=30グループ: max(c)=300
    my $r = query \@base, having { max_by('c', 'b') > 200 };
    is scalar @$r, 3;
    ok !grep { $_->{b} == 10 } @$r;
};

subtest 'having: min_by でグループ最小値が条件を満たす行を残す' => sub {
    # b=10グループ: min(c)=100, b=20グループ: min(c)=200, b=30グループ: min(c)=300
    my $r = query \@base, having { min_by('c', 'b') < 200 };
    is scalar @$r, 2;
    ok !grep { $_->{b} != 10 } @$r;
};

subtest 'having: max_by グループ内に有効値がない場合 undef を返す' => sub {
    my @tbl = (
        { g => 'a', v => undef },
        { g => 'b', v => 10   },
    );
    my $r = query \@tbl, having { !defined max_by('v', 'g') };
    is scalar @$r, 1;
    is $r->[0]{g}, 'a';
};

subtest 'having: min_by グループ内に有効値がない場合 undef を返す' => sub {
    my @tbl = (
        { g => 'a', v => undef },
        { g => 'b', v => 10   },
    );
    my $r = query \@tbl, having { !defined min_by('v', 'g') };
    is scalar @$r, 1;
    is $r->[0]{g}, 'a';
};

# ===========================================================================
# 11. having — first_by / last_by
# ===========================================================================

subtest 'having: first_by でグループ先頭行のみ残す' => sub {
    my $r = query \@base, having { first_by('b') };
    is scalar @$r, 3;
    is_deeply [map { $_->{a} } @$r], [qw/alice bob carol/];
};

subtest 'having: last_by でグループ末尾行のみ残す' => sub {
    my $r = query \@base, having { last_by('b') };
    is scalar @$r, 3;
    is_deeply [map { $_->{a} } @$r], [qw/carol dave eve/];
};

subtest 'having: first_by 1件グループは先頭かつ末尾' => sub {
    my @tbl = (
        { g => 'solo', v => 1 },
        { g => 'duo',  v => 2 },
        { g => 'duo',  v => 3 },
    );
    my $r_first = query \@tbl, having { first_by('g') };
    my $r_last  = query \@tbl, having { last_by('g')  };
    ok grep { $_->{g} eq 'solo' } @$r_first;
    ok grep { $_->{g} eq 'solo' } @$r_last;
};

subtest 'having: first_by 複数キーでグループ化' => sub {
    my @tbl = (
        { a => 'x', b => 1, v => 'first' },
        { a => 'x', b => 1, v => 'second' },
        { a => 'x', b => 2, v => 'only'   },
    );
    my $r = query \@tbl, having { first_by(qw/a b/) };
    is scalar @$r, 2;
    ok grep { $_->{v} eq 'first' } @$r;
    ok grep { $_->{v} eq 'only'  } @$r;
};

# ===========================================================================
# 12. having — エラーケース
# ===========================================================================

subtest 'having: count_by を having 外で呼ぶとdieする' => sub {
    eval { count_by('a') };
    like $@, qr/having/;
};

subtest 'having: max_by を having 外で呼ぶとdieする' => sub {
    eval { max_by('a', 'b') };
    like $@, qr/having/;
};

subtest 'having: min_by を having 外で呼ぶとdieする' => sub {
    eval { min_by('a', 'b') };
    like $@, qr/having/;
};

subtest 'having: first_by を having 外で呼ぶとdieする' => sub {
    eval { first_by('a') };
    like $@, qr/having/;
};

subtest 'having: last_by を having 外で呼ぶとdieする' => sub {
    eval { last_by('a') };
    like $@, qr/having/;
};

# ===========================================================================
# 13. having — as との組み合わせ
# ===========================================================================

subtest 'having: as で alias 変数を使って行の値を参照できる' => sub {
    our $th1;
    my $r = query \@base,
        as $th1,
        SELECT '*',
        having { $th1->{b} == 10 and count_by('b') > 1 };
    is scalar @$r, 2;
    ok !grep { $_->{b} != 10 } @$r;
};

subtest 'having: as なしでも $_ で行の値を参照できる' => sub {
    my $r = query \@base,
        having { $_->{b} == 10 and count_by('b') > 1 };
    is scalar @$r, 2;
};

# ===========================================================================
# 14. DSL 順序独立性
# ===========================================================================

subtest 'DSL: select を where より前に書いても同じ結果' => sub {
    my $r1 = query \@base, SELECT([qw/a b/]), where { $_->{b} == 10 };
    my $r2 = query \@base, where { $_->{b} == 10 }, SELECT [qw/a b/];
    is_deeply $r1, $r2;
};

subtest 'DSL: having を where より前に書いても同じ結果' => sub {
    my $r1 = query \@base, having { count_by('b') > 1 }, where { $_->{b} <= 20 };
    my $r2 = query \@base, where { $_->{b} <= 20 }, having { count_by('b') > 1 };
    is_deeply $r1, $r2;
};

subtest 'DSL: as を後ろに書いても動作する' => sub {
    our $td1;
    my $r = query \@base, where { $td1->{b} == 10 }, as $td1;
    is scalar @$r, 2;
};

# ===========================================================================
# 15. 組み合わせ
# ===========================================================================

subtest '組み合わせ: where + select' => sub {
    our $tc75;
    my $r = query \@base,
        as $tc75,
        SELECT [qw/a/],
        where  { $tc75->{b} == 10 };
    is scalar @$r, 2;
    is_deeply [sort keys %{$r->[0]}], [qw/a/];
};

subtest '組み合わせ: where + select（except）' => sub {
    our $tc76;
    my $r = query \@base,
        as $tc76,
        SELECT { except => ['b'] },
        where  { $tc76->{b} == 10 };
    is scalar @$r, 2;
    ok  exists $r->[0]{a};
    ok  exists $r->[0]{c};
    ok !exists $r->[0]{b};
};

subtest '組み合わせ: where + having + select' => sub {
    our $tc1;
    my $r = query \@base,
        as $tc1,
        SELECT [qw/a b/],
        where  { $tc1->{b} <= 20 },
        having { count_by('b') > 1 };
    is scalar @$r, 4;
    ok !exists $r->[0]{c};
    is_deeply [sort map { $_->{a} } @$r], [qw/alice bob dave eve/];
};

subtest '組み合わせ: grep_concat + where で条件絞り込み' => sub {
    my $r = query \@log_tbl,
        SELECT [qw/line msg/],
        where  { grep_concat('msg', qr/ERROR/, 0, 0) ne '' };
    is scalar @$r, 2;
    is $r->[0]{line}, 2;
    is $r->[1]{line}, 4;
};

subtest '組み合わせ: where + having（having は where 後のテーブルを集計）' => sub {
    # where で carol を除いた後、b グループの件数を集計
    # b=10: alice,dave(2件)  b=20: bob,eve(2件)  全行>1を満たす
    our $tc79;
    my $r = query \@base,
        as $tc79,
        SELECT '*',
        where  { $tc79->{a} ne 'carol' },
        having { count_by('b') > 1 };
    is scalar @$r, 4;
    ok !grep { $_->{a} eq 'carol' } @$r;
};

subtest '組み合わせ: スペック記載のフルサンプル' => sub {
    our $tf1;
    my $r = query
        \@base,
        as $tf1,
        SELECT { except => ['c'] },
        where {
            $tf1->{a} gt 'abc'
            and $tf1->{b} >= 10
            and $tf1->{b} <= 20
        },
        having {
            $tf1->{b} >= 10
            and count_by('b') > 1
            and max_by('c', 'b') > 100
        };
    is_deeply [sort map { $_->{a} } @$r], [qw/alice bob dave eve/];
    ok !exists $r->[0]{c};
};

# ===========================================================================
# 17. 実用テスト — SQL順序（as → select → where → having）
# ===========================================================================

subtest '実用: リードのみ絞り込んでチームと名前を取得' => sub {
    our $m1;
    my $r = query \@members,
        as $m1,
        SELECT [qw/team name/],
        where  { $m1->{role} eq 'lead' };
    is scalar @$r, 3;
    is_deeply [sort map { $_->{name} } @$r], [qw/alice dave frank/];
    ok !exists $r->[0]{score};
    ok !exists $r->[0]{role};
};

subtest '実用: チームの最高スコアが90以上のチームのメンバーを取得' => sub {
    our $m2;
    my $r = query \@members,
        as $m2,
        SELECT [qw/team name score/],
        having { max_by('score', 'team') >= 90 };
    is scalar @$r, 4;
    ok !grep { $_->{team} eq 'beta' } @$r;
};

subtest '実用: スコア75以上かつチームに2人以上いるメンバーを取得' => sub {
    our $m3;
    my $r = query \@members,
        as $m3,
        SELECT [qw/team name score/],
        where  { $m3->{score} >= 75 },
        having { count_by('team') >= 2 };
    is scalar @$r, 3;
    ok !grep { $_->{team} ne 'alpha' } @$r;
    is_deeply [sort map { $_->{name} } @$r], [qw/alice bob carol/];
};

subtest '実用: スコア75以上のメンバーからチームごとの先頭を取得' => sub {
    our $m4;
    my $r = query \@members,
        as $m4,
        SELECT [qw/team name score/],
        where  { $m4->{score} >= 75 },
        having { first_by('team') };
    is scalar @$r, 3;
    is_deeply [sort map { $_->{name} } @$r], [qw/alice dave frank/];
};

# ===========================================================================
# 19. grep_concat — 新仕様テスト（指定カラムの値のみが返ること）
#
# 新仕様: grep_concat($col, $pattern, $start, $end) は指定カラムの値のみを返す。
# ===========================================================================

subtest 'grep_concat: 指定カラムのみが結果に含まれる（単一行）' => sub {
    # msg カラムの値のみが返り、line カラムの値は含まれない
    my @results;
    query \@log_tbl,
        where {
            my $s = grep_concat('msg', qr/ERROR/, 0, 0);
            push @results, $s if $s ne '';
            1;
        };
    is scalar @results, 2;
    ok !grep { /^\d/ } @results,
        '結果が数値で始まらない（line の値が混入していない）';
};

subtest 'grep_concat: コンテキスト行でも指定カラムのみが含まれる' => sub {
    # コンテキスト行を含む場合も、各行の msg 値のみが返る
    my @results;
    query \@log_tbl,
        where {
            my $s = grep_concat('msg', qr/ERROR/, -1, 1);
            push @results, $s if $s ne '';
            1;
        };
    is scalar @results, 2;
    ok !grep { /^\d/m } @results,
        'コンテキスト行にも line の値が混入していない';
};

subtest 'grep_concat: 多カラムテーブルで指定カラム以外の値が混入しない' => sub {
    # @members は 4カラム（name/role/score/team）を持つ
    # name カラムを対象に呼んだとき、戻り値が "alice\n" のみになる
    my @results;
    query \@members,
        where {
            my $s = grep_concat('name', qr/alice/, 0, 0);
            push @results, $s if $s ne '';
            1;
        };
    is scalar @results, 1;
    is $results[0], "alice\n",
        '結果が name の値のみ（"alice\n"）';
};

subtest 'grep_concat: 指定カラムの値と等値比較できること' => sub {
    # 指定カラムの値のみが返るため eq による正確な比較が可能
    my @results;
    query \@members,
        where {
            my $s = grep_concat('name', qr/dave/, 0, 0);
            push @results, $s if $s ne '';
            1;
        };
    is scalar @results, 1;
    is $results[0], "dave\n",
        '結果が "dave\n" と等しい';
};

subtest 'as: クエリ完了後にレコード数が格納される' => sub {
    our $tc;
    query \@base, as $tc, where { $_->{b} == 10 };
    is $tc->{count},  2;
    is $tc->{affect}, 2;
};

# ===========================================================================
# delete — DSL ノード
# ===========================================================================

subtest 'delete: DSL ノードを返す' => sub {
    my $d = DELETE();
    is_deeply $d, { delete => 1 };
};

subtest 'DELETE: UPDATE と同時に指定するとdieする' => sub {
    eval { query \@base, DELETE, UPDATE { b => 0 } };
    like $@, qr/DELETE and UPDATE cannot be used together/;
};

# ===========================================================================
# DELETE — 実行
# ===========================================================================

subtest 'DELETE: where にマッチした行を削除して残りを返す' => sub {
    my $r = query \@base, DELETE, where { $_->{b} == 10 };
    is scalar @$r, 3;
    my @a_vals = map { $_->{a} } @$r;
    is_deeply [sort @a_vals], [qw/bob carol eve/];
};

subtest 'DELETE: 条件なしで全行削除する' => sub {
    my $r = query \@base, DELETE;
    is scalar @$r, 0;
};

subtest 'DELETE: 一致なしで全行残る' => sub {
    my $r = query \@base, DELETE, where { $_->{b} > 999 };
    is scalar @$r, 5;
};

subtest 'DELETE: having と組み合わせて削除できる' => sub {
    my $r = query \@base, DELETE, having { count_by('b') > 1 };
    is scalar @$r, 1;
    is $r->[0]{a}, 'carol';
};

subtest 'DELETE: 元テーブルは変更されない' => sub {
    my @orig = ({ a => 1, b => 2 }, { a => 3, b => 4 });
    my @copy = map { +{ %$_ } } @orig;
    query \@orig, DELETE, where { $_->{a} == 1 };
    is_deeply \@orig, \@copy;
};

subtest 'DELETE: _idx は出力に含まれない' => sub {
    my $r = query \@base, DELETE, where { $_->{b} > 999 };
    ok !exists $r->[0]{_idx};
};

subtest 'DELETE: as で count と affect が返る' => sub {
    our $td;
    query \@base, as $td, DELETE, where { $_->{b} == 10 };
    is $td->{count},  3;
    is $td->{affect}, 2;
};

subtest 'DELETE: SELECT と同じ条件で対称動作する' => sub {
    my $selected = query \@base, SELECT, where { $_->{b} == 10 };
    my $deleted  = query \@base, DELETE, where { $_->{b} == 10 };
    is scalar @$selected + scalar @$deleted, 5;
};

# ===========================================================================
# UPDATE — DSL ノード
# ===========================================================================

subtest 'UPDATE: DSL ノードを返す' => sub {
    my $u = UPDATE { score => 100 };
    is_deeply $u, { update => { score => 100 } };
};

subtest 'UPDATE: 複数カラム指定のDSLノードを返す' => sub {
    my $u = UPDATE { score => 100, grade => 'A' };
    is_deeply $u, { update => { score => 100, grade => 'A' } };
};

subtest 'UPDATE: ハッシュリファレンス以外はdieする' => sub {
    eval { UPDATE('invalid') };
    like $@, qr/UPDATE requires a hash reference/;
};

# ===========================================================================
# UPDATE — 実行
# ===========================================================================

subtest 'UPDATE: where にマッチした行を更新して全行返す' => sub {
    my $r = query \@base, UPDATE { b => 99 }, where { $_->{b} == 10 };
    is scalar @$r, 5;
    my @updated = grep { $_->{b} == 99 } @$r;
    my @a_vals  = sort map { $_->{a} } @updated;
    is_deeply \@a_vals, [qw/alice dave/];
};

subtest 'UPDATE: 条件なしで全行更新する' => sub {
    my $r = query \@base, UPDATE { b => 0 };
    is scalar @$r, 5;
    my @vals = map { $_->{b} } @$r;
    is_deeply \@vals, [0, 0, 0, 0, 0];
};

subtest 'UPDATE: 一致なしで全行そのまま返す' => sub {
    my $r = query \@base, UPDATE { b => 0 }, where { $_->{b} > 999 };
    is scalar @$r, 5;
    my @vals = map { $_->{b} } @$r;
    is_deeply \@vals, [10, 20, 30, 10, 20];
};

subtest 'UPDATE: having と組み合わせて更新できる' => sub {
    my $r = query \@base, UPDATE { b => 0 }, having { count_by('b') > 1 };
    my @zeroed = grep { $_->{b} == 0 } @$r;
    is scalar @zeroed, 4;
    my @intact = grep { $_->{b} != 0 } @$r;
    is scalar @intact, 1;
    is $intact[0]{a}, 'carol';
};

subtest 'UPDATE: 複数カラムを同時に更新できる' => sub {
    my $r = query \@base, UPDATE { b => 0, c => 0 }, where { $_->{a} eq 'alice' };
    my $alice = (grep { $_->{a} eq 'alice' } @$r)[0];
    is $alice->{b}, 0;
    is $alice->{c}, 0;
};

subtest 'UPDATE: 元テーブルは変更されない' => sub {
    my @orig = ({ a => 1, b => 2 }, { a => 3, b => 4 });
    my @copy = map { +{ %$_ } } @orig;
    query \@orig, UPDATE { b => 99 }, where { $_->{a} == 1 };
    is_deeply \@orig, \@copy;
};

subtest 'UPDATE: _idx は出力に含まれない' => sub {
    my $r = query \@base, UPDATE { b => 0 }, where { $_->{b} > 999 };
    ok !exists $r->[0]{_idx};
};

subtest 'UPDATE: as で count と affect が返る' => sub {
    our $tu;
    query \@base, as $tu, UPDATE { b => 0 }, where { $_->{b} == 10 };
    is $tu->{count},  5;
    is $tu->{affect}, 2;
};

subtest 'UPDATE: 存在しないカラムを指定するとdieする' => sub {
    eval { query \@base, UPDATE { nonexistent => 1 } };
    like $@, qr/unknown column in UPDATE: nonexistent/;
};

done_testing;
