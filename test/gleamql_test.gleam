import gleam/hackney
import gleam/json
import gleam/option.{None, Some}
import gleamql
import gleamql/field
import gleamql/operation
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub type Country {
  Country(name: String)
}

pub type CountryWithCode {
  CountryWithCode(name: String, code: String)
}

pub type Post {
  Post(id: String)
}

fn country_field() {
  field.object("country", fn() {
    use name <- field.field(field.string("name"))
    field.build(Country(name:))
  })
}

fn country_with_code_field() {
  field.object("country", fn() {
    use name <- field.field(field.string("name"))
    use code <- field.field(field.string("code"))
    field.build(CountryWithCode(name:, code:))
  })
}

pub fn country_query_test() {
  let country_op =
    operation.query("CountryQuery")
    |> operation.variable("code", "ID!")
    |> operation.field(country_field() |> field.arg("code", "code"))

  let assert Ok(Some(Country(name: "United Kingdom"))) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])
}

pub fn country_query_with_multiple_fields_test() {
  let country_op =
    operation.query("CountryQuery")
    |> operation.variable("code", "ID!")
    |> operation.field(country_with_code_field() |> field.arg("code", "code"))

  let assert Ok(Some(CountryWithCode(name: "United Kingdom", code: "GB"))) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])
}

pub fn invalid_query_test() {
  let country_op =
    operation.query("CountryQuery")
    |> operation.variable("code", "ID!")
    |> operation.field(country_field() |> field.arg("code", "code"))

  // Send with wrong variable name (missing required "code")
  let assert Error(gleamql.GraphQLErrors([
    gleamql.GraphQLError(
      message: "Variable \"$code\" of required type \"ID!\" was not provided.",
      ..,
    ),
    ..
  ])) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("invalid", json.string("invalid"))])
}

pub fn method_not_allowed_test() {
  let country_op =
    operation.query("CountryQuery")
    |> operation.variable("code", "ID!")
    |> operation.field(country_field() |> field.arg("code", "code"))

  let assert Error(gleamql.HttpError(status: 405, ..)) =
    gleamql.new(country_op)
    |> gleamql.host("google.com")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])
}

pub fn invalid_header_content_type_test() {
  let country_op =
    operation.query("CountryQuery")
    |> operation.variable("code", "ID!")
    |> operation.field(country_field() |> field.arg("code", "code"))

  let assert Error(gleamql.HttpError(status: 415, ..)) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.header("Content-Type", "text/html")
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])
}

pub fn mutation_test() {
  let create_post_op =
    operation.mutation("CreatePost")
    |> operation.variable("input", "CreatePostInput!")
    |> operation.field(
      field.object("createPost", fn() {
        use id <- field.field(field.id("id"))
        field.build(Post(id:))
      })
      |> field.arg("input", "input"),
    )

  let assert Ok(_) =
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
}

pub fn inline_string_argument_test() {
  // Test using inline value instead of variable
  let country_op =
    operation.anonymous_query()
    |> operation.field(
      country_field()
      |> field.arg_string("code", "GB"),
    )

  let assert Ok(Some(Country(name: "United Kingdom"))) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [])
}

pub fn optional_field_test() {
  // Test with optional field that may be null
  let capital_field =
    field.object("country", fn() {
      use name <- field.field(field.string("name"))
      use capital <- field.field(field.optional(field.string("capital")))
      field.build(#(name, capital))
    })

  let country_op =
    operation.query("CountryCapital")
    |> operation.variable("code", "ID!")
    |> operation.field(capital_field |> field.arg("code", "code"))

  // GB has capital London
  let assert Ok(Some(#("United Kingdom", Some("London")))) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])

  // AQ (Antarctica) has no capital
  let assert Ok(Some(#("Antarctica", None))) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("AQ"))])
}

pub fn nested_object_test() {
  // Test with nested objects (not in a list)
  let continent_field =
    field.object("continent", fn() {
      use name <- field.field(field.string("name"))
      field.build(name)
    })

  let country_field =
    field.object("country", fn() {
      use continent <- field.field(continent_field)
      field.build(continent)
    })

  let country_op =
    operation.query("CountryContinent")
    |> operation.variable("code", "ID!")
    |> operation.field(country_field |> field.arg("code", "code"))

  let assert Ok(Some("Europe")) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])
}

pub fn single_alias_test() {
  // Test a single field with an alias
  let aliased_field =
    field.object("country", fn() {
      use country_name <- field.field_as("countryName", field.string("name"))
      field.build(country_name)
    })

  let country_op =
    operation.query("CountryAlias")
    |> operation.variable("code", "ID!")
    |> operation.field(aliased_field |> field.arg("code", "code"))

  let assert Ok(Some("United Kingdom")) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])
}

pub fn multiple_aliases_same_field_test() {
  // Test multiple aliases of the same field with different arguments
  // Note: The countries API doesn't support size arguments for fields,
  // so we'll use a simpler test with the same field queried twice with different aliases
  let multi_alias_field =
    field.object("country", fn() {
      use name1 <- field.field_as("name1", field.string("name"))
      use name2 <- field.field_as("name2", field.string("name"))
      field.build(#(name1, name2))
    })

  let country_op =
    operation.query("MultipleAliases")
    |> operation.variable("code", "ID!")
    |> operation.field(multi_alias_field |> field.arg("code", "code"))

  let assert Ok(Some(#("United Kingdom", "United Kingdom"))) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])
}

pub fn nested_object_with_alias_test() {
  // Test aliases in nested objects
  let continent_field =
    field.object("continent", fn() {
      use continent_name <- field.field_as(
        "continentName",
        field.string("name"),
      )
      field.build(continent_name)
    })

  let country_field =
    field.object("country", fn() {
      use continent <- field.field(continent_field)
      field.build(continent)
    })

  let country_op =
    operation.query("NestedAlias")
    |> operation.variable("code", "ID!")
    |> operation.field(country_field |> field.arg("code", "code"))

  let assert Ok(Some("Europe")) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])
}

pub fn alias_with_arguments_test() {
  // Test that aliases work correctly with field arguments
  let aliased_country_field =
    field.object("country", fn() {
      use country_name <- field.field_as("countryName", field.string("name"))
      use country_code <- field.field_as("countryCode", field.string("code"))
      field.build(#(country_name, country_code))
    })

  let country_op =
    operation.query("AliasWithArgs")
    |> operation.variable("code", "ID!")
    |> operation.field(aliased_country_field |> field.arg("code", "code"))

  let assert Ok(Some(#("United Kingdom", "GB"))) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])
}
