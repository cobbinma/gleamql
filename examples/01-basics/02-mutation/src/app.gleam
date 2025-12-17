// A simple GraphQL mutation example using the GraphQLZero API.
//
// This example demonstrates:
// - Building a mutation
// - Using complex input variables (JSON objects)
// - Creating data
// - Handling mutation responses

import gleam/hackney
import gleam/io
import gleam/json
import gleam/option
import gleamql
import gleamql/field
import gleamql/operation

// TYPES -----------------------------------------------------------------------

pub type Post {
  Post(id: String, title: String, body: String)
}

// MAIN ------------------------------------------------------------------------

pub fn main() {
  // Build a mutation for creating a post
  let create_post_op =
    operation.mutation("CreatePost")
    |> operation.variable("input", "CreatePostInput!")
    |> operation.field(
      field.object("createPost", fn() {
        use id <- field.field(field.id("id"))
        use title <- field.field(field.string("title"))
        use body <- field.field(field.string("body"))
        field.build(Post(id:, title:, body:))
      })
      |> field.arg("input", "input"),
    )

  // Print the generated GraphQL mutation
  io.println("Generated GraphQL Mutation:")
  io.println(operation.to_string(create_post_op))
  io.println("")

  // Send the mutation to the GraphQLZero API
  case
    gleamql.new(create_post_op)
    |> gleamql.host("graphqlzero.almansi.me")
    |> gleamql.path("/api")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [
      #(
        "input",
        json.object([
          #("title", json.string("A Very Captivating Post Title")),
          #("body", json.string("Some interesting content.")),
        ]),
      ),
    ])
  {
    Ok(option.Some(Post(id:, title:, body:))) -> {
      io.println("Success! Post created:")
      io.println("ID: " <> id)
      io.println("Title: " <> title)
      io.println("Body: " <> body)
    }
    Ok(option.None) -> {
      io.println("No data returned")
    }
    Error(_err) -> {
      io.println("Error occurred - check your network connection")
    }
  }
}
