import gleam/io
import gleamql/field
import gleamql/operation

pub type Country {
  Country(name: String, code: String)
}

pub type Continent {
  Continent(name: String, code: String)
}

pub fn main() {
  // Demonstrate multiple root fields
  let multi_op =
    operation.query("GetCountryAndContinent")
    |> operation.variable("countryCode", "ID!")
    |> operation.variable("continentCode", "ID!")
    |> operation.root(fn() {
      use country <- field.field(
        field.object("country", fn() {
          use name <- field.field(field.string("name"))
          use code <- field.field(field.string("code"))
          field.build(Country(name:, code:))
        })
        |> field.arg("code", "countryCode"),
      )
      use continent <- field.field(
        field.object("continent", fn() {
          use name <- field.field(field.string("name"))
          use code <- field.field(field.string("code"))
          field.build(Continent(name:, code:))
        })
        |> field.arg("code", "continentCode"),
      )
      field.build(#(country, continent))
    })

  // Print the generated GraphQL query
  io.println("Generated GraphQL Query:")
  io.println(operation.to_string(multi_op))
  io.println("")
  io.println(
    "Notice: No wrapper field! Both 'country' and 'continent' are at the root level.",
  )
}
