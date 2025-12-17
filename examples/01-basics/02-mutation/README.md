# 01-basics/02-mutation

A simple GraphQL mutation example using the GraphQLZero API.

## What This Example Demonstrates

- Building a GraphQL mutation
- Using complex input variables (JSON objects)
- Creating data via mutations
- Handling mutation responses

## The Code

This example shows how to use GleamQL for mutations (creating, updating, or deleting data):

1. **Use `operation.mutation`** - Instead of `.query`, use `.mutation` to create a mutation
2. **Define input variables** - Mutations often use complex input objects
3. **Pass JSON objects** - Use `json.object()` to build structured input data
4. **Handle the response** - Mutations return the created/updated data

The example creates a new post on the GraphQLZero fake API.

## Running the Example

```bash
cd examples/01-basics/02-mutation
gleam run
```

## Expected Output

```
Generated GraphQL Mutation:
mutation CreatePost($input: CreatePostInput!) {
  createPost(input: $input) {
    id
    title
    body
  }
}

Success! Post created:
ID: 101
Title: A Very Captivating Post Title
Body: Some interesting content.
```

## Next Steps

After understanding mutations, explore:

- [`../../02-advanced/01-fragment`](../../02-advanced/01-fragment) - Learn about reusable fragments
- [`../../02-advanced/02-multiple-roots`](../../02-advanced/02-multiple-roots) - Query multiple fields at once

## API Used

This example uses the [GraphQLZero API](https://graphqlzero.almansi.me/api):
- URL: `https://graphqlzero.almansi.me/api`
- No authentication required
- Fake data API for testing
