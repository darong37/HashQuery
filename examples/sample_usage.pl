use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/../src";
use HashQuery;

my $table = [
    { name => 'alice', score => 90, grade => 'A' },
    { name => 'bob',   score => 75, grade => 'B' },
    { name => 'carol', score => 85, grade => 'A' },
    { name => 'dave',  score => 60, grade => 'C' },
    { name => 'eve',   score => 88, grade => 'A' },
];

# --- 1. where: 行フィルタ ---

my $high = query $table, where { $_->{score} >= 80 };
print "score >= 80:\n";
print "  $_->{name} ($_->{score})\n" for @$high;
# alice(90), carol(85), eve(88)

print "\n";

# --- 2. select: 列を絞る ---

my $names = query $table, select [qw/name score/];
print "select name, score:\n";
print "  $_->{name} => $_->{score}\n" for @$names;

print "\n";

# --- 3. select except: 指定列を除外 ---

my $no_grade = query $table, select { except => ['grade'] };
print "except grade:\n";
print "  ", join(', ', map { "$_=$no_grade->[0]{$_}" } sort keys %{ $no_grade->[0] }), "\n";

print "\n";

# --- 4. as + where: alias 変数でフィルタ ---

our $row;
my $b_or_higher = query $table, as $row, where { $row->{grade} ne 'C' };
print "grade != C:\n";
print "  $_->{name} ($_->{grade})\n" for @$b_or_higher;

print "\n";

# --- 5. where: like / between / in ---

my $al = query $table, where { $_->{name}->like('a%') };
print "name like 'a%':\n";
print "  $_->{name}\n" for @$al;

my $mid = query $table, where { $_->{score}->between(75, 88) };
print "score between 75 and 88:\n";
print "  $_->{name} ($_->{score})\n" for @$mid;

my $top = query $table, where { $_->{grade}->in(['A']) };
print "grade in ('A'):\n";
print "  $_->{name}\n" for @$top;

print "\n";

# --- 6. having: count_by でグループ件数フィルタ ---

my $multi = query $table, having { count_by('grade') > 1 };
print "count_by(grade) > 1:\n";
print "  $_->{name} ($_->{grade})\n" for @$multi;
# grade A のグループ（3件）のみ通過。grade B, C は1件なので除外。

print "\n";

# --- 7. having: first_by でグループ先頭だけ残す ---

our $r;
my $firsts = query $table, as $r, having { first_by('grade') };
print "first_by(grade):\n";
print "  $_->{name} ($_->{grade})\n" for @$firsts;

print "\n";

# --- 8. 組み合わせ: where + having + select ---

my $result = query
    $table,
    as   $row,
    select [qw/name score/],
    where  { $row->{score} >= 75 },
    having { count_by('grade') > 1 };

print "where(score>=75) + having(count_by(grade)>1) + select(name,score):\n";
print "  $_->{name} => $_->{score}\n" for @$result;
