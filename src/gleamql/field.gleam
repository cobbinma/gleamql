//// Field builders for constructing GraphQL field selections with synchronized decoders.
////
//// This module provides the core building blocks for constructing GraphQL queries
//// and mutations while ensuring the query structure and response decoder stay in sync.
////
//// ## Basic Usage
////
//// ```gleam
//// import gleamql/field
////
//// // Simple scalar field
//// let name_field = field.string("name")
////
//// // List of strings
//// let tags_field = field.list(field.string("tags"))
////
//// // Optional field
//// let nickname_field = field.optional(field.string("nickname"))
//// ```
////

import gleam/dynamic/decode.{type Decoder}
import gleam/list
import gleam/option.{type Option}
import gleam/string

// TYPES -----------------------------------------------------------------------

/// A Field represents a GraphQL field with its selection set and decoder.
/// 
/// The Field type keeps the GraphQL selection string and the response decoder
/// synchronized, ensuring they can never get out of sync.
///
pub opaque type Field(a) {
  Field(
    name: String,
    args: List(#(String, Argument)),
    selection: SelectionSet,
    decoder: Decoder(a),
  )
}

/// The selection set for a field - either a scalar (leaf) or object (nested fields).
///
pub type SelectionSet {
  /// A scalar field with no nested selection (e.g., name, id, count)
  Scalar
  /// An object field with nested field selections
  Object(fields: String)
}

/// Arguments that can be passed to GraphQL fields.
///
/// Supports both variables (defined in the operation) and inline literal values.
///
pub type Argument {
  /// A reference to a variable: $variableName
  Variable(name: String)
  /// An inline string literal: "value"
  InlineString(value: String)
  /// An inline integer literal: 42
  InlineInt(value: Int)
  /// An inline float literal: 3.14
  InlineFloat(value: Float)
  /// An inline boolean literal: true or false
  InlineBool(value: Bool)
  /// An inline null value
  InlineNull
  /// An inline object: { key: value, ... }
  InlineObject(fields: List(#(String, Argument)))
  /// An inline list: [item1, item2, ...]
  InlineList(items: List(Argument))
}

// SCALAR FIELDS ---------------------------------------------------------------

/// Create a String field.
///
/// ## Example
///
/// ```gleam
/// let name_field = field.string("name")
/// // Generates: name
/// // Decodes: String
/// ```
///
pub fn string(name: String) -> Field(String) {
  Field(name: name, args: [], selection: Scalar, decoder: decode.string)
}

/// Create an Int field.
///
/// ## Example
///
/// ```gleam
/// let age_field = field.int("age")
/// // Generates: age
/// // Decodes: Int
/// ```
///
pub fn int(name: String) -> Field(Int) {
  Field(name: name, args: [], selection: Scalar, decoder: decode.int)
}

/// Create a Float field.
///
/// ## Example
///
/// ```gleam
/// let price_field = field.float("price")
/// // Generates: price
/// // Decodes: Float
/// ```
///
pub fn float(name: String) -> Field(Float) {
  Field(name: name, args: [], selection: Scalar, decoder: decode.float)
}

/// Create a Bool field.
///
/// ## Example
///
/// ```gleam
/// let active_field = field.bool("isActive")
/// // Generates: isActive
/// // Decodes: Bool
/// ```
///
pub fn bool(name: String) -> Field(Bool) {
  Field(name: name, args: [], selection: Scalar, decoder: decode.bool)
}

/// Create an ID field (decoded as String).
///
/// GraphQL IDs are always decoded as strings, even if they look like numbers.
///
/// ## Example
///
/// ```gleam
/// let id_field = field.id("id")
/// // Generates: id
/// // Decodes: String
/// ```
///
pub fn id(name: String) -> Field(String) {
  Field(name: name, args: [], selection: Scalar, decoder: decode.string)
}

// CONTAINER TYPES -------------------------------------------------------------

/// Wrap a field as optional (nullable in GraphQL).
///
/// GraphQL fields can be nullable. This function wraps a field's decoder
/// to handle null values, returning `None` for null and `Some(value)` for present values.
///
/// ## Example
///
/// ```gleam
/// let nickname_field = field.optional(field.string("nickname"))
/// // Generates: nickname
/// // Decodes: Option(String)
/// ```
///
pub fn optional(field: Field(a)) -> Field(Option(a)) {
  let Field(name: name, args: args, selection: selection, decoder: dec) = field

  Field(
    name: name,
    args: args,
    selection: selection,
    decoder: decode.optional(dec),
  )
}

/// Wrap a field as a list.
///
/// GraphQL lists are decoded as Gleam lists. The inner field's decoder
/// is applied to each item in the list.
///
/// ## Example
///
/// ```gleam
/// let tags_field = field.list(field.string("tags"))
/// // Generates: tags
/// // Decodes: List(String)
/// ```
///
/// You can also combine with optional:
///
/// ```gleam
/// // List of optional strings
/// let items_field = field.list(field.optional(field.string("items")))
/// // Decodes: List(Option(String))
///
/// // Optional list of strings
/// let maybe_tags_field = field.optional(field.list(field.string("tags")))
/// // Decodes: Option(List(String))
/// ```
///
pub fn list(field: Field(a)) -> Field(List(a)) {
  let Field(name: name, args: args, selection: selection, decoder: dec) = field

  Field(name: name, args: args, selection: selection, decoder: decode.list(dec))
}

// OBJECT BUILDER --------------------------------------------------------------

/// Internal type for building object field selections.
///
pub opaque type ObjectBuilder(a) {
  ObjectBuilder(fields: List(String), decoder: Decoder(a))
}

/// Build an object field with multiple nested fields using a codec-style builder.
///
/// This is the core function for building GraphQL object selections. It uses
/// a continuation-passing style with `use` expressions to build up both the
/// field selection string and the decoder simultaneously.
///
/// ## Example
///
/// ```gleam
/// pub type Country {
///   Country(name: String, code: String)
/// }
///
/// fn country_field() {
///   field.object("country", fn() {
///     use name <- field.field(field.string("name"))
///     use code <- field.field(field.string("code"))
///     field.build(Country(name:, code:))
///   })
/// }
/// // Generates: country { name code }
/// // Decodes: Country
/// ```
///
/// For nested objects:
///
/// ```gleam
/// pub type Data {
///   Data(country: Country)
/// }
///
/// fn data_field() {
///   field.object("data", fn() {
///     use country <- field.field(country_field())
///     field.build(Data(country:))
///   })
/// }
/// // Generates: data { country { name code } }
/// ```
///
pub fn object(name: String, builder: fn() -> ObjectBuilder(a)) -> Field(a) {
  let ObjectBuilder(fields: fields, decoder: dec) = builder()

  let fields_string = string.join(fields, " ")

  // Don't wrap the decoder here - let field.field() or operation root do it
  Field(name: name, args: [], selection: Object(fields_string), decoder: dec)
}

/// Add a field to the object being built.
///
/// This function is designed to be used with the `use` keyword to chain
/// multiple fields together in a codec-style builder.
///
/// ## Example
///
/// ```gleam
/// field.object("person", fn() {
///   use name <- field.field(field.string("name"))
///   use age <- field.field(field.int("age"))
///   field.build(Person(name:, age:))
/// })
/// ```
///
pub fn field(fld: Field(b), next: fn(b) -> ObjectBuilder(a)) -> ObjectBuilder(a) {
  let field_selection = to_selection(fld)
  let field_name = fld.name
  let field_decoder = fld.decoder

  // The fields list accumulator - we need to evaluate the continuation
  // to get its field list, using a decoder that never actually runs
  let ObjectBuilder(fields: next_fields, ..) = next(placeholder_value())

  // Create a decoder that decodes this field and passes it to the next step
  let combined_decoder = {
    use value <- decode.then({
      use dyn <- decode.field(field_name, field_decoder)
      decode.success(dyn)
    })
    let ObjectBuilder(decoder: next_decoder, ..) = next(value)
    next_decoder
  }

  ObjectBuilder(
    fields: [field_selection, ..next_fields],
    decoder: combined_decoder,
  )
}

/// Complete the object with a constructor.
///
/// This is the final step in building an object field. It takes the
/// constructed value and wraps it in a field.
///
/// ## Example
///
/// ```gleam
/// field.object("country", fn() {
///   use name <- field.field(field.string("name"))
///   field.build(Country(name:))  // <- Complete with constructor
/// })
/// ```
///
pub fn build(value: a) -> ObjectBuilder(a) {
  ObjectBuilder(fields: [], decoder: decode.success(value))
}

/// Create a placeholder value for extracting field lists.
///
/// This uses FFI to return `undefined` which can be passed to constructors
/// without being evaluated. Pure Gleam alternatives like `panic` don't work
/// because they execute immediately when passed to record constructors.
///
/// This is safe because:
/// 1. The placeholder is only used on line 285 to extract the field list structure
/// 2. It's passed through the continuation chain to build() at line 318
/// 3. build() creates decode.success(value) but never actually runs the decoder
/// 4. The placeholder never escapes to user code or actual decoding operations
///
/// Why FFI is necessary:
/// - `panic` executes immediately in expressions like `Country(name: panic)`
/// - Gleam has no lazy evaluation or thunks for delaying panic
/// - `undefined` in Erlang/JS can be stored in data structures without evaluation
/// - No pure Gleam alternative exists for non-strict placeholder values
///
@external(erlang, "gleamql_ffi", "placeholder")
@external(javascript, "../../gleamql_ffi.mjs", "placeholder")
fn placeholder_value() -> a

// FIELD ARGUMENTS -------------------------------------------------------------

/// Add multiple arguments to a field.
///
/// ## Example
///
/// ```gleam
/// field.object("posts", posts_builder)
/// |> field.with_args([
///   #("first", Variable("limit")),
///   #("after", InlineString("cursor123")),
/// ])
/// // Generates: posts(first: $limit, after: "cursor123") { ... }
/// ```
///
pub fn with_args(fld: Field(a), args: List(#(String, Argument))) -> Field(a) {
  Field(..fld, args: args)
}

/// Add a single variable argument to a field.
///
/// This is a helper for the common case of passing a variable to a field.
///
/// ## Example
///
/// ```gleam
/// field.object("country", country_builder)
/// |> field.arg("code", "code")
/// // Generates: country(code: $code) { ... }
/// ```
///
pub fn arg(fld: Field(a), arg_name: String, var_name: String) -> Field(a) {
  let new_args = [#(arg_name, Variable(var_name)), ..fld.args]
  Field(..fld, args: new_args)
}

/// Add an inline string argument to a field.
///
/// ## Example
///
/// ```gleam
/// field.object("country", country_builder)
/// |> field.arg_string("code", "GB")
/// // Generates: country(code: "GB") { ... }
/// ```
///
pub fn arg_string(fld: Field(a), arg_name: String, value: String) -> Field(a) {
  let new_args = [#(arg_name, InlineString(value)), ..fld.args]
  Field(..fld, args: new_args)
}

/// Add an inline int argument to a field.
///
/// ## Example
///
/// ```gleam
/// field.object("posts", posts_builder)
/// |> field.arg_int("first", 10)
/// // Generates: posts(first: 10) { ... }
/// ```
///
pub fn arg_int(fld: Field(a), arg_name: String, value: Int) -> Field(a) {
  let new_args = [#(arg_name, InlineInt(value)), ..fld.args]
  Field(..fld, args: new_args)
}

/// Add an inline float argument to a field.
///
/// ## Example
///
/// ```gleam
/// field.object("products", products_builder)
/// |> field.arg_float("minPrice", 9.99)
/// // Generates: products(minPrice: 9.99) { ... }
/// ```
///
pub fn arg_float(fld: Field(a), arg_name: String, value: Float) -> Field(a) {
  let new_args = [#(arg_name, InlineFloat(value)), ..fld.args]
  Field(..fld, args: new_args)
}

/// Add an inline bool argument to a field.
///
/// ## Example
///
/// ```gleam
/// field.object("posts", posts_builder)
/// |> field.arg_bool("published", True)
/// // Generates: posts(published: true) { ... }
/// ```
///
pub fn arg_bool(fld: Field(a), arg_name: String, value: Bool) -> Field(a) {
  let new_args = [#(arg_name, InlineBool(value)), ..fld.args]
  Field(..fld, args: new_args)
}

/// Add an inline object argument to a field.
///
/// This is commonly used for mutation input objects.
///
/// ## Example
///
/// ```gleam
/// field.object("createPost", create_post_builder)
/// |> field.arg_object("input", [
///   #("title", InlineString("My Post")),
///   #("body", InlineString("Content here")),
/// ])
/// // Generates: createPost(input: { title: "My Post", body: "Content here" }) { ... }
/// ```
///
pub fn arg_object(
  fld: Field(a),
  arg_name: String,
  fields: List(#(String, Argument)),
) -> Field(a) {
  let new_args = [#(arg_name, InlineObject(fields)), ..fld.args]
  Field(..fld, args: new_args)
}

/// Add an inline list argument to a field.
///
/// ## Example
///
/// ```gleam
/// field.object("users", users_builder)
/// |> field.arg_list("ids", [InlineString("1"), InlineString("2")])
/// // Generates: users(ids: ["1", "2"]) { ... }
/// ```
///
pub fn arg_list(
  fld: Field(a),
  arg_name: String,
  items: List(Argument),
) -> Field(a) {
  let new_args = [#(arg_name, InlineList(items)), ..fld.args]
  Field(..fld, args: new_args)
}

// INTERNAL HELPERS ------------------------------------------------------------

/// Build the GraphQL selection string for a field.
///
/// This is an internal function used to generate the actual GraphQL query text.
///
pub fn to_selection(field: Field(a)) -> String {
  let Field(name: name, args: args, selection: selection, ..) = field

  let args_string = case args {
    [] -> ""
    args -> {
      let formatted_args =
        args
        |> list.map(fn(arg) {
          let #(key, value) = arg
          key <> ": " <> argument_to_string(value)
        })
        |> string.join(", ")
      "(" <> formatted_args <> ")"
    }
  }

  let selection_string = case selection {
    Scalar -> ""
    Object(fields) -> " { " <> fields <> " }"
  }

  name <> args_string <> selection_string
}

/// Get the decoder for a field.
///
pub fn decoder(field: Field(a)) -> Decoder(a) {
  field.decoder
}

/// Get the field name.
///
pub fn name(field: Field(a)) -> String {
  field.name
}

// ARGUMENT SERIALIZATION ------------------------------------------------------

/// Convert an Argument to its GraphQL string representation.
///
fn argument_to_string(arg: Argument) -> String {
  case arg {
    Variable(name) -> "$" <> name
    InlineString(value) -> "\"" <> escape_string(value) <> "\""
    InlineInt(value) -> int_to_string(value)
    InlineFloat(value) -> float_to_string(value)
    InlineBool(True) -> "true"
    InlineBool(False) -> "false"
    InlineNull -> "null"
    InlineObject(fields) -> {
      let formatted_fields =
        fields
        |> list.map(fn(field) {
          let #(key, value) = field
          key <> ": " <> argument_to_string(value)
        })
        |> string.join(", ")
      "{ " <> formatted_fields <> " }"
    }
    InlineList(items) -> {
      let formatted_items =
        items
        |> list.map(argument_to_string)
        |> string.join(", ")
      "[" <> formatted_items <> "]"
    }
  }
}

/// Escape special characters in strings for GraphQL.
///
fn escape_string(value: String) -> String {
  value
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
  |> string.replace("\r", "\\r")
  |> string.replace("\t", "\\t")
}

// These are imported from gleam/int and gleam/float in actual stdlib
// Using external FFI for proper conversion
@external(erlang, "erlang", "integer_to_binary")
@external(javascript, "../gleam_stdlib.mjs", "to_string")
fn int_to_string(i: Int) -> String

@external(erlang, "gleam_stdlib", "float_to_string")
@external(javascript, "../gleam_stdlib.mjs", "float_to_string")
fn float_to_string(f: Float) -> String
