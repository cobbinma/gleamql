import gleam/dynamic/decode
import gleam/hackney
import gleam/json
import gleam/option.{Some}
import gleamql
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub type Data {
  Data(country: Country)
}

pub type Country {
  Country(name: String)
}

const country_query = "query CountryQuery($code: ID!) {
  country(code: $code) {
    name
  }
}"

pub fn country_query_test() {
  let assert Ok(Some(Data(country: Country(name: "United Kingdom")))) =
    gleamql.new()
    |> gleamql.set_query(country_query)
    |> gleamql.set_variable("code", json.string("GB"))
    |> gleamql.set_host("countries.trevorblades.com")
    |> gleamql.set_path("/graphql")
    |> gleamql.set_default_content_type_header()
    |> gleamql.set_decoder({
      use country <- decode.field("country", {
        use name <- decode.field("name", decode.string)
        decode.success(Country(name:))
      })
      decode.success(Data(country:))
    })
    |> gleamql.send(hackney.send)
}

pub fn invalid_query_test() {
  let assert Error(gleamql.ErrorMessage(
    "Variable \"$code\" of required type \"ID!\" was not provided.",
  )) =
    gleamql.new()
    |> gleamql.set_query(country_query)
    |> gleamql.set_variable("invalid", json.string("invalid"))
    |> gleamql.set_host("countries.trevorblades.com")
    |> gleamql.set_path("/graphql")
    |> gleamql.set_default_content_type_header()
    |> gleamql.send(hackney.send)
}

pub fn method_not_allowed_test() {
  let assert Error(gleamql.UnexpectedStatus(405)) =
    gleamql.new()
    |> gleamql.set_query(country_query)
    |> gleamql.set_variable("code", json.string("GB"))
    |> gleamql.set_host("google.com")
    |> gleamql.set_default_content_type_header()
    |> gleamql.send(hackney.send)
}

pub fn invalid_header_content_type_test() {
  let assert Error(gleamql.UnexpectedStatus(415)) =
    gleamql.new()
    |> gleamql.set_query(country_query)
    |> gleamql.set_variable("code", json.string("GB"))
    |> gleamql.set_host("countries.trevorblades.com")
    |> gleamql.set_path("/graphql")
    |> gleamql.set_header("Content-Type", "text/html")
    |> gleamql.send(hackney.send)
}

pub fn mutation_test() {
  let assert Ok(_) =
    gleamql.new()
    |> gleamql.set_query(
      "mutation (
  $input: CreatePostInput!
) {
  createPost(input: $input) {
    id
  }
}",
    )
    |> gleamql.set_variable(
      "input",
      json.object([
        #("title", json.string("A Very Captivating Post Title")),
        #("body", json.string("Some interesting content.")),
      ]),
    )
    |> gleamql.set_host("graphqlzero.almansi.me")
    |> gleamql.set_path("/api")
    |> gleamql.set_header("Content-Type", "application/json")
    |> gleamql.send(hackney.send)
}
