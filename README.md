# HashQuery

Perl module for querying AOH (Array of Hash) data with SQL-like DSL syntax.

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
my $result = query $table,
    as   $row,
    select [qw/name score/],
    where  { $row->{score} >= 80 },
    having { count_by('grade') > 1 };
```

See [docs/spec.md](docs/spec.md) for the full API reference.

## Features

**Core functions:**

| Function | Role |
|---|---|
| `query` | The only executor. Accepts an AOH table and DSL parts, returns AOH |
| `as` | Binds an alias variable for use in `where` / `having` blocks |
| `select` | Column projection (does not change row count) |
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
| [docs/CodingRule.md](docs/CodingRule.md) | Coding conventions reference (Japanese) |

## Testing

```bash
perl test/hashquery.t
```

Output:

```
1..93
ok 1 - query: no DSL, returns all rows
ok 2 - query: no DSL, returns all columns
...
ok 93 - grep_concat: returned value equals column value
```
