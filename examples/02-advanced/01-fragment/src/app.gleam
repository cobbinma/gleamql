// Demonstrates how to use reusable fragments in GraphQL queries.
//
// This example shows:
// - Defining named fragments
// - Spreading fragments in queries
// - Automatic fragment collection

import gleam/io
import gleamql/field
import gleamql/fragment
import gleamql/operation

// TYPES -----------------------------------------------------------------------

pub type User {
  User(id: String, name: String, email: String)
}

pub type Post {
  Post(id: String, title: String, author: User)
}

// MAIN ------------------------------------------------------------------------

pub fn main() {
  // Define a reusable user fragment
  let user_fields =
    fragment.on("User", "UserFields", fn() {
      use id <- field.field(field.id("id"))
      use name <- field.field(field.string("name"))
      use email <- field.field(field.string("email"))
      field.build(User(id:, name:, email:))
    })

  // Use the fragment in a query - it's automatically collected!
  let post_query =
    operation.query("GetPost")
    |> operation.variable("postId", "ID!")
    |> operation.field(
      field.object("post", fn() {
        use id <- field.field(field.id("id"))
        use title <- field.field(field.string("title"))
        use author <- field.field(
          field.object("author", fn() {
            use user_data <- field.field(fragment.spread(user_fields))
            field.build(user_data)
          }),
        )
        field.build(Post(id:, title:, author:))
      })
      |> field.arg("id", "postId"),
    )

  io.println("Generated GraphQL Query:")
  io.println("========================")
  io.println(operation.to_string(post_query))
}
