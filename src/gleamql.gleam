//// Query a GraphQL server with `gleamql`.
////
//// This library provides a type-safe way to build GraphQL queries and mutations
//// while ensuring the query structure and response decoder stay synchronized.
////
//// ## Example
////
//// ```gleam
//// import gleamql
//// import gleamql/field
//// import gleamql/operation
//// import gleam/json
//// import gleam/hackney
////
//// pub type Country {
////   Country(name: String)
//// }
////
//// pub fn main() {
////   let country_op = 
////     operation.query("CountryQuery")
////     |> operation.variable("code", "ID!")
////     |> operation.field(
////       field.object("country", fn() {
////         use name <- field.field(field.string("name"))
////         field.build(Country(name:))
////       })
////       |> field.arg("code", "code")
////     )
////
////   let assert Ok(Some(Country(name: "United Kingdom"))) =
////     gleamql.new(country_op)
////     |> gleamql.host("countries.trevorblades.com")
////     |> gleamql.path("/graphql")
////     |> gleamql.json_content_type()
////     |> gleamql.send(hackney.send, [
////       #("code", json.string("GB"))
////     ])
//// }
//// ```
////

import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/http.{type Scheme, Post}
import gleam/http/request
import gleam/http/response.{type Response}
import gleam/json.{type Json, object}
import gleam/option.{type Option, None, Some}
import gleam/result
import gleamql/operation.{type Operation}

/// GleamQL Request
///
pub type Request(t) {
  Request(http_request: request.Request(String), operation: Operation(t))
}

/// Errors that can occur when sending a GraphQL request.
///
/// The error type is generic over the HTTP client error type, preserving
/// all error information from the underlying HTTP client.
///
pub type Error(http_error) {
  /// Network-level failure (timeout, connection refused, DNS issues, etc.).
  /// Preserves the original HTTP client error for full context.
  NetworkError(http_error)

  /// Server returned a non-2xx HTTP status code.
  /// Includes the status code and response body for debugging.
  HttpError(status: Int, body: String)

  /// GraphQL server returned one or more errors in the response.
  /// Even with errors, GraphQL typically returns 200 OK with error objects.
  /// This variant contains ALL errors returned by the server.
  GraphQLErrors(List(GraphQLError))

  /// Response body wasn't valid JSON.
  /// Includes the JSON decode error and response body for debugging.
  InvalidJson(json.DecodeError, body: String)

  /// JSON was valid but didn't match the expected GraphQL response structure.
  /// Includes the decode errors and response body for debugging.
  DecodeError(List(decode.DecodeError), body: String)
}

/// A GraphQL error as defined in the GraphQL specification (Section 7.1.2).
///
/// GraphQL servers may return multiple errors in a single response. Each error
/// includes a message and optionally includes path and extensions fields.
///
pub type GraphQLError {
  GraphQLError(
    /// Human-readable error message
    message: String,
    /// Path to the field that caused the error (can contain strings or integers).
    /// Use gleam/dynamic to decode the path segments as needed.
    path: Option(List(Dynamic)),
    /// Additional error information (server-specific).
    /// Use gleam/dynamic to decode the extensions as needed.
    extensions: Option(Dynamic),
  )
}

/// Construct a GleamQL Request with an operation.
///
/// ## Example
///
/// ```gleam
/// gleamql.new(country_operation)
/// |> gleamql.host("api.example.com")
/// |> gleamql.path("/graphql")
/// |> gleamql.json_content_type()
/// |> gleamql.send(hackney.send, [#("code", json.string("GB"))])
/// ```
///
pub fn new(op: Operation(t)) -> Request(t) {
  Request(
    http_request: request.new() |> request.set_method(Post),
    operation: op,
  )
}

/// Set the host of the request.
///
/// ## Example
///
/// ```gleam
/// gleamql.host(req, "api.example.com")
/// ```
///
pub fn host(req: Request(t), host: String) -> Request(t) {
  Request(..req, http_request: req.http_request |> request.set_host(host))
}

/// Set the path of the request.
///
/// ## Example
///
/// ```gleam
/// gleamql.path(req, "/graphql")
/// ```
///
pub fn path(req: Request(t), path: String) -> Request(t) {
  Request(..req, http_request: req.http_request |> request.set_path(path))
}

/// Set a header on the request.
///
/// If already present, it is replaced.
///
/// ## Example
///
/// ```gleam
/// gleamql.header(req, "Authorization", "Bearer token123")
/// ```
///
pub fn header(req: Request(t), key: String, value: String) -> Request(t) {
  Request(
    ..req,
    http_request: req.http_request |> request.set_header(key, value),
  )
}

/// Set the `Content-Type` header to `application/json`.
///
/// This is required by most GraphQL servers.
///
/// ## Example
///
/// ```gleam
/// gleamql.json_content_type(req)
/// ```
///
pub fn json_content_type(req: Request(t)) -> Request(t) {
  Request(
    ..req,
    http_request: req.http_request
      |> request.set_header("Content-Type", "application/json"),
  )
}

/// Set the schema of the request (http or https).
///
/// ## Example
///
/// ```gleam
/// import gleam/http
/// gleamql.scheme(req, http.Https)
/// ```
///
pub fn scheme(req: Request(t), scheme: Scheme) -> Request(t) {
  Request(..req, http_request: req.http_request |> request.set_scheme(scheme))
}

/// Send the built request to a GraphQL server with variable values.
///
/// A HTTP client is needed to send the request, see https://github.com/gleam-lang/http#client-adapters.
///
/// ## Example
///
/// ```gleam
/// import gleam/hackney
/// import gleam/json
///
/// gleamql.send(request, hackney.send, [
///   #("code", json.string("GB")),
///   #("lang", json.string("en")),
/// ])
/// ```
///
/// Variable values must be provided as a list of name/JSON pairs. The names
/// should match the variables defined in the operation.
///
/// Returns `Ok(Some(data))` if the query succeeded and returned data,
/// `Ok(None)` if the query succeeded but returned null, or an `Error` if
/// the request failed at any level (network, HTTP, GraphQL, or decoding).
///
pub fn send(
  req: Request(t),
  http_send: fn(request.Request(String)) -> Result(response.Response(String), e),
  variables: List(#(String, Json)),
) -> Result(Option(t), Error(e)) {
  // Build the request body
  let query_string = operation.to_string(req.operation)
  let variables_json = operation.build_variables(req.operation, variables)

  let request =
    req.http_request
    |> request.set_body(
      object([
        #("query", json.string(query_string)),
        #("variables", variables_json),
      ])
      |> json.to_string,
    )

  // Send the request
  use resp <- result.try(
    request
    |> http_send
    |> result.map_error(NetworkError),
  )

  // Handle the response
  case status_is_ok(resp.status) {
    True -> handle_status_ok(req, resp)
    False -> handle_status_not_ok(resp)
  }
}

fn handle_status_ok(
  req: Request(t),
  resp: Response(String),
) -> Result(Option(t), Error(e)) {
  // First, check if the response contains GraphQL errors
  // GraphQL can return errors even with 200 status
  case decode_graphql_errors(resp.body) {
    Ok(errors) -> Error(GraphQLErrors(errors))
    Error(_) -> {
      // No errors, try to decode the data
      // Check if the data field exists and is not null
      case decode_optional_data(req, resp.body) {
        Ok(opt_value) -> Ok(opt_value)
        Error(decode_errors) -> Error(DecodeError(decode_errors, resp.body))
      }
    }
  }
}

// Decode the response, handling null data field
fn decode_optional_data(
  req: Request(t),
  body: String,
) -> Result(Option(t), List(decode.DecodeError)) {
  // Try to decode using the operation decoder (which expects data field)
  // If it fails, it could be because data is null or missing
  case json.parse(from: body, using: operation.decoder(req.operation)) {
    Ok(value) -> Ok(Some(value))
    Error(json.UnableToDecode(errors)) -> {
      // Check if the error is because data is null/missing
      // Try to parse just to check if data field exists and is null
      case is_data_null(body) {
        True -> Ok(None)
        False -> Error(errors)
      }
    }
    Error(_other_json_error) -> {
      // For other JSON errors (malformed JSON, etc), still return error
      // but we need to create a generic decode error
      Error([
        decode.DecodeError(
          expected: "valid JSON",
          found: "malformed JSON",
          path: [],
        ),
      ])
    }
  }
}

// Check if the response has a null data field
fn is_data_null(body: String) -> Bool {
  let decoder = {
    use opt_data <- decode.optional_field(
      "data",
      option.None,
      decode.optional(decode.dynamic),
    )
    decode.success(opt_data)
  }

  case json.parse(from: body, using: decoder) {
    Ok(option.None) -> True
    _ -> False
  }
}

fn handle_status_not_ok(resp: Response(String)) -> Result(Option(t), Error(e)) {
  // Try to decode GraphQL errors from the response
  case decode_graphql_errors(resp.body) {
    Ok(errors) -> Error(GraphQLErrors(errors))
    Error(_) -> Error(HttpError(status: resp.status, body: resp.body))
  }
}

fn decode_graphql_errors(body: String) -> Result(List(GraphQLError), Nil) {
  let decoder = {
    use errors <- decode.field(
      "errors",
      decode.list({
        use message <- decode.field("message", decode.string)
        use path <- decode.optional_field(
          "path",
          option.None,
          decode.optional(decode.list(decode.dynamic)),
        )
        use extensions <- decode.optional_field(
          "extensions",
          option.None,
          decode.optional(decode.dynamic),
        )
        decode.success(GraphQLError(message:, path:, extensions:))
      }),
    )
    decode.success(errors)
  }

  json.parse(from: body, using: decoder)
  |> result.replace_error(Nil)
}

fn status_is_ok(status: Int) -> Bool {
  status == 200
}
