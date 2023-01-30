# gleamql

[![Package Version](https://img.shields.io/hexpm/v/gleamql)](https://hex.pm/packages/gleamql)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gleamql/)

A Simple Graphql Client Written In Gleam ✨

## Usage

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

const country_query = "query CountryQuery($code: ID!) {
  country(code: $code) {
    name
  }
}"

pub fn main() {
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
```

## Installation

If available on Hex this package can be added to your Gleam project:

```sh
gleam add gleamql
```

and its documentation can be found at <https://hexdocs.pm/gleamql>.
