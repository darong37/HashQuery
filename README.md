# HashQuery

Syntactic sugar for querying Perl AOH (Array of Hash) data with SQL-like DSL syntax. ([日本語版](README.ja.md)) The DSL closely mirrors SQL so that anyone familiar with SQL can read and write queries intuitively.

`query` takes the target table as its first argument, which serves as both the `FROM` clause and the target for future UPDATE/DELETE operations — keeping the grammar consistent regardless of operation type. `where` filters rows individually; `having` filters based on aggregate conditions across the whole table, matching the SQL `WHERE` / `HAVING` distinction.

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
    SELECT [qw/name score/],
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
| `SELECT` | Column projection (does not change row count) |
| `DELETE` | Declares delete mode; rows matching `where` / `having` are removed, remaining rows returned |
| `UPDATE` | Declares update mode; rows matching `where` / `having` have their specified columns overwritten with fixed values, all rows returned |
| `where` | Row filter with a condition block |
| `having` | Aggregate filter; uses `count_by`, `max_by`, etc. |

> `SELECT`, `DELETE`, `UPDATE` are uppercase to avoid conflicts with Perl built-in operators.

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
1..104
ok 1 - query: no DSL, returns all rows
ok 2 - query: no DSL, returns all columns
...
ok 104 - DELETE: SELECT and DELETE are symmetric for same condition
```
