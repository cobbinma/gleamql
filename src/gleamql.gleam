import gleam/http/request
import gleam/http/response
import gleam/dynamic.{Decoder, Dynamic, field}
import gleam/http.{Post}
import gleam/json.{Json, object}
import gleam/option.{None, Option, Some}
import gleam/result
import gleam/list

pub type Request(t) {
  Request(
    http_request: request.Request(String),
    query: Option(String),
    variables: Option(List(#(String, Json))),
    decoder: Option(Decoder(t)),
  )
}

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

pub fn new() -> Request(t) {
  Request(
    http_request: request.new()
    |> request.set_method(Post),
    query: None,
    variables: None,
    decoder: None,
  )
}

pub fn set_query(req: Request(t), query: String) -> Request(t) {
  Request(..req, query: Some(query))
}

pub fn set_variable(req: Request(t), key: String, value: Json) -> Request(t) {
  let variables = [
    #(key, value),
    ..req.variables
    |> option.unwrap(list.new())
  ]

  Request(..req, variables: Some(variables))
}

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

  try resp =
    request
    |> send
    |> result.map_error(fn(e) { UnknownError(inner: dynamic.from(e)) })

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

pub fn set_host(req: Request(t), host: String) -> Request(t) {
  Request(
    ..req,
    http_request: req.http_request
    |> request.set_host(host),
  )
}

pub fn set_path(req: Request(t), path: String) -> Request(t) {
  Request(
    ..req,
    http_request: req.http_request
    |> request.set_path(path),
  )
}

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

pub fn decode(req: Request(t), decoder: dynamic.Decoder(t)) -> Request(t) {
  Request(..req, decoder: Some(decoder))
}
