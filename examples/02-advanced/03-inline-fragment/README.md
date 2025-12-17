# 02-advanced/03-inline-fragment

Demonstrates inline fragments for querying GraphQL unions and interfaces.

## What This Example Demonstrates

- Using `field.inline_on()` for type-specific fields
- Querying union types with inline fragments
- Querying interface types
- Handling polymorphic GraphQL responses

## The Code

This example shows how to work with GraphQL union types and interfaces:

1. **Define types for each variant** - Create Gleam types for each possible type
2. **Use `field.inline_on(type, builder)`** - Create inline fragments for each variant
3. **Aggregate the results** - Combine all variants into a single result type

Inline fragments are essential for polymorphic GraphQL queries where a field
can return different types.

## Running the Example

```bash
cd examples/02-advanced/03-inline-fragment
gleam run
```

## Expected Output

```
Generated GraphQL Query (Union Example):
query SearchQuery($term: String!) {
  search(term: $term) {
    ... on User {
      name
      email
    }
    ... on Post {
      title
      body
    }
    ... on Comment {
      text
      author
    }
  }
}

Generated GraphQL Query (Interface Example):
query NodeQuery($id: ID!) {
  node(id: $id) {
    id
    ... on User {
      name
    }
    ... on Post {
      title
    }
  }
}
```

## Key Concepts

**Union Types**: A GraphQL union can be one of several types. You use inline
fragments to specify which fields to select for each possible type.

**Interface Types**: A GraphQL interface defines common fields, with implementations
adding additional fields. Use inline fragments to access implementation-specific fields.

**Inline Fragments**: Syntax `... on TypeName { fields }` lets you conditionally
select fields based on the concrete type.

## Next Steps

- [`../01-fragment`](../01-fragment) - Review named fragments
- [`../../01-basics/01-simple-query`](../../01-basics/01-simple-query) - Back to basics

## Note

This example demonstrates the query structure without making network requests.
The patterns shown work with any GraphQL API that uses unions or interfaces.
