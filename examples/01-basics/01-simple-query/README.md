# 01-basics/01-simple-query

A simple GraphQL query example using the Countries API.

## What This Example Demonstrates

- Building a basic GraphQL query
- Using variables in queries
- Selecting fields from objects
- Sending requests with an HTTP client
- Proper error handling

## The Code

This example shows the fundamental workflow of using GleamQL:

1. **Define your data types** - Create Gleam types to represent the GraphQL response
2. **Build the operation** - Use the operation builder to construct your query
3. **Define fields** - Map GraphQL fields to your Gleam types
4. **Send the request** - Configure the HTTP request and send it

The example queries the Countries GraphQL API to fetch information about a country
by its code.

## Running the Example

```bash
cd examples/01-basics/01-simple-query
gleam run
```

## Expected Output

```
Generated GraphQL Query:
query CountryQuery($code: ID!) {
  country(code: $code) {
    name
    code
  }
}

Success!
Country: United Kingdom (GB)
```

## Next Steps

After understanding this basic example, check out:

- [`02-mutation`](../02-mutation) - Learn how to create data with mutations
- [`../../02-advanced/01-fragment`](../../02-advanced/01-fragment) - Explore reusable fragments

## API Used

This example uses the free [Countries GraphQL API](https://countries.trevorblades.com/graphql):
- URL: `https://countries.trevorblades.com/graphql`
- No authentication required
- Provides country and continent data
