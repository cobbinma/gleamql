# GleamQL Examples

This directory contains example programs demonstrating various features of GleamQL.
Each example is a complete, self-contained Gleam project that you can run directly.

For newcomers, we recommend looking through them in order, as each example tends
to build on the previous ones. Feel free to jump to any example that interests you, though!

## 01-basics

These examples cover the fundamentals of GleamQL such as building queries, sending
requests, and handling responses.

### [`01-simple-query`](https://github.com/cobbinma/gleamql/tree/master/examples/01-basics/01-simple-query)

A basic GraphQL query example using the Countries API.

**Demonstrates:**
- Building a basic query
- Using variables
- Selecting fields from objects  
- Sending requests with an HTTP client
- Proper error handling

**Run:**
```bash
cd examples/01-basics/01-simple-query
gleam run
```

### [`02-mutation`](https://github.com/cobbinma/gleamql/tree/master/examples/01-basics/02-mutation)

A simple GraphQL mutation example using the GraphQLZero API.

**Demonstrates:**
- Building mutations
- Using complex input variables (JSON objects)
- Creating data via mutations
- Handling mutation responses

**Run:**
```bash
cd examples/01-basics/02-mutation
gleam run
```

## 02-advanced

These examples demonstrate advanced GleamQL features for more complex use cases.

### [`01-fragment`](https://github.com/cobbinma/gleamql/tree/master/examples/02-advanced/01-fragment)

Shows how to use reusable fragments across queries.

**Demonstrates:**
- Defining named fragments
- Spreading fragments in queries
- Fragment reusability
- Automatic fragment collection

**Run:**
```bash
cd examples/02-advanced/01-fragment
gleam run
```

### [`02-multiple-roots`](https://github.com/cobbinma/gleamql/tree/master/examples/02-advanced/02-multiple-roots)

Demonstrates querying multiple root fields in a single operation.

**Demonstrates:**
- Using `operation.root()` for multiple top-level fields
- Querying different data in one request
- Structuring responses as tuples
- Efficient data fetching

**Run:**
```bash
cd examples/02-advanced/02-multiple-roots
gleam run
```

### [`03-inline-fragment`](https://github.com/cobbinma/gleamql/tree/master/examples/02-advanced/03-inline-fragment)

Comprehensive examples of inline fragments for unions and interfaces.

**Demonstrates:**
- Querying union types with inline fragments
- Querying interface types
- Using `field.inline_on()` for type-specific fields
- Handling polymorphic GraphQL responses

**Run:**
```bash
cd examples/02-advanced/03-inline-fragment
gleam run
```

## Public APIs Used

These examples use publicly available GraphQL APIs:

- **Countries API:** `https://countries.trevorblades.com/graphql`
  - A free GraphQL API for country and continent data
  - No authentication required

- **GraphQLZero API:** `https://graphqlzero.almansi.me/api`
  - A fake online GraphQL API for testing
  - No authentication required

## Getting Help

If you're having trouble with GleamQL or not sure what the right way to do
something is, the best place to get help is the [Gleam Discord server](https://discord.gg/Fm8Pwmy).
You could also open an issue on the [GleamQL GitHub repository](https://github.com/cobbinma/gleamql/issues).

## Next Steps

After exploring these examples:

1. Check out the [main documentation](https://hexdocs.pm/gleamql/) for API reference
2. Read the [README](../README.md) for quick start guide
3. Explore the test suite in `test/` for more usage patterns
4. Try building your own queries against these public APIs or your own GraphQL server
