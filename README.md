# gleamql

[![Package Version](https://img.shields.io/hexpm/v/gleamql)](https://hex.pm/packages/gleamql)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gleamql/)

A type-safe GraphQL client for Gleam.

## Installation

```sh
gleam add gleamql
```

## Quick Start

```gleam
import gleamql
import gleamql/field
import gleamql/operation
import gleam/json
import gleam/hackney

pub type Country {
  Country(name: String, code: String)
}

pub fn main() {
  // Build the operation
  let country_op =
    operation.query("CountryQuery")
    |> operation.variable("code", "ID!")
    |> operation.field(
      field.object("country", fn() {
        use name <- field.field(field.string("name"))
        use code <- field.field(field.string("code"))
        field.build(Country(name:, code:))
      })
      |> field.arg("code", "code"),
    )

  // Send the request
  let assert Ok(Some(Country(name: "United Kingdom", code: "GB"))) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])
}
```

This generates:
```graphql
query CountryQuery($code: ID!) {
  country(code: $code) {
    name
    code
  }
}
```

## Building Fields

### Scalars

```gleam
field.string("name")
field.int("age")
field.float("price")
field.bool("isActive")
field.id("id")
```

### Optional and Lists

```gleam
field.optional(field.string("nickname"))
field.list(field.string("tags"))
```

### Objects

```gleam
field.object("person", fn() {
  use name <- field.field(field.string("name"))
  use age <- field.field(field.int("age"))
  field.build(Person(name:, age:))
})
```

### Nested Objects

```gleam
field.object("user", fn() {
  use name <- field.field(field.string("name"))
  use address <- field.field(address_field())
  field.build(User(name:, address:))
})
```

## Field Arguments

```gleam
// Variable reference
field.object("country", country_builder)
|> field.arg("code", "code")

// Inline values
field.object("posts", posts_builder)
|> field.arg_string("status", "published")
|> field.arg_int("limit", 10)
```

## Fragments

Fragments allow you to reuse common field selections across multiple queries.

### Defining Fragments

```gleam
import gleamql/fragment

// Define a reusable fragment
let user_fields = 
  fragment.on("User", "UserFields", fn() {
    use id <- field.field(field.id("id"))
    use name <- field.field(field.string("name"))
    use email <- field.field(field.string("email"))
    field.build(#(id, name, email))
  })
```

### Using Fragments in Queries

```gleam
// Just use fragment.spread() - it's automatically included!
operation.query("GetUsers")
|> operation.field(
  field.list(
    field.object("users", fn() {
      use user_data <- field.field(fragment.spread(user_fields))
      let #(id, name, email) = user_data
      field.build(User(id:, name:, email:))
    })
  )
)
```

This generates:
```graphql
query GetUsers {
  users {
    ...UserFields
  }
}

fragment UserFields on User {
  id
  name
  email
}
```

### Multiple Fragments

You can use multiple fragments in a single operation - they're all auto-collected:

```gleam
operation.query("GetPost")
|> operation.variable("id", "ID!")
|> operation.field(
  field.object("post", fn() {
    use author <- field.field(fragment.spread(user_fields))
    use comments <- field.field(
      field.list(
        field.object("comments", fn() {
          use comment_data <- field.field(fragment.spread(comment_fields))
          field.build(comment_data)
        })
      )
    )
    field.build(Post(author:, comments:))
  })
)
```

### Combining Fragments with Regular Fields

```gleam
field.object("post", fn() {
  use author <- field.field(fragment.spread(user_fields))
  use created_at <- field.field(field.string("createdAt"))
  field.build(Post(author:, created_at:))
})
```

## Operations

### Queries

```gleam
operation.query("GetUser")
|> operation.variable("id", "ID!")
|> operation.field(user_field())
```

### Mutations

```gleam
operation.mutation("CreatePost")
|> operation.variable("input", "CreatePostInput!")
|> operation.field(create_post_field())
```

## Error Handling

```gleam
case gleamql.send(request, client, variables) {
  Ok(Some(data)) -> handle_success(data)
  Ok(None) -> handle_null_data()
  Error(gleamql.GraphQLErrors(errors)) -> handle_graphql_errors(errors)
  Error(gleamql.HttpError(status:, body:)) -> handle_http_error(status, body)
  Error(gleamql.NetworkError(error)) -> handle_network_error(error)
  Error(gleamql.InvalidJson(error, body)) -> handle_invalid_json(error, body)
  Error(gleamql.DecodeError(errors, body)) -> handle_decode_error(errors, body)
}
```

## HTTP Clients

Works with any client matching `fn(Request(String)) -> Result(Response(String), e)`:

- [gleam_hackney](https://hex.pm/packages/gleam_hackney) (Erlang)
- [gleam_fetch](https://hex.pm/packages/gleam_fetch) (JavaScript)
- [gleam_httpc](https://hex.pm/packages/gleam_httpc) (Erlang)

## Documentation

Full documentation at [hexdocs.pm/gleamql](https://hexdocs.pm/gleamql/).

## License

Apache-2.0
