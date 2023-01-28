import gleeunit
import graphql
import gleam/json
import gleam/dynamic.{field, string}

pub fn main() {
  gleeunit.main()
}

const country_query = "query CountryQuery($code: ID!) {
  country(code: $code) {
    name
  }
}
"

pub type Data {
  Data(country: Country)
}

pub type Country {
  Country(name: String)
}

pub fn country_query_test() {
  assert Ok(resp) =
    graphql.new()
    |> graphql.set_query(country_query)
    |> graphql.set_variable("code", json.string("GB"))
    |> graphql.set_host("countries.trevorblades.com")
    |> graphql.set_path("/graphql")
    |> graphql.set_header("Content-Type", "application/json")
    |> graphql.send()

  assert Ok(data) =
    dynamic.decode1(
      Data,
      field(
        "country",
        of: fn(country) {
          dynamic.decode1(Country, field("name", of: string))(country)
        },
      ),
    )(
      resp,
    )

  assert "United Kingdom" = data.country.name
}

pub fn invalid_query_test() {
  assert Error(graphql.ErrorMessage(
    "Variable \"$code\" of required type \"ID!\" was not provided.",
  )) =
    graphql.new()
    |> graphql.set_query(country_query)
    |> graphql.set_variable("invalid", json.string("invalid"))
    |> graphql.set_host("countries.trevorblades.com")
    |> graphql.set_path("/graphql")
    |> graphql.set_header("Content-Type", "application/json")
    |> graphql.send()
}

pub fn method_not_allowed_test() {
  assert Error(graphql.UnexpectedStatus(405)) =
    graphql.new()
    |> graphql.set_query(country_query)
    |> graphql.set_variable("code", json.string("GB"))
    |> graphql.set_host("google.com")
    |> graphql.send()
}

pub fn invalid_server_test() {
  assert Error(graphql.UnknownError(_)) =
    graphql.new()
    |> graphql.set_query(country_query)
    |> graphql.set_variable("code", json.string("GB"))
    |> graphql.set_host("unknown")
    |> graphql.send()
}
