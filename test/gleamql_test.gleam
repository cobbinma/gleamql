import gleeunit
import gleamql
import gleam/json
import gleam/dynamic.{field, string}

pub fn main() {
  gleeunit.main()
}

const country_query = "query CountryQuery($code: ID!) {
  country(code: $code) {
    name
  }
}"

pub type Data {
  Data(country: Country)
}

pub type Country {
  Country(name: String)
}

pub fn country_query_test() {
  assert Ok(resp) =
    gleamql.new()
    |> gleamql.set_query(country_query)
    |> gleamql.set_variable("code", json.string("GB"))
    |> gleamql.set_host("countries.trevorblades.com")
    |> gleamql.set_path("/graphql")
    |> gleamql.set_header("Content-Type", "application/json")
    |> gleamql.send()

  assert Ok(Data(country: Country(name: "United Kingdom"))) =
    resp
    |> dynamic.decode1(
      Data,
      field(
        "country",
        of: fn(country) {
          country
          |> dynamic.decode1(Country, field("name", of: string))
        },
      ),
    )
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
    |> gleamql.send()
}

pub fn method_not_allowed_test() {
  assert Error(gleamql.UnexpectedStatus(405)) =
    gleamql.new()
    |> gleamql.set_query(country_query)
    |> gleamql.set_variable("code", json.string("GB"))
    |> gleamql.set_host("google.com")
    |> gleamql.send()
}

pub fn invalid_server_test() {
  assert Error(gleamql.UnknownError(_)) =
    gleamql.new()
    |> gleamql.set_query(country_query)
    |> gleamql.set_variable("code", json.string("GB"))
    |> gleamql.set_host("unknown")
    |> gleamql.send()
}
