# gleamql

[![Package Version](https://img.shields.io/hexpm/v/gleamql)](https://hex.pm/packages/gleamql)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gleamql/)

A Simple Graphql Client Written In Gleam ✨

## Usage

```gleam
import gleamql
import gleam/json.{string}
import gleam/dynamic/decode
import gleam/option.{Some}
import gleam/hackney

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
```

## Installation

If available on Hex this package can be added to your Gleam project:

```sh
gleam add gleamql
```

and its documentation can be found at <https://hexdocs.pm/gleamql>.
