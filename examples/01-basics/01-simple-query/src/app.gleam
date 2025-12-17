// A simple GraphQL query example using the Countries API.
//
// This example demonstrates:
// - Building a basic query
// - Using variables
// - Selecting fields from objects
// - Sending the request with an HTTP client
// - Proper error handling

import gleam/hackney
import gleam/io
import gleam/json
import gleam/option
import gleamql
import gleamql/field
import gleamql/operation

// TYPES -----------------------------------------------------------------------

pub type Country {
  Country(name: String, code: String)
}

// MAIN ------------------------------------------------------------------------

pub fn main() {
  // Build a query for fetching country information
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

  // Print the generated GraphQL query
  io.println("Generated GraphQL Query:")
  io.println(operation.to_string(country_op))
  io.println("")

  // Send the request to the Countries API
  case
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])
  {
    Ok(option.Some(Country(name:, code:))) -> {
      io.println("Success!")
      io.println("Country: " <> name <> " (" <> code <> ")")
    }
    Ok(option.None) -> {
      io.println("No data returned")
    }
    Error(_err) -> {
      io.println("Error occurred - check your network connection")
    }
  }
}
