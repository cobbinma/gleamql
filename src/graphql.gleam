import gleam/http/request
import gleam/dynamic.{Dynamic, field}
import gleam/hackney
import gleam/http.{Post}
import gleam/json.{Json, object}
import gleam/option.{None, Option, Some}
import gleam/result
import gleam/list

pub type Request {
  Request(
    http_request: request.Request(String),
    query: Option(String),
    variables: Option(List(#(String, Json))),
  )
}

type Response {
  Response(data: Dynamic)
}

pub fn new() -> Request {
  Request(
    http_request: request.new()
    |> request.set_method(Post),
    query: None,
    variables: None,
  )
}

pub fn set_query(req: Request, query: String) -> Request {
  Request(..req, query: Some(query))
}

pub fn set_variable(req: Request, key: String, value: Json) -> Request {
  let variables = [
    #(key, value),
    ..req.variables
    |> option.unwrap(list.new())
  ]

  Request(..req, variables: Some(variables))
}

pub fn send(req: Request) -> Result(Dynamic, Dynamic) {
  let req =
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
    hackney.send(req)
    |> result.map_error(fn(e) { dynamic.from(e) })

  let response_decoder =
    dynamic.decode1(Response, field("data", of: dynamic.dynamic))

  assert Ok(response) =
    json.decode(from: resp.body, using: response_decoder)
    |> result.map_error(fn(e) { dynamic.from(e) })

  Ok(response.data)
}

pub fn set_host(req: Request, host: String) -> Request {
  Request(
    ..req,
    http_request: req.http_request
    |> request.set_host(host),
  )
}

pub fn set_path(req: Request, path: String) -> Request {
  Request(
    ..req,
    http_request: req.http_request
    |> request.set_path(path),
  )
}

pub fn set_header(req: Request, key: String, value: String) -> Request {
  Request(
    ..req,
    http_request: req.http_request
    |> request.set_header(key, value),
  )
}
