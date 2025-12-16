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
