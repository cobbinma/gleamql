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

## Key Features

### Building Fields

```gleam
// Scalars
field.string("name")
field.int("age")
field.bool("active")

// Optional fields and lists
field.optional(field.string("nickname"))
field.list(field.string("tags"))

// Nested objects
field.object("user", fn() {
  use name <- field.field(field.string("name"))
  use age <- field.field(field.int("age"))
  field.build(User(name:, age:))
})
```

### Mutations

```gleam
operation.mutation("CreatePost")
|> operation.variable("input", "CreatePostInput!")
|> operation.field(
  field.object("createPost", fn() {
    use id <- field.field(field.id("id"))
    field.build(Post(id:))
  })
  |> field.arg("input", "input")
)
```

### Multiple Root Fields

Query multiple fields at the root level in a single operation:

```gleam
pub type DashboardData {
  DashboardData(user: User, posts: List(Post), stats: Stats)
}

operation.query("GetDashboard")
|> operation.variable("userId", "ID!")
|> operation.root(fn() {
  use user <- field.field(
    field.object("user", fn() {
      use name <- field.field(field.string("name"))
      use email <- field.field(field.string("email"))
      field.build(User(name:, email:))
    })
    |> field.arg("id", "userId")
  )
  use posts <- field.field(
    field.list(field.object("posts", fn() {
      use title <- field.field(field.string("title"))
      field.build(Post(title:))
    }))
    |> field.arg("authorId", "userId")
  )
  use stats <- field.field(
    field.object("userStats", fn() {
      use totalPosts <- field.field(field.int("totalPosts"))
      field.build(Stats(totalPosts:))
    })
  )
  field.build(DashboardData(user:, posts:, stats:))
})
```

This generates:

```graphql
query GetDashboard($userId: ID!) {
  user(id: $userId) {
    name
    email
  }
  posts(authorId: $userId) {
    title
  }
  userStats {
    totalPosts
  }
}
```

### Fragments

Reuse field selections across queries:

```gleam
import gleamql/fragment

let user_fields = 
  fragment.on("User", "UserFields", fn() {
    use id <- field.field(field.id("id"))
    use name <- field.field(field.string("name"))
    field.build(User(id:, name:))
  })

operation.query("GetUsers")
|> operation.field(
  field.list(field.object("users", fn() {
    use user <- field.field(fragment.spread(user_fields))
    field.build(user)
  }))
)
```

### Inline Fragments

Query unions and interfaces:

```gleam
// Query a union type
field.object("search", fn() {
  use user <- field.field(field.inline_on("User", fn() {
    use name <- field.field(field.string("name"))
    field.build(name)
  }))
  use post <- field.field(field.inline_on("Post", fn() {
    use title <- field.field(field.string("title"))
    field.build(title)
  }))
  field.build(SearchResult(user:, post:))
})
```

### Directives

Conditionally include fields:

```gleam
import gleamql/directive

field.string("email")
|> field.with_directive(directive.include("showEmail"))
// Generates: email @include(if: $showEmail)
```

## Documentation

For comprehensive guides and API documentation, visit [hexdocs.pm/gleamql](https://hexdocs.pm/gleamql/).

## HTTP Clients

Works with any HTTP client:

- [gleam_hackney](https://hex.pm/packages/gleam_hackney) (Erlang)
- [gleam_fetch](https://hex.pm/packages/gleam_fetch) (JavaScript)
- [gleam_httpc](https://hex.pm/packages/gleam_httpc) (Erlang)

## License

Apache-2.0
