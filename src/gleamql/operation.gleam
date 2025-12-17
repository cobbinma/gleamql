//// Operation builders for constructing GraphQL queries and mutations.
////
//// This module provides functions for building complete GraphQL operations
//// with variable definitions and root fields. It supports both single and
//// multiple root field operations.
////
//// ## Basic Usage - Single Root Field
////
//// ```gleam
//// import gleamql/operation
//// import gleamql/field
////
//// let country_op = 
////   operation.query("CountryQuery")
////   |> operation.variable("code", "ID!")
////   |> operation.field(country_field())
//// ```
////
//// ## Multiple Root Fields
////
//// Query multiple fields at the root level while maintaining type safety:
////
//// ```gleam
//// operation.query("GetDashboard")
//// |> operation.variable("userId", "ID!")
//// |> operation.root(fn() {
////   use user <- field.field(user_field())
////   use posts <- field.field(posts_field())
////   use stats <- field.field(stats_field())
////   field.build(#(user, posts, stats))
//// })
//// ```
////
//// This generates clean GraphQL without wrapper fields:
//// ```graphql
//// query GetDashboard($userId: ID!) {
////   user { ... }
////   posts { ... }
////   stats { ... }
//// }
//// ```
////

import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleamql/field.{type Field}
import gleamql/fragment

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
    fragments: List(String),
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
    fragments: List(String),
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
  OperationBuilder(
    operation_type: Query,
    name: Some(name),
    variables: [],
    fragments: [],
  )
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
  OperationBuilder(
    operation_type: Mutation,
    name: Some(name),
    variables: [],
    fragments: [],
  )
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
  OperationBuilder(
    operation_type: Query,
    name: None,
    variables: [],
    fragments: [],
  )
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
  OperationBuilder(
    operation_type: Mutation,
    name: None,
    variables: [],
    fragments: [],
  )
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
  let OperationBuilder(
    operation_type: op_type,
    name: op_name,
    variables: vars,
    fragments: frags,
  ) = builder

  let new_var = VariableDef(name: name, type_def: type_def)

  OperationBuilder(
    operation_type: op_type,
    name: op_name,
    variables: [new_var, ..vars],
    fragments: frags,
  )
}

/// Add a fragment definition to the operation (optional).
///
/// **Note:** As of version 1.0.0, fragments are automatically collected when
/// you use `fragment.spread()`, so this function is **optional**. You only need
/// to use it if you want to explicitly register a fragment that isn't used in
/// the current operation's fields.
///
/// For most use cases, simply use `fragment.spread()` in your field selections
/// and the fragment will be automatically included.
///
/// ## Example (modern approach - auto-collection)
///
/// ```gleam
/// import gleamql/fragment
///
/// let user_fields = fragment.on("User", "UserFields", fn() {
///   use id <- field.field(field.id("id"))
///   use name <- field.field(field.string("name"))
///   field.build(User(id:, name:))
/// })
///
/// // No need to call operation.fragment() - it's auto-collected!
/// operation.query("GetUser")
/// |> operation.variable("id", "ID!")
/// |> operation.field(
///   field.object("user", fn() {
///     use user_data <- field.field(fragment.spread(user_fields))
///     field.build(user_data)
///   })
/// )
/// ```
///
/// ## Example (legacy approach - manual registration)
///
/// ```gleam
/// // You can still manually register if needed
/// operation.query("GetUser")
/// |> operation.fragment(user_fields)  // Optional - for backwards compatibility
/// |> operation.variable("id", "ID!")
/// |> operation.field(user_field())
/// ```
///
pub fn fragment(
  builder: OperationBuilder(a),
  frag: fragment.Fragment(b),
) -> OperationBuilder(a) {
  let OperationBuilder(
    operation_type: op_type,
    name: op_name,
    variables: vars,
    fragments: frags,
  ) = builder

  let frag_def = fragment.to_definition(frag)

  OperationBuilder(
    operation_type: op_type,
    name: op_name,
    variables: vars,
    fragments: [frag_def, ..frags],
  )
}

/// Set the root field for the operation and build the final Operation.
///
/// This completes the operation builder and generates the GraphQL query string.
/// Fragments used in the field tree are automatically collected and included
/// in the operation.
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
  let OperationBuilder(
    operation_type: op_type,
    name: op_name,
    variables: vars,
    fragments: manual_frags,
  ) = builder

  // Collect fragments from the field tree
  let field_frags = field.fragments(root_field)

  // Combine manual fragments (from operation.fragment()) with auto-collected ones
  // Remove duplicates by using list.unique (need to import set or dedupe manually)
  let all_frags = list.append(manual_frags, field_frags) |> dedupe_strings()

  // Generate the query string
  let query_string =
    build_query_string(op_type, op_name, vars, root_field, all_frags)

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
    fragments: all_frags,
  )
}

/// Set multiple root fields for the operation using a builder pattern.
///
/// This allows you to query multiple root fields in a single operation
/// while maintaining full type safety. The builder pattern is identical to
/// `field.object()`, but the generated GraphQL will not wrap the fields
/// in an additional object.
///
/// ## Example
///
/// ```gleam
/// pub type UserAndPosts {
///   UserAndPosts(user: User, posts: List(Post))
/// }
///
/// operation.query("GetData")
/// |> operation.variable("userId", "ID!")
/// |> operation.root(fn() {
///   use user <- field.field(
///     field.object("user", user_builder)
///     |> field.arg("id", "userId")
///   )
///   use posts <- field.field(
///     field.list(field.object("posts", post_builder))
///     |> field.arg_int("limit", 10)
///   )
///   field.build(UserAndPosts(user:, posts:))
/// })
/// ```
///
/// Generates:
/// ```graphql
/// query GetData($userId: ID!) {
///   user(id: $userId) { ... }
///   posts(limit: 10) { ... }
/// }
/// ```
///
/// ## Single Root Field
///
/// You can also use `root()` with a single field (though `field()` is simpler):
///
/// ```gleam
/// operation.root(fn() {
///   use user <- field.field(user_field())
///   field.build(user)
/// })
/// ```
///
/// ## Backward Compatibility
///
/// The existing `field()` function continues to work for single-field operations.
/// Use `root()` when you need multiple root fields or want a consistent API.
///
pub fn root(
  builder: OperationBuilder(_),
  root_builder: fn() -> field.ObjectBuilder(a),
) -> Operation(a) {
  let phantom_field = field.phantom_root(root_builder)

  // The OperationBuilder type parameter is phantom, so we can safely reconstruct
  // it with the correct type by pattern matching and rebuilding
  let OperationBuilder(
    operation_type: op_type,
    name: op_name,
    variables: vars,
    fragments: manual_frags,
  ) = builder

  let typed_builder =
    OperationBuilder(
      operation_type: op_type,
      name: op_name,
      variables: vars,
      fragments: manual_frags,
    )

  field(typed_builder, phantom_field)
}

/// Alias for `field` that builds the operation.
///
pub fn build(operation: Operation(a)) -> Operation(a) {
  operation
}

// QUERY GENERATION ------------------------------------------------------------

/// Deduplicate a list of strings while preserving order.
///
fn dedupe_strings(strings: List(String)) -> List(String) {
  do_dedupe(strings, [])
}

fn do_dedupe(strings: List(String), seen: List(String)) -> List(String) {
  case strings {
    [] -> list.reverse(seen)
    [first, ..rest] -> {
      case list.contains(seen, first) {
        True -> do_dedupe(rest, seen)
        False -> do_dedupe(rest, [first, ..seen])
      }
    }
  }
}

/// Build the complete GraphQL query string.
///
fn build_query_string(
  op_type: OperationType,
  op_name: Option(String),
  vars: List(VariableDef),
  root_field: Field(a),
  fragments: List(String),
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

  let fragments_part = case fragments {
    [] -> ""
    frags -> {
      "\n\n" <> string.join(list.reverse(frags), "\n\n")
    }
  }

  operation_keyword
  <> name_part
  <> variables_part
  <> " { "
  <> selection
  <> " }"
  <> fragments_part
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
  let root_field_decoder = field.decoder(operation.root_field)

  // Check if this is a phantom root (multiple root fields)
  case field.is_phantom_root(operation.root_field) {
    True -> {
      // Phantom root: decode children directly from data object
      // The phantom root's decoder already handles field-by-field decoding
      use data_value <- decode.field("data", root_field_decoder)
      decode.success(data_value)
    }
    False -> {
      // Regular field: decode the named field from data object
      let root_field_name = field.name(operation.root_field)
      use data_value <- decode.field("data", {
        use field_value <- decode.field(root_field_name, root_field_decoder)
        decode.success(field_value)
      })
      decode.success(data_value)
    }
  }
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
