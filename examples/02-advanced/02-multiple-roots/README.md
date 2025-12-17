# 02-advanced/02-multiple-roots

Demonstrates querying multiple root fields in a single GraphQL operation.

## What This Example Demonstrates

- Using `operation.root()` to create multiple root-level fields
- Querying different data in a single request
- Structuring responses as tuples when fields are unrelated
- Efficient data fetching with fewer round trips

## The Code

This example shows how to query multiple root fields without nesting them
under a wrapper field:

1. **Use `operation.root()`** - This creates a root-level field builder
2. **Define multiple fields** - Each field at the root level is independent
3. **Return a tuple** - Since the fields are unrelated, return them as a tuple

This is more efficient than making separate requests for each piece of data.

## Running the Example

```bash
cd examples/02-advanced/02-multiple-roots
gleam run
```

## Expected Output

```
Generated GraphQL Query:
query GetCountryAndContinent($countryCode: ID!, $continentCode: ID!) {
  country(code: $countryCode) {
    name
    code
  }
  continent(code: $continentCode) {
    name
    code
  }
}

Notice: No wrapper field! Both 'country' and 'continent' are at the root level.
```

## Key Concepts

**Multiple Root Fields**: In GraphQL, you can request multiple top-level fields
in a single query, which is more efficient than making separate requests.

**Root vs Field**: Use `operation.root()` when you want fields at the top level,
or `operation.field()` when you want a single root field.

**Tuple Returns**: When querying unrelated data, returning a tuple `#(a, b)` is
a natural way to structure your decoder.

## Next Steps

- [`../03-inline-fragment`](../03-inline-fragment) - Handle union types and interfaces
- [`../../01-basics/01-simple-query`](../../01-basics/01-simple-query) - Review basic queries

## Note

This example doesn't make a network request - it demonstrates the query structure.
The pattern shown here works with any GraphQL API that supports multiple root fields.
