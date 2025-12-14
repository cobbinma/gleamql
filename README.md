# gleamql

[![Package Version](https://img.shields.io/hexpm/v/gleamql)](https://hex.pm/packages/gleamql)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gleamql/)

A GraphQL client library for Gleam that builds queries and decoders simultaneously ✨

## Overview

gleamql is a type-safe GraphQL client for Gleam that uses a builder pattern to construct GraphQL operations and their response decoders at the same time. This ensures your queries and decoders can never get out of sync.

Inspired by [gleam-community/codec](https://github.com/gleam-community/codec), gleamql uses a codec-style API where you define the structure once and get both the GraphQL query string and the response decoder automatically.

## Features

- 🔒 **Type-safe** - Query structure and decoder always match
- 🎯 **Codec-style builders** - Define once, get query + decoder
- 🔄 **Reusable operations** - Operations can be reused with different variable values
- 📦 **No codegen** - Pure Gleam, no build step required
- ✨ **Clean API** - Intuitive builder pattern with `use` expressions
- 🚀 **Supports queries and mutations**
- 🌐 **Works everywhere Gleam runs** - Erlang, JavaScript, and more

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
  // Build the operation with query and decoder together
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

  // Send the request with variable values
  let assert Ok(Some(Country(name: "United Kingdom", code: "GB"))) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [
      #("code", json.string("GB")),
    ])
}
```

This generates the GraphQL query:
```graphql
query CountryQuery($code: ID!) {
  country(code: $code) {
    name
    code
  }
}
```

And automatically creates a decoder that extracts `Country` from the response.

## Usage Guide

### Building Fields

#### Scalar Fields

```gleam
import gleamql/field

// Basic scalar fields
let name_field = field.string("name")
let age_field = field.int("age")
let price_field = field.float("price")
let active_field = field.bool("isActive")
let id_field = field.id("id")
```

#### Optional and List Fields

```gleam
// Optional field (nullable in GraphQL)
let nickname = field.optional(field.string("nickname"))
// Type: Field(Option(String))

// List field
let tags = field.list(field.string("tags"))
// Type: Field(List(String))

// Optional list
let maybe_tags = field.optional(field.list(field.string("tags")))
// Type: Field(Option(List(String)))
```

#### Object Fields

Use codec-style builders with `use` expressions:

```gleam
pub type Address {
  Address(street: String, city: String, zip: String)
}

fn address_field() {
  field.object("address", fn() {
    use street <- field.field(field.string("street"))
    use city <- field.field(field.string("city"))
    use zip <- field.field(field.string("zipCode"))
    field.build(Address(street:, city:, zip:))
  })
}
```

#### Nested Objects

```gleam
pub type Person {
  Person(name: String, address: Address)
}

fn person_field() {
  field.object("person", fn() {
    use name <- field.field(field.string("name"))
    use address <- field.field(address_field())
    field.build(Person(name:, address:))
  })
}
```

### Field Arguments

#### Variable Arguments

```gleam
// Single variable argument
field.object("country", country_builder)
|> field.arg("code", "code")
// Generates: country(code: $code) { ... }

// Multiple arguments
field.object("posts", posts_builder)
|> field.with_args([
  #("first", field.Variable("limit")),
  #("after", field.Variable("cursor")),
])
```

#### Inline Arguments

```gleam
// Inline string
field.object("country", country_builder)
|> field.arg_string("code", "GB")
// Generates: country(code: "GB") { ... }

// Inline int
field.object("posts", posts_builder)
|> field.arg_int("first", 10)

// Inline bool
field.object("users", users_builder)
|> field.arg_bool("active", True)

// Inline object (for mutations)
field.object("createPost", create_post_builder)
|> field.arg_object("input", [
  #("title", field.InlineString("My Post")),
  #("body", field.InlineString("Post content")),
])
```

### Building Operations

#### Queries

```gleam
import gleamql/operation

let my_query =
  operation.query("GetUser")
  |> operation.variable("id", "ID!")
  |> operation.variable("includeEmail", "Boolean")
  |> operation.field(user_field())
```

#### Mutations

```gleam
let create_user =
  operation.mutation("CreateUser")
  |> operation.variable("input", "CreateUserInput!")
  |> operation.field(
    field.object("createUser", fn() {
      use id <- field.field(field.id("id"))
      use name <- field.field(field.string("name"))
      field.build(User(id:, name:))
    })
    |> field.arg("input", "input"),
  )
```

#### Anonymous Operations

```gleam
// For simple queries without names
let simple_query =
  operation.anonymous_query()
  |> operation.field(countries_field())
```

### Sending Requests

```gleam
import gleam/hackney

gleamql.new(my_operation)
|> gleamql.host("api.example.com")
|> gleamql.path("/graphql")
|> gleamql.scheme(http.Https)  // Optional, defaults to HTTP
|> gleamql.header("Authorization", "Bearer token123")  // Optional headers
|> gleamql.json_content_type()  // Required by most GraphQL servers
|> gleamql.send(hackney.send, [
  #("id", json.string("user-123")),
  #("includeEmail", json.bool(True)),
])
```

Variable values are provided at send time, allowing operations to be reused:

```gleam
let country_op = operation.query("CountryQuery")...

// Reuse with different values
gleamql.new(country_op) |> gleamql.send(..., [#("code", json.string("GB"))])
gleamql.new(country_op) |> gleamql.send(..., [#("code", json.string("FR"))])
```

## Complete Example: Mutation

```gleam
import gleamql
import gleamql/field
import gleamql/operation
import gleam/json
import gleam/hackney

pub type Post {
  Post(id: String, title: String)
}

pub fn create_post(title: String, body: String) {
  let create_post_op =
    operation.mutation("CreatePost")
    |> operation.variable("input", "CreatePostInput!")
    |> operation.field(
      field.object("createPost", fn() {
        use id <- field.field(field.id("id"))
        use title <- field.field(field.string("title"))
        field.build(Post(id:, title:))
      })
      |> field.arg("input", "input"),
    )

  gleamql.new(create_post_op)
  |> gleamql.host("api.example.com")
  |> gleamql.path("/graphql")
  |> gleamql.json_content_type()
  |> gleamql.send(hackney.send, [
    #(
      "input",
      json.object([
        #("title", json.string(title)),
        #("body", json.string(body)),
      ]),
    ),
  ])
}
```

## HTTP Clients

gleamql works with any HTTP client that matches the signature:
```gleam
fn(Request(String)) -> Result(Response(String), e)
```

Recommended clients:
- [gleam_hackney](https://hex.pm/packages/gleam_hackney) (Erlang)
- [gleam_fetch](https://hex.pm/packages/gleam_fetch) (JavaScript)
- [gleam_httpc](https://hex.pm/packages/gleam_httpc) (Erlang)

## Error Handling

gleamql provides comprehensive error handling with specific error types for different failure scenarios:

```gleam
import gleam/dynamic

case gleamql.send(request, client, variables) {
  // Success with data
  Ok(Some(data)) -> handle_success(data)
  
  // Success but data field was null
  Ok(None) -> handle_null_data()
  
  // GraphQL server returned errors
  Error(gleamql.GraphQLErrors(errors)) -> {
    // errors is a List(GraphQLError)
    list.each(errors, fn(error) {
      // Access error details
      io.println(error.message)
      
      // Optional path to the field that failed
      case error.path {
        Some(path) -> io.debug(path)  // List(Dynamic)
        None -> Nil
      }
      
      // Optional server-specific extensions
      case error.extensions {
        Some(ext) -> io.debug(ext)  // Dynamic
        None -> Nil
      }
    })
  }
  
  // HTTP error (non-2xx status)
  Error(gleamql.HttpError(status:, body:)) -> {
    io.println("HTTP " <> int.to_string(status))
    io.println(body)
  }
  
  // Network error (connection failed, timeout, etc.)
  Error(gleamql.NetworkError(http_error)) -> {
    // http_error is the original error from your HTTP client
    io.debug(http_error)
  }
  
  // Response wasn't valid JSON
  Error(gleamql.InvalidJson(decode_error, body)) -> {
    io.debug(decode_error)
    io.println(body)
  }
  
  // JSON was valid but didn't match expected structure
  Error(gleamql.DecodeError(errors, body)) -> {
    list.each(errors, fn(err) {
      io.println("Expected: " <> err.expected)
      io.println("Found: " <> err.found)
      io.debug(err.path)
    })
    io.println(body)
  }
}
```

### Error Type Reference

- **`GraphQLErrors(List(GraphQLError))`** - GraphQL server returned errors. Contains ALL errors from the response, not just the first one. Each `GraphQLError` has:
  - `message: String` - Human-readable error message
  - `path: Option(List(Dynamic))` - Path to the field that caused the error (can contain strings or integers)
  - `extensions: Option(Dynamic)` - Additional server-specific error information

- **`HttpError(status: Int, body: String)`** - Server returned a non-2xx HTTP status code. Includes the status code and full response body for debugging.

- **`NetworkError(http_error)`** - Network-level failure (connection refused, timeout, DNS issues, etc.). Preserves the original error from your HTTP client.

- **`InvalidJson(json.DecodeError, body: String)`** - Response body wasn't valid JSON. Includes the JSON parsing error and response body.

- **`DecodeError(List(decode.DecodeError), body: String)`** - JSON was valid but didn't match the expected GraphQL response structure. Includes all decode errors and the response body.

### Best Practices

```gleam
// Always handle all error cases
case gleamql.send(request, client, variables) {
  Ok(Some(data)) -> process_data(data)
  Ok(None) -> handle_null_result()
  Error(error) -> {
    // Log the error for debugging
    logger.error("GraphQL request failed", [
      #("error", string.inspect(error))
    ])
    
    // Return appropriate error to user
    case error {
      gleamql.GraphQLErrors(errors) -> 
        show_user_friendly_errors(errors)
      _ -> 
        show_generic_error()
    }
  }
}
```

## Limitations & Future Work

### Current Limitations (v0.5.0)
- Single root field per operation (can't do `query { user {...} posts {...} }`)
- No fragments support
- No field aliases support
- Lists of nested objects require workaround

### Planned Features
- Multiple root fields (v0.6.0)
- Fragment support (v0.7.0)
- Field aliases (v0.7.0)
- Improved list of objects support (v0.6.0)
- Directive support (@include, @skip) (v0.8.0)

## Migration from v0.4.x

### Breaking Changes in v0.5.0

v0.5.0 is a complete redesign with breaking changes:

**Old API (v0.4.x):**
```gleam
const query = "query GetCountry($code: ID!) { country(code: $code) { name } }"

gleamql.new()
|> gleamql.set_query(query)
|> gleamql.set_variable("code", json.string("GB"))
|> gleamql.set_decoder(my_decoder)
|> gleamql.set_host("api.example.com")
|> gleamql.send(hackney.send)
```

**New API (v0.5.0):**
```gleam
let country_op =
  operation.query("GetCountry")
  |> operation.variable("code", "ID!")
  |> operation.field(country_field())

gleamql.new(country_op)
|> gleamql.host("api.example.com")
|> gleamql.send(hackney.send, [#("code", json.string("GB"))])
```

**Key Changes:**
- ❌ Removed: `set_query()` - use operation builders
- ❌ Removed: `set_decoder()` - decoder built automatically
- ❌ Removed: `set_variable()` - use `operation.variable()`
- ❌ Renamed: `set_default_content_type_header()` → `json_content_type()`
- ❌ Renamed: `set_host()` → `host()`, `set_path()` → `path()`, etc.
- ✅ Changed: `send()` now requires variables list as third parameter
- ✅ Changed: `new()` now requires an Operation instead of being empty
- ✅ Changed: Error types completely redesigned (see Error Handling section)
- ✅ Added: `gleamql/field` module for field builders
- ✅ Added: `gleamql/operation` module for operation builders

**Error Type Changes:**

Old error types:
```gleam
Error(gleamql.ErrorMessage(msg))          // Single GraphQL error
Error(gleamql.UnexpectedStatus(status))   // HTTP error
Error(gleamql.UnrecognisedResponse(body)) // Decode error
Error(gleamql.UnknownError)               // Network error
```

New error types:
```gleam
Error(gleamql.GraphQLErrors([...]))       // ALL GraphQL errors with full details
Error(gleamql.HttpError(status:, body:))  // HTTP error with body
Error(gleamql.DecodeError(errors, body))  // Decode errors with full details
Error(gleamql.InvalidJson(error, body))   // Invalid JSON with parse error
Error(gleamql.NetworkError(http_error))   // Network error preserving original
```

The new error types provide much more context for debugging and preserve all error information from the underlying systems.

## Documentation

Full documentation is available at [hexdocs.pm/gleamql](https://hexdocs.pm/gleamql/).

## License

Apache-2.0

## Contributing

Contributions are welcome! Please open an issue or PR on [GitHub](https://github.com/cobbinma/gleamql).
