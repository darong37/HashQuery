# HashQuery

Syntactic sugar for querying Perl AOH (Array of Hash) data with SQL-like DSL syntax. ([日本語版](README.ja.md)) The DSL closely mirrors SQL so that anyone familiar with SQL can read and write queries intuitively.

`HashQuery->new(\@table)` creates an instance from an AOH table. `SELECT` / `DELETE` / `UPDATE` are called as instance methods. `where` filters rows individually; `having` filters based on aggregate conditions across the whole table, matching the SQL `WHERE` / `HAVING` distinction.

## Requirements

- Perl 5.x
- [Clone](https://metacpan.org/pod/Clone)

## Installation

```bash
cpanm Clone
```

Place `HashQuery.pm` in a directory on `@INC`, then:

```perl
use HashQuery;
```

## Quick Start

```perl
use HashQuery;

my $table = [
    { name => 'alice', score => 90, grade => 'A' },
    { name => 'bob',   score => 75, grade => 'B' },
    { name => 'carol', score => 85, grade => 'A' },
];

our $row;
my $hq = HashQuery->new(\@table, as $row);

my $result = $hq->SELECT(
    [qw/name score/],
    where  { $row->{score} >= 80 },
    having { count_by('grade') > 1 },
);
```

See [docs/spec.md](docs/spec.md) for the full API reference.

## Features

**Constructor:**

```perl
my $hq = HashQuery->new(\@table);
my $hq = HashQuery->new(\@table, as $tbl);
```

**Instance methods:**

| Method | Role |
|---|---|
| `SELECT('*', ...)` | Column projection; rows matching `where` / `having` are returned |
| `DELETE(...)` | Rows matching `where` / `having` are removed; remaining rows returned |
| `UPDATE(\%set, ...)` | Rows matching `where` / `having` have their specified columns overwritten; all rows returned |

**DSL helper functions:**

| Function | Role |
|---|---|
| `as` | Binds an alias variable for use in `where` / `having` blocks (passed to `new`) |
| `except` | Column exclusion for `SELECT` first argument |
| `set` | Syntax sugar for `UPDATE` first argument (key/value list → hashref) |
| `where` | Row filter with a condition block |
| `having` | Aggregate filter; uses `count_by`, `max_by`, etc. |

**Methods on column values (`$row->{col}`):**

| Method | Role |
|---|---|
| `like($pattern)` | SQL LIKE match (`%` = any string, `_` = any char) |
| `not_like($pattern)` | Negated LIKE |
| `between($min, $max)` | Range check (append `!` to a bound to exclude it) |
| `in(@list)` | Set membership |
| `not_in(@list)` | Negated set membership |
| `asNull($default)` | Replace `undef` or empty string with a default value |

**`having`-only aggregate functions:**

| Function | Role |
|---|---|
| `count_by($key, ...)` | Count of rows sharing the same group key |
| `max_by($col, $key, ...)` | Max of `$col` within the group |
| `min_by($col, $key, ...)` | Min of `$col` within the group |
| `first_by($key, ...)` | True if the current row is the first in its group |
| `last_by($key, ...)` | True if the current row is the last in its group |

**`where`-only standalone function:**

| Function | Role |
|---|---|
| `grep_concat($col, $pattern, $start, $end)` | Returns `$col` values from a range of rows around the matching row, joined by newline. The `s` flag is applied to `$pattern` automatically. |

## Documentation

| File | Description |
|---|---|
| [docs/spec.md](docs/spec.md) | Feature specification and API reference (Japanese) |
| [docs/test-spec.md](docs/test-spec.md) | Test case definitions (Japanese) |

## Testing

```bash
perl test/hashquery.t
```

Output:

```
1..60
ok 1 - as: { as => \$var } を返す
ok 2 - except: { except => [...] } を返す
...
ok 60 - 実用: スコア75以上かつチームに2人以上いるメンバーを取得
```
