# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Multiple root fields support** for querying multiple top-level fields in a single operation
  - New `operation.root()` function using builder pattern for type-safe multiple root fields
  - Phantom root pattern ensures clean GraphQL generation without wrapper fields
  - Full backward compatibility - existing `operation.field()` continues to work
  - Supports all existing features: variables, aliases, fragments, directives
  - See README for examples and test/multiple_root_fields_test.gleam for comprehensive usage
- **Inline fragment support** for querying GraphQL unions and interfaces per GraphQL specification
  - `field.inline_on()` for inline fragments with type conditions (e.g., `... on User { name }`)
  - `field.inline()` for inline fragments without type conditions (directive grouping)
  - Full support for directives on inline fragments
  - Nested inline fragments
  - See `src/inline_fragment_demo.gleam` for comprehensive examples
- Fragment support for reusing common field selections per GraphQL specification
  - New `gleamql/fragment` module with `on()` and `spread()` functions
  - `operation.fragment()` to register fragment definitions with operations
  - Full support for named fragments with type conditions
  - Fragment spreads can be combined with regular fields in object builders

### Changed

- Simplified README to focus on main use-cases (comprehensive docs available at hexdocs.pm)

### Internal Changes

- Added `PhantomRoot` variant to `SelectionSet` type in `gleamql/field`
- New `field.phantom_root()` internal constructor for phantom root fields
- New `field.is_phantom_root()` helper to detect phantom roots
- Updated `operation.decoder()` to handle phantom root field decoding
- Updated `field.to_selection()` to render phantom roots without field wrapper
- Extended `SelectionSet` type in `gleamql/field` to support `InlineFragment` variant
- Updated `to_selection()` to generate inline fragment syntax with proper directive placement
- Enhanced decoder composition to handle inline fragment fields spreading into parent
- Updated query string generation to append fragment definitions
- Enhanced decoder composition to handle fragment spreads inline

## [0.5.0] - 2025-12-15

### Changed - BREAKING

This is a complete rewrite of the gleamql API, moving from a manual query+decoder approach to a codec-style builder pattern. **This release is not backward compatible with v0.4.x**.

#### New Codec-Style Builder API

**Before (v0.4.x):**
```gleam
let query = "query($id: ID!) { user(id: $id) { name email } }"
let decoder = decode.into({
  fn(name, email) { User(name: name, email: email) }
})
|> decode.field("name", decode.string)
|> decode.field("email", decode.string)

gleamql.new(query, decoder, [Variable("id", "123")])
|> gleamql.send(client)
```

**After (v0.5.0):**
```gleam
import gleamql/field
import gleamql/operation

let user_query = {
  use name <- field.string("name")
  use email <- field.string("email")
  field.return(User(name: name, email: email))
}

let query =
  operation.query("user", user_query)
  |> operation.id_arg("id")

gleamql.new(query)
|> gleamql.send(client, [#("id", json.string("123"))])
```

#### Key Breaking Changes

1. **Request Construction**: Operations are now built using `gleamql/operation` module instead of raw query strings
2. **Field Builders**: Queries and decoders are defined together using the `gleamql/field` module with `use` expressions
3. **Variable Handling**: Variables are defined in the operation but values are provided at send time
4. **Response Unwrapping**: The library now automatically unwraps the GraphQL `data` field - no need for wrapper types
5. **Module Structure**: New submodules `gleamql/field` and `gleamql/operation` for better organization
6. **Error Types**: Completely redesigned error handling with spec-compliant GraphQL errors (see below)

#### Error Type Changes

The error handling system has been completely redesigned to provide more context and follow the GraphQL specification:

**Old Error Types (v0.4.x):**
```gleam
pub type GraphQLError {
  ErrorMessage(message: String)          // Single GraphQL error
  UnexpectedStatus(status: Int)          // HTTP error
  UnrecognisedResponse(response: String) // Decode error
  UnknownError                           // Network error (discarded details)
}
```

**New Error Types (v0.5.0):**
```gleam
pub type Error(http_error) {
  GraphQLErrors(List(GraphQLError))      // ALL GraphQL errors with full spec-compliant fields
  HttpError(status: Int, body: String)   // HTTP error with response body
  DecodeError(List(decode.DecodeError), body: String) // Detailed decode errors
  InvalidJson(json.DecodeError, body: String)         // JSON parse errors
  NetworkError(http_error)               // Preserves original HTTP client error
}

pub type GraphQLError {
  GraphQLError(
    message: String,                     // Error message
    path: Option(List(Dynamic)),         // Path to the field that failed
    extensions: Option(Dynamic),         // Server-specific error details
  )
}
```

**Key Improvements:**
- Returns **all** GraphQL errors, not just the first one
- Includes GraphQL spec-compliant fields: `path`, `extensions`
- Preserves original HTTP client errors (generic over error type)
- Includes response body in decode and HTTP errors for debugging
- Distinguishes between malformed JSON and structure mismatch
- Separates network, HTTP, GraphQL, and decode error concerns

### Added

- `gleamql/field` module with scalar field builders:
  - `field.string()`, `field.int()`, `field.float()`, `field.bool()`, `field.id()`
  - `field.optional()`, `field.list()` for container types
  - `field.object()` for nested objects with codec-style composition
  - Argument helpers: `arg()`, `arg_string()`, `arg_int()`, `arg_bool()`, `arg_object()`
  - `with_args()` for adding arguments to fields

- `gleamql/operation` module for building GraphQL operations:
  - `operation.query()`, `operation.mutation()` builders
  - Variable definition helpers: `id_arg()`, `string_arg()`, `int_arg()`, etc.
  - Automatic operation string generation

- FFI placeholder functions (`gleamql_ffi.erl`, `gleamql_ffi.mjs`) for safe field list extraction

### Removed

- Raw query string construction (replaced by operation builders)
- Manual decoder wiring (replaced by codec-style field builders)
- `Variable` type exposed to users (variables now internal to operations)
- Backward compatibility with v0.4.x API

### Migration Guide

See the [README.md](README.md#migrating-from-v04x) for a detailed migration guide from v0.4.x to v0.5.0.

### Known Limitations

- Only single root field per operation (multiple fields planned for future release)
- No support for aliases yet
- Union types and inline fragments not yet supported (planned for future release)

---

## [0.4.1] and earlier

See git history for changes in previous versions.
