# 02-advanced/01-fragment

Demonstrates how to use reusable fragments in GraphQL queries.

## What This Example Demonstrates

- Defining named fragments with `fragment.on()`
- Spreading fragments in queries with `fragment.spread()`
- Automatic fragment collection in the final query
- Reusing field selections across multiple queries

## The Code

This example shows how to create and use GraphQL fragments:

1. **Define a fragment** - Use `fragment.on(type, name, builder)` to create a reusable fragment
2. **Spread the fragment** - Use `fragment.spread(fragment)` wherever you want to use it
3. **Automatic collection** - GleamQL automatically includes fragment definitions in the output

Fragments are useful when you need to select the same fields in multiple places,
keeping your code DRY (Don't Repeat Yourself).

## Running the Example

```bash
cd examples/02-advanced/01-fragment
gleam run
```

## Expected Output

```
Generated GraphQL Query:
========================
query GetPost($postId: ID!) {
  post(id: $postId) {
    id
    title
    author {
      ...UserFields
    }
  }
}

fragment UserFields on User {
  id
  name
  email
}
```

## Key Concepts

**Fragment Definition**: A reusable set of fields for a specific GraphQL type.

**Fragment Spread**: Using `...FragmentName` to include those fields in a query.

**Automatic Collection**: GleamQL tracks which fragments are used and automatically
adds their definitions to the query string.

## Next Steps

- [`../02-multiple-roots`](../02-multiple-roots) - Query multiple root fields
- [`../03-inline-fragment`](../03-inline-fragment) - Handle unions and interfaces

## Note

This example doesn't make a network request - it just demonstrates fragment syntax
and how the generated query looks. Fragments are most useful when you need to
query the same fields across multiple operations.
