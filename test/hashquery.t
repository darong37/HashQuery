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
