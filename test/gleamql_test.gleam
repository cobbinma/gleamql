import gleeunit
import gleamql
import gleam/json
import gleam/dynamic.{field, string}
import gleam/option.{Some}
import gleam/hackney

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
  assert Ok(Some(Data(country: Country(name: "United Kingdom")))) =
    gleamql.new()
    |> gleamql.set_query(country_query)
    |> gleamql.set_variable("code", json.string("GB"))
    |> gleamql.set_host("countries.trevorblades.com")
    |> gleamql.set_path("/graphql")
    |> gleamql.set_header("Content-Type", "application/json")
    |> gleamql.set_decoder(dynamic.decode1(
      Data,
      field(
        "country",
        of: fn(country) {
          country
          |> dynamic.decode1(Country, field("name", of: string))
        },
      ),
    ))
    |> gleamql.send(hackney.send)
}

pub fn invalid_query_test() {
  assert Error(gleamql.ErrorMessage(
    "Variable \"$code\" of required type \"ID!\" was not provided.",
  )) =
    gleamql.new()
    |> gleamql.set_query(country_query)
    |> gleamql.set_variable("invalid", json.string("invalid"))
    |> gleamql.set_host("countries.trevorblades.com")
    |> gleamql.set_path("/graphql")
    |> gleamql.set_header("Content-Type", "application/json")
    |> gleamql.send(hackney.send)
}

pub fn method_not_allowed_test() {
  assert Error(gleamql.UnexpectedStatus(405)) =
    gleamql.new()
    |> gleamql.set_query(country_query)
    |> gleamql.set_variable("code", json.string("GB"))
    |> gleamql.set_host("google.com")
    |> gleamql.send(hackney.send)
}

pub fn invalid_server_test() {
  assert Error(gleamql.UnknownError(_)) =
    gleamql.new()
    |> gleamql.set_query(country_query)
    |> gleamql.set_variable("code", json.string("GB"))
    |> gleamql.set_host("unknown")
    |> gleamql.send(hackney.send)
}

pub fn mutation_test() {
  assert Ok(_) =
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
