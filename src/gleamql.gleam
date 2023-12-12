//// Query a GraphQL server with `gleamql`.
////
//// ```gleam
//// gleamql.new()
//// |> gleamql.set_query(country_query)
//// |> gleamql.set_variable("code", json.string("GB"))
//// |> gleamql.set_host("countries.trevorblades.com")
//// |> gleamql.set_path("/graphql")
//// |> gleamql.set_header("Content-Type", "application/json")
//// |> gleamql.set_decoder(dynamic.decode1(
////   Data,
////   field("country", of: dynamic.decode1(Country, field("name", of: string))),
//// ))
//// |> gleamql.send(hackney.send)
//// ```
////

import gleam/http/request
import gleam/http/response
import gleam/dynamic.{type Decoder, type Dynamic, field}
import gleam/http.{Post}
import gleam/json.{type Json, object}
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/list

/// GleamQL Request
///
pub type Request(t) {
  Request(
    http_request: request.Request(String),
    query: Option(String),
    variables: Option(List(#(String, Json))),
    decoder: Option(Decoder(t)),
  )
}

/// GleamQL Error
///
pub type GraphQLError {
  ErrorMessage(message: String)
  UnexpectedStatus(status: Int)
  UnrecognisedResponse(response: String)
  UnknownError(inner: Dynamic)
}

type GqlSuccess(t) {
  SuccessResponse(data: t)
}

type GqlErrors {
  ErrorResponse(errors: List(GqlError))
}

type GqlError {
  GqlError(message: String)
}

/// Construct a GleamQL Request
///
/// Use with set functions to customise.
///
pub fn new() -> Request(t) {
  Request(
    http_request: request.new()
    |> request.set_method(Post),
    query: None,
    variables: None,
    decoder: None,
  )
}

/// Set the query of the request
///
pub fn set_query(req: Request(t), query: String) -> Request(t) {
  Request(..req, query: Some(query))
}

/// Set a variable that is needed in the request query
///
/// ```gleam
/// gleamql.set_variable("code", json.string("GB"))
/// ```
///
pub fn set_variable(req: Request(t), key: String, value: Json) -> Request(t) {
  let variables = [
    #(key, value),
    ..req.variables
    |> option.unwrap(list.new())
  ]

  Request(..req, variables: Some(variables))
}

/// Send the built request to a GraphQL server.
///
/// A HTTP client is needed to send the request, see https://github.com/gleam-lang/http#client-adapters.
///
pub fn send(
  req: Request(t),
  send: fn(request.Request(String)) -> Result(response.Response(String), b),
) -> Result(Option(t), GraphQLError) {
  let request =
    req.http_request
    |> request.set_body(
      object([
        #(
          "query",
          req.query
          |> option.unwrap("")
          |> json.string,
        ),
        #(
          "variables",
          object(
            req.variables
            |> option.unwrap(list.new()),
          ),
        ),
      ])
      |> json.to_string,
    )

  use resp <- result.then(
    request
    |> send
    |> result.map_error(fn(e) { UnknownError(inner: dynamic.from(e)) }),
  )

  let errors_decoder =
    dynamic.decode1(
      ErrorResponse,
      field(
        "errors",
        of: dynamic.list(of: dynamic.decode1(
          GqlError,
          field("message", dynamic.string),
        )),
      ),
    )

  case
    resp.status
    |> status_is_ok
  {
    True ->
      case req.decoder {
        Some(decoder) ->
          case
            json.decode(
              from: resp.body,
              using: dynamic.decode1(
                SuccessResponse,
                field("data", of: decoder),
              ),
            )
          {
            Ok(response) -> Ok(Some(response.data))
            Error(_) -> Error(UnrecognisedResponse(response: resp.body))
          }
        None -> Ok(None)
      }
    False ->
      case json.decode(from: resp.body, using: errors_decoder) {
        Ok(response) ->
          case
            response.errors
            |> list.first
          {
            Ok(error) -> Error(ErrorMessage(message: error.message))
            Error(_) -> Error(UnrecognisedResponse(response: resp.body))
          }
        Error(_) -> Error(UnexpectedStatus(resp.status))
      }
  }
}

/// Set the host of the request.
///
/// ```gleam
/// gleamql.set_host("countries.trevorblades.com")
/// ```
///
pub fn set_host(req: Request(t), host: String) -> Request(t) {
  Request(
    ..req,
    http_request: req.http_request
    |> request.set_host(host),
  )
}

/// Set the path of the request.
///
/// ```gleam
/// gleamql.set_path("/graphql")
/// ```
///
pub fn set_path(req: Request(t), path: String) -> Request(t) {
  Request(
    ..req,
    http_request: req.http_request
    |> request.set_path(path),
  )
}

/// Set the header with the given value under the given header key.
///
/// If already present, it is replaced.
///
/// ```gleam
/// gleamql.set_header("Content-Type", "application/json")
/// ```
///
pub fn set_header(req: Request(t), key: String, value: String) -> Request(t) {
  Request(
    ..req,
    http_request: req.http_request
    |> request.set_header(key, value),
  )
}

fn status_is_ok(status: Int) -> Bool {
  status == 200
}

/// Set the decoder that will be used to deserialize the graphql response.
///
/// If not given, the response will not be deserialized.
///
/// ```gleam
/// gleamql.set_decoder(dynamic.decode1(
///   Data,
///   field("country", of: dynamic.decode1(Country, field("name", of: string))),
/// ))
/// ```
///
pub fn set_decoder(req: Request(t), decoder: dynamic.Decoder(t)) -> Request(t) {
  Request(..req, decoder: Some(decoder))
}
