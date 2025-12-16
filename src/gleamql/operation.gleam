//// Operation builders for constructing GraphQL queries and mutations.
////
//// This module provides functions for building complete GraphQL operations
//// with variable definitions and root fields.
////
//// ## Basic Usage
////
//// ```gleam
//// import gleamql/operation
//// import gleamql/field
////
//// let country_op = 
////   operation.query("CountryQuery")
////   |> operation.variable("code", "ID!")
////   |> operation.field(country_field())
////   |> operation.build()
//// ```
////

import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleamql/field.{type Field}

// TYPES -----------------------------------------------------------------------

/// A complete GraphQL operation (query or mutation) with its decoder.
///
pub opaque type Operation(a) {
  Operation(
    operation_type: OperationType,
    name: Option(String),
    variables: List(VariableDef),
    root_field: Field(a),
    query_string: String,
    variables_list: List(String),
  )
}

/// The type of GraphQL operation.
///
pub type OperationType {
  Query
  Mutation
}

/// A variable definition for a GraphQL operation.
///
pub type VariableDef {
  VariableDef(name: String, type_def: String)
}

/// Builder for constructing operations.
///
pub opaque type OperationBuilder(a) {
  OperationBuilder(
    operation_type: OperationType,
    name: Option(String),
    variables: List(VariableDef),
  )
}

// CONSTRUCTORS ----------------------------------------------------------------

/// Create a named query operation.
///
/// ## Example
///
/// ```gleam
/// operation.query("GetCountry")
/// |> operation.variable("code", "ID!")
/// |> operation.field(country_field())
/// |> operation.build()
/// ```
///
pub fn query(name: String) -> OperationBuilder(a) {
  OperationBuilder(operation_type: Query, name: Some(name), variables: [])
}

/// Create a named mutation operation.
///
/// ## Example
///
/// ```gleam
/// operation.mutation("CreatePost")
/// |> operation.variable("input", "CreatePostInput!")
/// |> operation.field(create_post_field())
/// |> operation.build()
/// ```
///
pub fn mutation(name: String) -> OperationBuilder(a) {
  OperationBuilder(operation_type: Mutation, name: Some(name), variables: [])
}

/// Create an anonymous query operation.
///
/// Anonymous operations have no name and are useful for simple queries.
///
/// ## Example
///
/// ```gleam
/// operation.anonymous_query()
/// |> operation.field(countries_field())
/// |> operation.build()
/// ```
///
pub fn anonymous_query() -> OperationBuilder(a) {
  OperationBuilder(operation_type: Query, name: None, variables: [])
}

/// Create an anonymous mutation operation.
///
/// ## Example
///
/// ```gleam
/// operation.anonymous_mutation()
/// |> operation.field(create_post_field())
/// |> operation.build()
/// ```
///
pub fn anonymous_mutation() -> OperationBuilder(a) {
  OperationBuilder(operation_type: Mutation, name: None, variables: [])
}

// BUILDERS --------------------------------------------------------------------

/// Add a variable definition to the operation.
///
/// Variables allow you to parameterize your operations and reuse them
/// with different values.
///
/// ## Example
///
/// ```gleam
/// operation.query("GetCountry")
/// |> operation.variable("code", "ID!")  // Non-null ID
/// |> operation.variable("lang", "String")  // Optional String
/// ```
///
/// The type definition should be a valid GraphQL type:
/// - Scalars: `"String"`, `"Int"`, `"Float"`, `"Boolean"`, `"ID"`
/// - Non-null: `"String!"`, `"ID!"`
/// - Lists: `"[String]"`, `"[ID!]!"` 
/// - Custom types: `"CreatePostInput!"`, `"[UserInput!]"`
///
pub fn variable(
  builder: OperationBuilder(a),
  name: String,
  type_def: String,
) -> OperationBuilder(a) {
  let OperationBuilder(operation_type: op_type, name: op_name, variables: vars) =
    builder

  let new_var = VariableDef(name: name, type_def: type_def)

  OperationBuilder(operation_type: op_type, name: op_name, variables: [
    new_var,
    ..vars
  ])
}

/// Set the root field for the operation and build the final Operation.
///
/// This completes the operation builder and generates the GraphQL query string.
///
/// ## Example
///
/// ```gleam
/// operation.query("GetCountry")
/// |> operation.variable("code", "ID!")
/// |> operation.field(country_field())
/// |> operation.build()
/// ```
///
pub fn field(builder: OperationBuilder(a), root_field: Field(a)) -> Operation(a) {
  let OperationBuilder(operation_type: op_type, name: op_name, variables: vars) =
    builder

  // Generate the query string
  let query_string = build_query_string(op_type, op_name, vars, root_field)

  // Extract variable names for the request
  let variables_list =
    vars
    |> list.map(fn(var) { var.name })

  Operation(
    operation_type: op_type,
    name: op_name,
    variables: vars,
    root_field: root_field,
    query_string: query_string,
    variables_list: variables_list,
  )
}

/// Alias for `field` that builds the operation.
///
pub fn build(operation: Operation(a)) -> Operation(a) {
  operation
}

// QUERY GENERATION ------------------------------------------------------------

/// Build the complete GraphQL query string.
///
fn build_query_string(
  op_type: OperationType,
  op_name: Option(String),
  vars: List(VariableDef),
  root_field: Field(a),
) -> String {
  let operation_keyword = case op_type {
    Query -> "query"
    Mutation -> "mutation"
  }

  let name_part = case op_name {
    Some(name) -> " " <> name
    None -> ""
  }

  let variables_part = case vars {
    [] -> ""
    vars -> {
      let vars_string =
        vars
        |> list.reverse()
        |> list.map(fn(var) { "$" <> var.name <> ": " <> var.type_def })
        |> string.join(", ")
      "(" <> vars_string <> ")"
    }
  }

  let selection = field.to_selection(root_field)

  operation_keyword <> name_part <> variables_part <> " { " <> selection <> " }"
}

// ACCESSORS -------------------------------------------------------------------

/// Get the GraphQL query string from an operation.
///
pub fn to_string(operation: Operation(a)) -> String {
  operation.query_string
}

/// Get the decoder from an operation.
///
/// This decoder will automatically unwrap the "data" field from the
/// GraphQL response.
///
pub fn decoder(operation: Operation(a)) -> Decoder(a) {
  // Auto-unwrap the "data" field, then decode the root field by name
  let root_field_name = field.name(operation.root_field)
  let root_field_decoder = field.decoder(operation.root_field)

  use data_value <- decode.field("data", {
    use field_value <- decode.field(root_field_name, root_field_decoder)
    decode.success(field_value)
  })
  decode.success(data_value)
}

/// Get the list of variable names defined in the operation.
///
/// This is useful for knowing which variables need values at send time.
///
pub fn variable_names(operation: Operation(a)) -> List(String) {
  operation.variables_list
}

/// Build the variables JSON object for the GraphQL request.
///
/// Takes a list of variable name/value pairs and constructs the
/// variables object to send with the request.
///
pub fn build_variables(
  _operation: Operation(a),
  values: List(#(String, Json)),
) -> Json {
  json.object(values)
}
