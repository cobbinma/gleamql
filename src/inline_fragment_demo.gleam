//// Examples demonstrating inline fragment usage for querying unions and interfaces.
////
//// Inline fragments are essential when working with GraphQL union types and interfaces,
//// allowing you to select different fields based on the actual runtime type.

import gleamql/directive
import gleamql/field
import gleamql/operation

// UNION TYPE EXAMPLE ----------------------------------------------------------

/// Example types for a union search result
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

/// Query a union type with inline fragments for each possible type.
///
/// GraphQL Schema:
/// ```graphql
/// union SearchResult = User | Post | Comment
///
/// type Query {
///   search(term: String!): [SearchResult!]!
/// }
/// ```
///
pub fn search_union_example() {
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
  // Generates:
  // query SearchQuery($term: String!) {
  //   search(term: $term) {
  //     ... on User { name email }
  //     ... on Post { title body }
  //     ... on Comment { text author }
  //   }
  // }
}

// INTERFACE TYPE EXAMPLE ------------------------------------------------------

pub type NodeData {
  NodeData(id: String, user_name: String, post_title: String)
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
pub fn interface_example() {
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
  // Generates:
  // query NodeQuery($id: ID!) {
  //   node(id: $id) {
  //     id
  //     ... on User { name }
  //     ... on Post { title }
  //   }
  // }
}

// DIRECTIVE GROUPING EXAMPLE --------------------------------------------------

pub type UserWithPrivate {
  UserWithPrivate(name: String, private_data: #(String, String))
}

/// Use inline fragments without type conditions to group fields with directives.
///
/// This is useful when you want to conditionally include multiple fields together.
///
pub fn directive_grouping_example() {
  operation.query("UserQuery")
  |> operation.variable("id", "ID!")
  |> operation.variable("showPrivate", "Boolean!")
  |> operation.field(
    field.object("user", fn() {
      // Always fetch name
      use name <- field.field(field.string("name"))

      // Conditionally fetch private fields as a group
      use private_data <- field.field(
        field.inline(fn() {
          use email <- field.field(field.string("email"))
          use phone <- field.field(field.string("phone"))
          field.build(#(email, phone))
        })
        |> field.with_directive(directive.include("showPrivate")),
      )

      field.build(UserWithPrivate(name:, private_data:))
    })
    |> field.arg("id", "id"),
  )
  // Generates:
  // query UserQuery($id: ID!, $showPrivate: Boolean!) {
  //   user(id: $id) {
  //     name
  //     ... @include(if: $showPrivate) {
  //       email
  //       phone
  //     }
  //   }
  // }
}

// NESTED INLINE FRAGMENTS EXAMPLE ---------------------------------------------

pub type AdminUser {
  AdminUser(name: String, role: String)
}

/// Nested inline fragments for refining types further.
///
pub fn nested_inline_fragments_example() {
  operation.query("SearchQuery")
  |> operation.field(
    field.object("search", fn() {
      use user_data <- field.field(
        field.inline_on("User", fn() {
          use name <- field.field(field.string("name"))

          // Further refine to Admin type
          use role <- field.field(
            field.inline_on("Admin", fn() {
              use admin_role <- field.field(field.string("role"))
              field.build(admin_role)
            }),
          )

          field.build(AdminUser(name:, role:))
        }),
      )

      field.build(user_data)
    }),
  )
  // Generates:
  // query SearchQuery {
  //   search {
  //     ... on User {
  //       name
  //       ... on Admin {
  //         role
  //       }
  //     }
  //   }
  // }
}
