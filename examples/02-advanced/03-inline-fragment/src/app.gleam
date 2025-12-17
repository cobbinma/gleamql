// Demonstrates inline fragments for querying GraphQL unions and interfaces.
//
// This example shows:
// - Using field.inline_on() for type-specific fields
// - Querying union types
// - Querying interface types

import gleam/io
import gleamql/field
import gleamql/operation

// TYPES -----------------------------------------------------------------------

// Union type example
pub type UserResult {
  UserResult(name: String, email: String)
}

pub type PostResult {
  PostResult(title: String, body: String)
}

pub type CommentResult {
  CommentResult(text: String, author: String)
}

pub type SearchResult {
  SearchResult(user: UserResult, post: PostResult, comment: CommentResult)
}

// Interface type example
pub type NodeData {
  NodeData(id: String, user_name: String, post_title: String)
}

// MAIN ------------------------------------------------------------------------

pub fn main() {
  // Example 1: Union type query
  io.println("Generated GraphQL Query (Union Example):")
  io.println(operation.to_string(search_union_example()))
  io.println("")

  // Example 2: Interface type query
  io.println("Generated GraphQL Query (Interface Example):")
  io.println(operation.to_string(interface_example()))
}

// EXAMPLES --------------------------------------------------------------------

/// Query a union type with inline fragments for each possible type.
///
/// GraphQL Schema:
/// ```graphql
/// union SearchResult = User | Post | Comment
/// ```
///
fn search_union_example() {
  operation.query("SearchQuery")
  |> operation.variable("term", "String!")
  |> operation.field(
    field.list(
      field.object("search", fn() {
        // Inline fragment for User type
        use user <- field.field(
          field.inline_on("User", fn() {
            use name <- field.field(field.string("name"))
            use email <- field.field(field.string("email"))
            field.build(UserResult(name:, email:))
          }),
        )

        // Inline fragment for Post type
        use post <- field.field(
          field.inline_on("Post", fn() {
            use title <- field.field(field.string("title"))
            use body <- field.field(field.string("body"))
            field.build(PostResult(title:, body:))
          }),
        )

        // Inline fragment for Comment type
        use comment <- field.field(
          field.inline_on("Comment", fn() {
            use text <- field.field(field.string("text"))
            use author <- field.field(field.string("author"))
            field.build(CommentResult(text:, author:))
          }),
        )

        field.build(SearchResult(user:, post:, comment:))
      }),
    )
    |> field.arg("term", "term"),
  )
}

/// Query an interface type with inline fragments for specific implementations.
///
/// GraphQL Schema:
/// ```graphql
/// interface Node {
///   id: ID!
/// }
///
/// type User implements Node {
///   id: ID!
///   name: String!
/// }
///
/// type Post implements Node {
///   id: ID!
///   title: String!
/// }
/// ```
///
fn interface_example() {
  operation.query("NodeQuery")
  |> operation.variable("id", "ID!")
  |> operation.field(
    field.object("node", fn() {
      // Common field available on all Node types
      use id <- field.field(field.id("id"))

      // Type-specific fields using inline fragments
      use user_name <- field.field(
        field.inline_on("User", fn() {
          use name <- field.field(field.string("name"))
          field.build(name)
        }),
      )

      use post_title <- field.field(
        field.inline_on("Post", fn() {
          use title <- field.field(field.string("title"))
          field.build(title)
        }),
      )

      field.build(NodeData(id:, user_name:, post_title:))
    })
    |> field.arg("id", "id"),
  )
}
