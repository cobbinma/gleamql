import gleam/hackney
import gleam/json
import gleam/option.{None, Some}
import gleam/string
import gleamql
import gleamql/field
import gleamql/fragment
import gleamql/operation
import gleeunit

pub fn main() {
  gleeunit.main()
}

// Type definitions for tests
pub type Country {
  Country(name: String, code: String)
}

pub type Continent {
  Continent(name: String, code: String)
}

pub type Language {
  Language(name: String)
}

// Helper function to build a country field
fn country_field() {
  field.object("country", fn() {
    use name <- field.field(field.string("name"))
    use code <- field.field(field.string("code"))
    field.build(Country(name:, code:))
  })
}

// Helper function to build a continent field
fn continent_field() {
  field.object("continent", fn() {
    use name <- field.field(field.string("name"))
    use code <- field.field(field.string("code"))
    field.build(Continent(name:, code:))
  })
}

// Test 1: Basic multiple root fields (two fields)
pub fn basic_multiple_root_fields_test() {
  let multi_op =
    operation.query("GetCountryAndContinent")
    |> operation.variable("countryCode", "ID!")
    |> operation.variable("continentCode", "ID!")
    |> operation.root(fn() {
      use country <- field.field(
        country_field()
        |> field.arg("code", "countryCode"),
      )
      use continent <- field.field(
        continent_field()
        |> field.arg("code", "continentCode"),
      )
      field.build(#(country, continent))
    })

  // Verify query string format
  let query_string = operation.to_string(multi_op)

  // Should contain both fields at root level
  let assert True = string.contains(query_string, "country(code: $countryCode)")
  let assert True =
    string.contains(query_string, "continent(code: $continentCode)")

  // Should NOT contain a wrapper field like "root {"
  let assert False = string.contains(query_string, "root {")

  // Test actual execution
  let assert Ok(Some(#(
    Country(name: "United Kingdom", code: "GB"),
    Continent(name: "Europe", code: "EU"),
  ))) =
    gleamql.new(multi_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [
      #("countryCode", json.string("GB")),
      #("continentCode", json.string("EU")),
    ])
}

// Test 2: Three root fields with different types
pub fn three_root_fields_test() {
  let multi_op =
    operation.query("GetThreeFields")
    |> operation.variable("code1", "ID!")
    |> operation.variable("code2", "ID!")
    |> operation.root(fn() {
      use country <- field.field(
        country_field()
        |> field.arg("code", "code1"),
      )
      use continent <- field.field(
        continent_field()
        |> field.arg("code", "code2"),
      )
      use languages <- field.field(
        field.list(
          field.object("languages", fn() {
            use name <- field.field(field.string("name"))
            field.build(Language(name:))
          }),
        ),
      )
      field.build(#(country, continent, languages))
    })

  let query_string = operation.to_string(multi_op)

  // Verify all three fields are present
  let assert True = string.contains(query_string, "country(code: $code1)")
  let assert True = string.contains(query_string, "continent(code: $code2)")
  let assert True = string.contains(query_string, "languages")

  // Test execution
  let assert Ok(Some(#(
    Country(name: "United Kingdom", ..),
    Continent(name: "Europe", ..),
    _languages,
  ))) =
    gleamql.new(multi_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [
      #("code1", json.string("GB")),
      #("code2", json.string("EU")),
    ])
}

// Test 3: Single field via root() for consistency
pub fn single_field_via_root_test() {
  let single_op =
    operation.query("GetCountry")
    |> operation.variable("code", "ID!")
    |> operation.root(fn() {
      use country <- field.field(
        country_field()
        |> field.arg("code", "code"),
      )
      field.build(country)
    })

  // Should work identically to operation.field()
  let assert Ok(Some(Country(name: "United Kingdom", code: "GB"))) =
    gleamql.new(single_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])
}

// Test 4: Multiple root fields with aliases
pub fn multiple_roots_with_aliases_test() {
  let multi_op =
    operation.query("GetTwoCountries")
    |> operation.root(fn() {
      use uk <- field.field_as(
        "uk",
        country_field()
          |> field.arg_string("code", "GB"),
      )
      use us <- field.field_as(
        "us",
        country_field()
          |> field.arg_string("code", "US"),
      )
      field.build(#(uk, us))
    })

  let query_string = operation.to_string(multi_op)

  // Verify aliases are in the query
  let assert True = string.contains(query_string, "uk: country")
  let assert True = string.contains(query_string, "us: country")

  // Test execution
  let assert Ok(Some(#(
    Country(name: "United Kingdom", code: "GB"),
    Country(name: "United States", code: "US"),
  ))) =
    gleamql.new(multi_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [])
}

// Test 5: Multiple root fields with fragments
pub fn multiple_roots_with_fragments_test() {
  let country_fragment =
    fragment.on("Country", "CountryFields", fn() {
      use name <- field.field(field.string("name"))
      use code <- field.field(field.string("code"))
      field.build(Country(name:, code:))
    })

  let multi_op =
    operation.query("GetCountriesWithFragment")
    |> operation.root(fn() {
      use uk <- field.field(
        field.object("country", fn() {
          use country_data <- field.field(fragment.spread(country_fragment))
          field.build(country_data)
        })
        |> field.arg_string("code", "GB"),
      )
      use continent <- field.field(
        continent_field()
        |> field.arg_string("code", "EU"),
      )
      field.build(#(uk, continent))
    })

  let query_string = operation.to_string(multi_op)

  // Verify fragment definition appears
  let assert True =
    string.contains(query_string, "fragment CountryFields on Country")

  // Verify fragment spread is used
  let assert True = string.contains(query_string, "...CountryFields")

  // Test execution
  let assert Ok(Some(#(
    Country(name: "United Kingdom", code: "GB"),
    Continent(name: "Europe", ..),
  ))) =
    gleamql.new(multi_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [])
}

// Test 6: Optional fields in multiple roots
pub fn multiple_roots_optional_fields_test() {
  let multi_op =
    operation.query("GetCountryWithOptionalCapital")
    |> operation.variable("code", "ID!")
    |> operation.root(fn() {
      use country <- field.field(
        field.object("country", fn() {
          use name <- field.field(field.string("name"))
          use capital <- field.field(field.optional(field.string("capital")))
          field.build(#(name, capital))
        })
        |> field.arg("code", "code"),
      )
      use continent <- field.field(
        continent_field()
        |> field.arg_string("code", "EU"),
      )
      field.build(#(country, continent))
    })

  // Test with country that has capital (GB)
  let assert Ok(Some(#(#("United Kingdom", Some("London")), Continent(..)))) =
    gleamql.new(multi_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])

  // Test with country that has no capital (AQ - Antarctica)
  let assert Ok(Some(#(#("Antarctica", None), Continent(..)))) =
    gleamql.new(multi_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("AQ"))])
}

// Test 7: Query string format validation
pub fn query_string_format_test() {
  let multi_op =
    operation.query("TestQuery")
    |> operation.variable("id", "ID!")
    |> operation.root(fn() {
      use a <- field.field(
        field.object("country", fn() {
          use name <- field.field(field.string("name"))
          field.build(name)
        })
        |> field.arg("code", "id"),
      )
      use b <- field.field(
        field.object("continent", fn() {
          use code <- field.field(field.string("code"))
          field.build(code)
        })
        |> field.arg_string("code", "EU"),
      )
      field.build(#(a, b))
    })

  let query = operation.to_string(multi_op)

  // Verify it starts with query keyword
  let assert True = string.starts_with(query, "query TestQuery($id: ID!) {")

  // Verify both fields are at root level (no nesting wrapper)
  let assert True = string.contains(query, "country(code: $id)")
  let assert True = string.contains(query, "continent(code: \"EU\")")
}

// Test 8: Nested objects within multiple root fields
pub fn nested_objects_in_multiple_roots_test() {
  let multi_op =
    operation.query("GetNestedData")
    |> operation.variable("code", "ID!")
    |> operation.root(fn() {
      use country_with_continent <- field.field(
        field.object("country", fn() {
          use name <- field.field(field.string("name"))
          use continent <- field.field(
            field.object("continent", fn() {
              use cont_name <- field.field(field.string("name"))
              field.build(cont_name)
            }),
          )
          field.build(#(name, continent))
        })
        |> field.arg("code", "code"),
      )
      use standalone_continent <- field.field(
        continent_field()
        |> field.arg_string("code", "EU"),
      )
      field.build(#(country_with_continent, standalone_continent))
    })

  // Test execution
  let assert Ok(Some(#(
    #("United Kingdom", "Europe"),
    Continent(name: "Europe", ..),
  ))) =
    gleamql.new(multi_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])
}
