# gleamql

[![Package Version](https://img.shields.io/hexpm/v/gleamql)](https://hex.pm/packages/gleamql)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gleamql/)

Simple Graphql Client Written In Gleam ✨

## Installation

```gleam
import gleamql
import gleam/json.{string}
import gleam/dynamic.{field}

pub type Data {
  Data(country: Country)
}

pub type Country {
  Country(name: String)
}

pub fn main() {
  assert Ok(resp) =
    graphql.new()
    |> graphql.set_query(
      "query CountryQuery($code: ID!) {
  country(code: $code) {
    name
  }
}",
    )
    |> graphql.set_variable("code", string("GB"))
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
          dynamic.decode1(Country, field("name", of: dynamic.string))(country)
        },
      ),
    )(
      resp,
    )

  assert "United Kingdom" = data.country.name
}
```

## Installation

If available on Hex this package can be added to your Gleam project:

```sh
gleam add graphql
```

and its documentation can be found at <https://hexdocs.pm/gleeql>.
