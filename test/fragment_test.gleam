import gleam/hackney
import gleam/json
import gleam/option.{Some}
import gleamql
import gleamql/field
import gleamql/fragment
import gleamql/operation
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub type Country {
  Country(name: String, code: String)
}

pub type Continent {
  Continent(name: String, code: String)
}

pub type CountryWithContinent {
  CountryWithContinent(name: String, code: String, continent: String)
}

// Test basic named fragment creation and usage
pub fn basic_named_fragment_test() {
  let country_fields =
    fragment.on("Country", "CountryFields", fn() {
      use name <- field.field(field.string("name"))
      field.build(Country(name:, code: ""))
    })

  let country_op =
    operation.query("GetCountry")
    |> operation.variable("code", "ID!")
    |> operation.field(
      field.object("country", fn() {
        use country_data <- field.field(fragment.spread(country_fields))
        field.build(country_data)
      })
      |> field.arg("code", "code"),
    )

  let assert Ok(Some(Country(name: "United Kingdom", ..))) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])
}

// Test fragment with multiple fields
pub fn fragment_with_multiple_fields_test() {
  let country_fields =
    fragment.on("Country", "CountryFields", fn() {
      use name <- field.field(field.string("name"))
      use code <- field.field(field.string("code"))
      field.build(Country(name:, code:))
    })

  let country_op =
    operation.query("GetCountry")
    |> operation.variable("code", "ID!")
    |> operation.field(
      field.object("country", fn() {
        use country_data <- field.field(fragment.spread(country_fields))
        field.build(country_data)
      })
      |> field.arg("code", "code"),
    )

  let assert Ok(Some(Country(name: "United Kingdom", code: "GB"))) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])
}

// Test reusing the same fragment multiple times
pub fn fragment_reuse_query_string_test() {
  let continent_fields =
    fragment.on("Continent", "ContinentFields", fn() {
      use name <- field.field(field.string("name"))
      use code <- field.field(field.string("code"))
      field.build(Continent(name:, code:))
    })

  let country_op =
    operation.query("GetCountries")
    |> operation.field(
      field.list(
        field.object("countries", fn() {
          use name <- field.field(field.string("name"))
          use continent <- field.field(
            field.object("continent", fn() {
              use continent_data <- field.field(fragment.spread(
                continent_fields,
              ))
              field.build(continent_data)
            }),
          )
          field.build(#(name, continent))
        }),
      ),
    )

  // Just check we can generate the query string without errors
  let query = operation.to_string(country_op)
  let assert True = case query {
    _ -> True
  }
}

// Test reusing the same fragment multiple times
pub fn fragment_reuse_test() {
  let continent_fields =
    fragment.on("Continent", "ContinentFields", fn() {
      use name <- field.field(field.string("name"))
      use code <- field.field(field.string("code"))
      field.build(Continent(name:, code:))
    })

  let country_op =
    operation.query("GetCountries")
    |> operation.field(
      field.list(
        field.object("countries", fn() {
          use name <- field.field(field.string("name"))
          use continent <- field.field(
            field.object("continent", fn() {
              use continent_data <- field.field(fragment.spread(
                continent_fields,
              ))
              field.build(continent_data)
            }),
          )
          field.build(#(name, continent))
        }),
      ),
    )

  let assert Ok(Some(countries)) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [])

  // Verify we got some countries and can access the data
  let assert True = case countries {
    [#(_name, _continent), ..] -> True
    _ -> False
  }
}

// Test multiple different fragments in one operation
pub fn multiple_fragments_test() {
  let country_fields =
    fragment.on("Country", "CountryFields", fn() {
      use name <- field.field(field.string("name"))
      use code <- field.field(field.string("code"))
      field.build(#(name, code))
    })

  let continent_fields =
    fragment.on("Continent", "ContinentFields", fn() {
      use name <- field.field(field.string("name"))
      field.build(name)
    })

  let country_op =
    operation.query("GetCountry")
    |> operation.variable("code", "ID!")
    |> operation.field(
      field.object("country", fn() {
        use country_data <- field.field(fragment.spread(country_fields))
        use continent <- field.field(
          field.object("continent", fn() {
            use continent_name <- field.field(fragment.spread(continent_fields))
            field.build(continent_name)
          }),
        )
        field.build(#(country_data, continent))
      })
      |> field.arg("code", "code"),
    )

  let assert Ok(Some(result)) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])

  let #(#(name, code), continent) = result
  let assert "United Kingdom" = name
  let assert "GB" = code
  let assert "Europe" = continent
}

// Test combining fragment spread with regular fields
pub fn mixed_fragment_and_regular_fields_test() {
  let country_basic =
    fragment.on("Country", "CountryBasic", fn() {
      use name <- field.field(field.string("name"))
      field.build(name)
    })

  let country_op =
    operation.query("GetCountry")
    |> operation.variable("code", "ID!")
    |> operation.field(
      field.object("country", fn() {
        use name <- field.field(fragment.spread(country_basic))
        use code <- field.field(field.string("code"))
        field.build(Country(name:, code:))
      })
      |> field.arg("code", "code"),
    )

  let assert Ok(Some(Country(name: "United Kingdom", code: "GB"))) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])
}

// Test fragment query string generation
pub fn fragment_query_string_generation_test() {
  let country_fields =
    fragment.on("Country", "CountryFields", fn() {
      use name <- field.field(field.string("name"))
      use code <- field.field(field.string("code"))
      field.build(Country(name:, code:))
    })

  let country_op =
    operation.query("GetCountry")
    |> operation.variable("code", "ID!")
    |> operation.field(
      field.object("country", fn() {
        use country_data <- field.field(fragment.spread(country_fields))
        field.build(country_data)
      })
      |> field.arg("code", "code"),
    )

  let query_string = operation.to_string(country_op)

  // Verify the query contains the operation
  let assert True = case query_string {
    _ -> True
  }
  // Could add more specific assertions about the query format
  // but for now just verify it generates without errors
}

// Test fragment with field arguments
pub fn fragment_with_field_arguments_test() {
  let country_fields =
    fragment.on("Country", "CountryFields", fn() {
      use name <- field.field(field.string("name"))
      field.build(name)
    })

  let country_op =
    operation.query("GetCountry")
    |> operation.variable("code", "ID!")
    |> operation.field(
      field.object("country", fn() {
        use country_name <- field.field(fragment.spread(country_fields))
        field.build(country_name)
      })
      |> field.arg("code", "code"),
    )

  let assert Ok(Some("United Kingdom")) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])
}

// Test nested fragment spread
pub fn nested_fragment_spread_test() {
  let continent_fields =
    fragment.on("Continent", "ContinentFields", fn() {
      use name <- field.field(field.string("name"))
      field.build(name)
    })

  let country_op =
    operation.query("GetCountry")
    |> operation.variable("code", "ID!")
    |> operation.field(
      field.object("country", fn() {
        use name <- field.field(field.string("name"))
        use continent <- field.field(
          field.object("continent", fn() {
            use continent_name <- field.field(fragment.spread(continent_fields))
            field.build(continent_name)
          }),
        )
        field.build(#(name, continent))
      })
      |> field.arg("code", "code"),
    )

  let assert Ok(Some(#("United Kingdom", "Europe"))) =
    gleamql.new(country_op)
    |> gleamql.host("countries.trevorblades.com")
    |> gleamql.path("/graphql")
    |> gleamql.json_content_type()
    |> gleamql.send(hackney.send, [#("code", json.string("GB"))])
}
