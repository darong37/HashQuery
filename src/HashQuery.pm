package HashQuery;

use strict;
use warnings;

use Clone qw(clone);
use Exporter 'import';

our @EXPORT = qw(
    query
    as
    SELECT
    DELETE
    where
    having
    count_by
    max_by
    min_by
    first_by
    last_by
    grep_concat
);

sub query ($@) {
    my ($table, @dsls) = @_;

    die 'query requires an Array of Hash table'
        unless ref $table eq 'ARRAY';

    my @all = _check_cols($table);
    my ($as, $sel, $exc, $whr, $hvg, $del);

    for my $dsl (@dsls) {
        die 'invalid DSL part'
            unless ref $dsl eq 'HASH';

        if (exists $dsl->{alias}) {
            $as = $dsl;
        }
        elsif (exists $dsl->{select}) {
            $sel = $dsl;
        }
        elsif (exists $dsl->{except}) {
            $exc = $dsl;
        }
        elsif (exists $dsl->{where}) {
            $whr = $dsl;
        }
        elsif (exists $dsl->{having}) {
            $hvg = $dsl;
        }
        elsif (exists $dsl->{delete}) {
            $del = $dsl;
        }
        else {
            die 'invalid DSL part';
        }
    }

    die 'select and delete cannot be used together'
        if ($sel || $exc) && $del;

    my $tbl = clone($table);

    for my $i (0 .. $#$tbl) {
        $tbl->[$i]{_idx} = $i;
    }

    if ($del) {
        my $matched = $tbl;
        $matched = _run_where($matched, $as, $whr) if $whr;
        $matched = _run_having($matched, $as, $hvg) if $hvg;

        my %del_idx = map { $_->{_idx} => 1 } @$matched;
        my @remaining = grep { !$del_idx{ $_->{_idx} } } @$tbl;
        my $result = _run_select(\@remaining, \@all);

        if ($as) {
            ${ $as->{alias} } = {
                count  => scalar @$result,
                affect => scalar @$matched,
            };
        }
        return $result;
    }

    my $cols;

    if ($exc) {
        my %skip = map { $_ => 1 } @{ $exc->{except} };
        $cols = [ grep { !$skip{$_} } @all ];
    }
    elsif (!$sel || $sel->{select} eq '*') {
        $cols = \@all;
    }
    elsif (ref $sel->{select} eq 'ARRAY') {
        $cols = $sel->{select};
    }
    else {
        die 'invalid SELECT node';
    }

    $tbl = _run_where($tbl, $as, $whr) if $whr;
    $tbl = _run_having($tbl, $as, $hvg) if $hvg;
    $tbl = _run_select($tbl, $cols);

    if ($as) {
        ${ $as->{alias} } = {
            count  => scalar @$tbl,
            affect => scalar @$tbl,
        };
    }
    return $tbl;
}

sub as (\$) {
    my ($alias) = @_;

    return {
        alias => $alias,
    };
}

sub SELECT (;$) {
    my ($arg) = @_;

    if (!defined $arg || (!ref $arg && $arg eq '*')) {
        return { select => '*' };
    }

    if (ref $arg eq 'ARRAY') {
        return { select => [ @$arg ] };
    }

    if (ref $arg eq 'HASH' && ref $arg->{except} eq 'ARRAY') {
        return { except => [ @{ $arg->{except} } ] };
    }

    die 'SELECT accepts only "*", arrayref, or { except => [...] }';
}

sub where (&) {
    my ($code) = @_;
    return { where => $code };
}

sub having (&) {
    my ($code) = @_;
    return { having => $code };
}

sub DELETE () {
    return { delete => 1 };
}

sub count_by    { return HashQuery::HavingContext::count_by(@_) }
sub max_by      { return HashQuery::HavingContext::max_by(@_) }
sub min_by      { return HashQuery::HavingContext::min_by(@_) }
sub first_by    { return HashQuery::HavingContext::first_by(@_) }
sub last_by     { return HashQuery::HavingContext::last_by(@_) }
sub grep_concat { return HashQuery::WhereContext::grep_concat(@_) }

sub _run_where {
    my ($table, $as, $whr) = @_;
    my $alias = $as ? $as->{alias} : undef;
    my @hit;

    for my $i (0 .. $#$table) {
        my $row = $table->[$i];
        my $h   = HashQuery::RowHash->new($row, $table, $i);
        local $_ = $h;
        local $HashQuery::WhereContext::ROW   = $row;
        local $HashQuery::WhereContext::TABLE = $table;

        if ($alias) {
            $$alias = $h;
            push @hit, $row if $whr->{where}->();
        }
        else {
            push @hit, $row if $whr->{where}->();
        }
    }

    return \@hit;
}

sub _run_having {
    my ($table, $as, $hvg) = @_;
    my $alias = $as ? $as->{alias} : undef;
    my @hit;

    for my $i (0 .. $#$table) {
        my $row = $table->[$i];
        my $h   = HashQuery::RowHash->new($row, $table, $i);
        local $_ = $h;
        local $HashQuery::HavingContext::ROW   = $row;
        local $HashQuery::HavingContext::TABLE = $table;

        if ($alias) {
            $$alias = $h;
            push @hit, $row if $hvg->{having}->();
        }
        else {
            push @hit, $row if $hvg->{having}->();
        }
    }

    return \@hit;
}

sub _run_select {
    my ($table, $cols) = @_;
    my @out;

    for my $row (@$table) {
        my %picked;
        @picked{@$cols} = @{$row}{@$cols};
        push @out, \%picked;
    }

    return \@out;
}

sub _check_cols {
    my ($table) = @_;
    return () unless @$table;

    my @cols = sort keys %{ $table->[0] };
    my %base = map { $_ => 1 } @cols;

    for my $row (@$table) {
        die 'table row must be hash reference'
            unless ref $row eq 'HASH';

        my @keys = sort keys %$row;
        my %keys = map { $_ => 1 } @keys;

        die 'table columns are not consistent'
            unless @keys == @cols;

        for my $col (@cols) {
            die 'table columns are not consistent'
                unless $keys{$col};
        }

        for my $key (@keys) {
            die 'table columns are not consistent'
                unless $base{$key};
        }
    }

    return @cols;
}

sub _compare_values {
    my ($lhs, $rhs) = @_;

    $lhs = '' unless defined $lhs;
    $rhs = '' unless defined $rhs;

    if (_is_number($lhs) && _is_number($rhs)) {
        return $lhs <=> $rhs;
    }

    return "$lhs" cmp "$rhs";
}

sub _is_number {
    my ($value) = @_;
    return defined $value && $value =~ /\A[+-]?(?:\d+(?:\.\d+)?|\.\d+)\z/;
}

1;

package HashQuery::WhereContext;

use strict;
use warnings;

our $ROW;
our $TABLE;

sub grep_concat {
    my ($col, $pattern, $start, $end) = @_;
    $start //= 0;
    $end   //= $start;

    my $row   = _require_row('grep_concat');
    my $table = _require_table('grep_concat');

    my $re    = qr/(?s)$pattern/;
    my $value = $row->{$col};
    return '' unless defined $value && $value =~ $re;

    my $idx = $row->{_idx};

    my $from = $idx + $start;
    my $to   = $idx + $end;
    $from = 0          if $from < 0;
    $to   = $#$table   if $to > $#$table;

    my $result = '';
    for my $r (@{$table}[$from .. $to]) {
        my $v = defined $r->{$col} ? "$r->{$col}" : '';
        $result .= $v . "\n";
    }

    return $result;
}

sub _require_row {
    my ($name) = @_;

    die "$name can only be used inside where"
        unless $ROW;

    return $ROW;
}

sub _require_table {
    my ($name) = @_;

    die "$name can only be used inside where"
        unless $TABLE;

    return $TABLE;
}

1;

package HashQuery::HavingContext;

use strict;
use warnings;

use Scalar::Util qw(refaddr);

our $ROW;
our $TABLE;

sub count_by {
    my @keys = @_;
    my $row = _require_row('count_by');
    my $table = _require_table('count_by');
    my $group_key = _group_key($row, \@keys);
    my @rows = grep { _group_key($_, \@keys) eq $group_key } @$table;
    return scalar @rows;
}

sub max_by {
    my ($target, @keys) = @_;
    my $row = _require_row('max_by');
    my $table = _require_table('max_by');
    my $group_key = _group_key($row, \@keys);
    my @rows = grep { _group_key($_, \@keys) eq $group_key } @$table;
    my $max;

    for my $row (@rows) {
        next unless defined $row->{$target};
        $max = $row->{$target} if !defined $max || $row->{$target} > $max;
    }

    return $max;
}

sub min_by {
    my ($target, @keys) = @_;
    my $row = _require_row('min_by');
    my $table = _require_table('min_by');
    my $group_key = _group_key($row, \@keys);
    my @rows = grep { _group_key($_, \@keys) eq $group_key } @$table;
    my $min;

    for my $row (@rows) {
        next unless defined $row->{$target};
        $min = $row->{$target} if !defined $min || $row->{$target} < $min;
    }

    return $min;
}

sub first_by {
    my @keys = @_;
    my $row = _require_row('first_by');
    my $table = _require_table('first_by');
    my $group_key = _group_key($row, \@keys);
    my @rows = grep { _group_key($_, \@keys) eq $group_key } @$table;

    return 0 unless @rows;
    return refaddr($rows[0]) == refaddr($row) ? 1 : 0;
}

sub last_by {
    my @keys = @_;
    my $row = _require_row('last_by');
    my $table = _require_table('last_by');
    my $group_key = _group_key($row, \@keys);
    my @rows = grep { _group_key($_, \@keys) eq $group_key } @$table;

    return 0 unless @rows;
    return refaddr($rows[-1]) == refaddr($row) ? 1 : 0;
}

sub _require_row {
    my ($name) = @_;

    die "$name can only be used inside having"
        unless $ROW;

    return $ROW;
}

sub _require_table {
    my ($name) = @_;

    die "$name can only be used inside having"
        unless $TABLE;

    return $TABLE;
}

sub _group_key {
    my ($row, $keys) = @_;
    return join "\x1F", map { defined $row->{$_} ? $row->{$_} : '' } @$keys;
}

1;

package HashQuery::RowHash;

use strict;
use warnings;

sub new {
    my ($class, $row, $table, $idx) = @_;
    my %hash;
    tie %hash, $class, $row, $table, $idx;
    return bless \%hash, $class;
}

sub TIEHASH {
    my ($class, $row, $table, $idx) = @_;
    return bless { row => $row, table => $table, idx => $idx }, $class;
}

sub FETCH {
    my ($self, $key) = @_;
    return HashQuery::Value->new($self->{row}, $key, $self->{table}, $self->{idx});
}

1;

package HashQuery::Value;

use strict;
use warnings;

use overload
    '0+'     => sub { $_[0]->_num_value },
    '""'     => sub { $_[0]->_str_value },
    'bool'   => sub { $_[0]->_bool_value },
    fallback => 1;

sub new {
    my ($class, $row, $key, $table, $idx) = @_;
    return bless {
        row   => $row,
        key   => $key,
        table => $table,
        idx   => $idx,
    }, $class;
}

sub _value {
    my ($self) = @_;
    return $self->{row}->{ $self->{key} };
}

sub like {
    my ($self, $pattern) = @_;
    my $value = $self->_value;
    return 0 unless defined $value;

    my $re = quotemeta($pattern);
    $re =~ s/\\%/.*/g;
    $re =~ s/_/./g;

    return $value =~ /\A$re\z/ ? 1 : 0;
}

sub not_like {
    my ($self, $pattern) = @_;
    return $self->like($pattern) ? 0 : 1;
}

sub between {
    my ($self, $min, $max) = @_;
    my $value = $self->_value;
    return 0 unless defined $value;

    my ($min_value, $min_inclusive) = _parse_bound($min);
    my ($max_value, $max_inclusive) = _parse_bound($max);

    my $lower_cmp = HashQuery::_compare_values($value, $min_value);
    return 0 if $min_inclusive ? ($lower_cmp < 0) : ($lower_cmp <= 0);

    my $upper_cmp = HashQuery::_compare_values($value, $max_value);
    return 0 if $max_inclusive ? ($upper_cmp > 0) : ($upper_cmp >= 0);

    return 1;
}

sub in {
    my ($self, @items) = @_;
    my $value = $self->_value;
    return 0 unless defined $value;

    my $list = (@items == 1 && ref $items[0] eq 'ARRAY') ? $items[0] : \@items;

    for my $item (@$list) {
        return 1 if HashQuery::_compare_values($value, $item) == 0;
    }

    return 0;
}

sub not_in {
    my ($self, @items) = @_;
    return $self->in(@items) ? 0 : 1;
}

sub asNull {
    my ($self, $default) = @_;
    my $value = $self->_value;

    return $default if !defined $value || $value eq '';
    return $value;
}

sub _parse_bound {
    my ($bound) = @_;

    return ($bound, 1) if !defined $bound || ref $bound;

    if ($bound =~ /\A(.*)!\z/s) {
        return ($1, 0);
    }

    return ($bound, 1);
}

sub _num_value {
    my ($self) = @_;
    my $value = $self->_value;
    return 0 unless defined $value;
    return $value + 0;
}

sub _str_value {
    my ($self) = @_;
    my $value = $self->_value;
    return '' unless defined $value;
    return "$value";
}

sub _bool_value {
    my ($self) = @_;
    my $value = $self->_value;
    return $value ? 1 : 0;
}

1;
