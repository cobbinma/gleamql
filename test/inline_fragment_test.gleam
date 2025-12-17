import gleam/string
import gleamql/directive
import gleamql/field
import gleamql/operation
import gleeunit

pub fn main() {
  gleeunit.main()
}

// Test basic inline fragment with type condition generates correct query
pub fn inline_fragment_with_type_condition_test() {
  let op =
    operation.query("TestQuery")
    |> operation.field(
      field.object("search", fn() {
        use user_name <- field.field(
          field.inline_on("User", fn() {
            use name <- field.field(field.string("name"))
            field.build(name)
          }),
        )
        field.build(user_name)
      }),
    )

  let query_string = operation.to_string(op)

  // Verify the query contains inline fragment syntax with type condition
  let assert True = string.contains(query_string, "... on User { name }")
}

// Test inline fragment without type condition generates correct query
pub fn inline_fragment_without_type_condition_test() {
  let op =
    operation.query("TestQuery")
    |> operation.field(
      field.object("user", fn() {
        use email <- field.field(
          field.inline(fn() {
            use email_field <- field.field(field.string("email"))
            field.build(email_field)
          }),
        )
        field.build(email)
      }),
    )

  let query_string = operation.to_string(op)

  // Verify inline fragment without type condition (just "..." with fields)
  let assert True = string.contains(query_string, "... { email }")
}

// Test directive placement on inline fragment with type condition
pub fn inline_fragment_with_type_condition_and_directive_test() {
  let op =
    operation.query("TestQuery")
    |> operation.variable("includeUser", "Boolean!")
    |> operation.field(
      field.object("search", fn() {
        use user <- field.field(
          field.inline_on("User", fn() {
            use name <- field.field(field.string("name"))
            field.build(name)
          })
          |> field.with_directive(directive.include("includeUser")),
        )
        field.build(user)
      }),
    )

  let query_string = operation.to_string(op)

  // Verify directive comes after "... on User" and before "{"
  let assert True =
    string.contains(query_string, "... on User @include(if: $includeUser) {")
}

// Test directive on inline fragment without type condition
pub fn inline_fragment_without_type_condition_with_directive_test() {
  let op =
    operation.query("TestQuery")
    |> operation.variable("showPrivate", "Boolean!")
    |> operation.field(
      field.object("user", fn() {
        use name <- field.field(field.string("name"))
        use private <- field.field(
          field.inline(fn() {
            use email <- field.field(field.string("email"))
            use phone <- field.field(field.string("phone"))
            field.build(#(email, phone))
          })
          |> field.with_directive(directive.include("showPrivate")),
        )
        field.build(#(name, private))
      }),
    )

  let query_string = operation.to_string(op)

  // Verify inline fragment without type condition has directive
  let assert True =
    string.contains(query_string, "... @include(if: $showPrivate) {")
  let assert True = string.contains(query_string, "email")
  let assert True = string.contains(query_string, "phone")
}

// Test multiple inline fragments in one query
pub fn multiple_inline_fragments_test() {
  let op =
    operation.query("TestQuery")
    |> operation.field(
      field.object("search", fn() {
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
        field.build(#(user_name, post_title))
      }),
    )

  let query_string = operation.to_string(op)

  // Verify both inline fragments are present
  let assert True = string.contains(query_string, "... on User { name }")
  let assert True = string.contains(query_string, "... on Post { title }")
}

// Test inline fragment with multiple fields
pub fn inline_fragment_with_multiple_fields_test() {
  let op =
    operation.query("TestQuery")
    |> operation.field(
      field.object("search", fn() {
        use user_data <- field.field(
          field.inline_on("User", fn() {
            use name <- field.field(field.string("name"))
            use email <- field.field(field.string("email"))
            use age <- field.field(field.int("age"))
            field.build(#(name, email, age))
          }),
        )
        field.build(user_data)
      }),
    )

  let query_string = operation.to_string(op)

  // Verify all fields are in the inline fragment
  let assert True = string.contains(query_string, "... on User {")
  let assert True = string.contains(query_string, "name")
  let assert True = string.contains(query_string, "email")
  let assert True = string.contains(query_string, "age")
}

// Test nested inline fragments
pub fn nested_inline_fragments_test() {
  let op =
    operation.query("TestQuery")
    |> operation.field(
      field.object("search", fn() {
        use outer <- field.field(
          field.inline_on("User", fn() {
            use name <- field.field(field.string("name"))
            use admin <- field.field(
              field.inline_on("Admin", fn() {
                use role <- field.field(field.string("role"))
                field.build(role)
              }),
            )
            field.build(#(name, admin))
          }),
        )
        field.build(outer)
      }),
    )

  let query_string = operation.to_string(op)

  // Verify nested inline fragments
  let assert True = string.contains(query_string, "... on User {")
  let assert True = string.contains(query_string, "... on Admin {")
  let assert True = string.contains(query_string, "role")
}

// Test inline fragment mixed with regular fields
pub fn inline_fragment_mixed_with_regular_fields_test() {
  let op =
    operation.query("TestQuery")
    |> operation.field(
      field.object("search", fn() {
        use id <- field.field(field.id("id"))
        use user_name <- field.field(
          field.inline_on("User", fn() {
            use name <- field.field(field.string("name"))
            field.build(name)
          }),
        )
        field.build(#(id, user_name))
      }),
    )

  let query_string = operation.to_string(op)

  // Verify both regular field and inline fragment
  let assert True = string.contains(query_string, "id")
  let assert True = string.contains(query_string, "... on User { name }")
}

// Test multiple directives on inline fragment
pub fn inline_fragment_with_multiple_directives_test() {
  let op =
    operation.query("TestQuery")
    |> operation.variable("includeUser", "Boolean!")
    |> operation.variable("skipUser", "Boolean!")
    |> operation.field(
      field.object("search", fn() {
        use user <- field.field(
          field.inline_on("User", fn() {
            use name <- field.field(field.string("name"))
            field.build(name)
          })
          |> field.with_directive(directive.include("includeUser"))
          |> field.with_directive(directive.skip("skipUser")),
        )
        field.build(user)
      }),
    )

  let query_string = operation.to_string(op)

  // Verify both directives are present
  let assert True = string.contains(query_string, "@include(if: $includeUser)")
  let assert True = string.contains(query_string, "@skip(if: $skipUser)")
}

// Test inline fragment in a list field
pub fn inline_fragment_in_list_field_test() {
  let op =
    operation.query("TestQuery")
    |> operation.field(
      field.list(
        field.object("searchResults", fn() {
          use user_name <- field.field(
            field.inline_on("User", fn() {
              use name <- field.field(field.string("name"))
              field.build(name)
            }),
          )
          field.build(user_name)
        }),
      ),
    )

  let query_string = operation.to_string(op)

  // Verify inline fragment works in list context
  let assert True = string.contains(query_string, "... on User { name }")
}

// Test query string format is valid GraphQL
pub fn inline_fragment_query_format_test() {
  let op =
    operation.query("SearchQuery")
    |> operation.variable("term", "String!")
    |> operation.field(
      field.object("search", fn() {
        use user <- field.field(
          field.inline_on("User", fn() {
            use name <- field.field(field.string("name"))
            field.build(name)
          }),
        )
        field.build(user)
      })
      |> field.arg("term", "term"),
    )

  let query_string = operation.to_string(op)

  // Verify basic structure
  let assert True = string.contains(query_string, "query SearchQuery")
  let assert True = string.contains(query_string, "$term: String!")
  let assert True = string.contains(query_string, "search(term: $term)")
  let assert True = string.contains(query_string, "... on User { name }")
}
