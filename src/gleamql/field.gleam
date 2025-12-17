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
//// ## Inline Fragments
////
//// Inline fragments allow you to conditionally select fields based on type
//// or to group fields together with directives.
////
//// ```gleam
//// // Querying a union type
//// field.object("search", fn() {
////   use user <- field.field(field.inline_on("User", fn() {
////     use name <- field.field(field.string("name"))
////     field.build(name)
////   }))
////   field.build(user)
//// })
//// // Generates: search { ... on User { name } }
////
//// // Grouping fields with directives
//// field.inline(builder)
//// |> field.with_directive(directive.include("var"))
//// ```
////

import gleam/dynamic/decode.{type Decoder}
import gleam/list
import gleam/option.{type Option}
import gleam/string
import gleamql/directive.{type Directive}

// TYPES -----------------------------------------------------------------------

/// A Field represents a GraphQL field with its selection set and decoder.
/// 
/// The Field type keeps the GraphQL selection string and the response decoder
/// synchronized, ensuring they can never get out of sync.
///
pub opaque type Field(a) {
  Field(
    name: String,
    alias: Option(String),
    args: List(#(String, Argument)),
    directives: List(Directive),
    selection: SelectionSet,
    decoder: Decoder(a),
    fragments: List(String),
  )
}

/// The selection set for a field - either a scalar (leaf) or object (nested fields).
///
pub type SelectionSet {
  /// A scalar field with no nested selection (e.g., name, id, count)
  Scalar
  /// An object field with nested field selections
  Object(fields: String)
  /// A fragment spread: ...FragmentName
  FragmentSpread(name: String)
  /// An inline fragment: ... on TypeName { fields } or ... { fields }
  InlineFragment(type_condition: Option(String), fields: String)
  /// A phantom root for multiple root-level fields.
  /// This selection type exists only in the builder - it renders its children
  /// directly without wrapping them in a named field.
  PhantomRoot(fields: String)
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
  Field(
    name: name,
    alias: option.None,
    args: [],
    directives: [],
    selection: Scalar,
    decoder: decode.string,
    fragments: [],
  )
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
  Field(
    name: name,
    alias: option.None,
    args: [],
    directives: [],
    selection: Scalar,
    decoder: decode.int,
    fragments: [],
  )
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
  Field(
    name: name,
    alias: option.None,
    args: [],
    directives: [],
    selection: Scalar,
    decoder: decode.float,
    fragments: [],
  )
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
  Field(
    name: name,
    alias: option.None,
    args: [],
    directives: [],
    selection: Scalar,
    decoder: decode.bool,
    fragments: [],
  )
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
  Field(
    name: name,
    alias: option.None,
    args: [],
    directives: [],
    selection: Scalar,
    decoder: decode.string,
    fragments: [],
  )
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
  let Field(
    name: name,
    alias: alias,
    args: args,
    directives: directives,
    selection: selection,
    decoder: dec,
    fragments: fragments,
  ) = field

  Field(
    name: name,
    alias: alias,
    args: args,
    directives: directives,
    selection: selection,
    decoder: decode.optional(dec),
    fragments: fragments,
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
  let Field(
    name: name,
    alias: alias,
    args: args,
    directives: directives,
    selection: selection,
    decoder: dec,
    fragments: fragments,
  ) = field

  Field(
    name: name,
    alias: alias,
    args: args,
    directives: directives,
    selection: selection,
    decoder: decode.list(dec),
    fragments: fragments,
  )
}

// OBJECT BUILDER --------------------------------------------------------------

/// Internal type for building object field selections.
///
pub opaque type ObjectBuilder(a) {
  ObjectBuilder(
    fields: List(String),
    decoder: Decoder(a),
    fragments: List(String),
  )
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
  let ObjectBuilder(fields: fields, decoder: dec, fragments: frags) = builder()

  let fields_string = string.join(fields, " ")

  // Don't wrap the decoder here - let field.field() or operation root do it
  Field(
    name: name,
    alias: option.None,
    args: [],
    directives: [],
    selection: Object(fields_string),
    decoder: dec,
    fragments: frags,
  )
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
  let field_name = case fld.alias {
    option.Some(alias) -> alias
    option.None -> fld.name
  }
  let field_decoder = fld.decoder
  let field_fragments = fld.fragments

  // The fields list accumulator - we need to evaluate the continuation
  // to get its field list, using a decoder that never actually runs
  let ObjectBuilder(fields: next_fields, fragments: next_fragments, ..) =
    next(placeholder_value())

  // Create a decoder that decodes this field and passes it to the next step
  // Special handling for fragment spreads and inline fragments - they don't have a field wrapper
  let combined_decoder = case fld.selection {
    FragmentSpread(_) -> {
      // Fragment fields are spread inline, so don't wrap in decode.field()
      use value <- decode.then(field_decoder)
      let ObjectBuilder(decoder: next_decoder, ..) = next(value)
      next_decoder
    }
    InlineFragment(_, _) -> {
      // Inline fragment fields are spread inline, so don't wrap in decode.field()
      use value <- decode.then(field_decoder)
      let ObjectBuilder(decoder: next_decoder, ..) = next(value)
      next_decoder
    }
    _ -> {
      // Regular fields need decode.field() wrapper
      use value <- decode.then({
        use dyn <- decode.field(field_name, field_decoder)
        decode.success(dyn)
      })
      let ObjectBuilder(decoder: next_decoder, ..) = next(value)
      next_decoder
    }
  }

  // Collect fragments from this field and all subsequent fields
  let all_fragments = list.append(field_fragments, next_fragments)

  ObjectBuilder(
    fields: [field_selection, ..next_fields],
    decoder: combined_decoder,
    fragments: all_fragments,
  )
}

/// Add a field with an alias to the object being built.
///
/// This function is similar to `field()` but allows you to specify an alias
/// for the field. The alias will be used as the key in the response object.
///
/// ## Example
///
/// ```gleam
/// field.object("user", fn() {
///   use small_pic <- field.field_as("smallPic", 
///     field.string("profilePic") 
///     |> field.arg_int("size", 64))
///   use large_pic <- field.field_as("largePic",
///     field.string("profilePic")
///     |> field.arg_int("size", 1024))
///   field.build(#(small_pic, large_pic))
/// })
/// // Generates: user { smallPic: profilePic(size: 64) largePic: profilePic(size: 1024) }
/// ```
///
pub fn field_as(
  alias: String,
  fld: Field(b),
  next: fn(b) -> ObjectBuilder(a),
) -> ObjectBuilder(a) {
  let aliased_field = Field(..fld, alias: option.Some(alias))
  field(aliased_field, next)
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
  ObjectBuilder(fields: [], decoder: decode.success(value), fragments: [])
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

/// Add a directive to a field.
///
/// Directives modify the behavior of fields at execution time. Common directives
/// include @skip and @include for conditional field inclusion.
///
/// ## Example
///
/// ```gleam
/// import gleamql/directive
///
/// field.string("name")
/// |> field.with_directive(directive.skip("shouldSkipName"))
/// // Generates: name @skip(if: $shouldSkipName)
/// ```
///
/// Multiple directives can be chained:
///
/// ```gleam
/// field.string("email")
/// |> field.with_directive(directive.include("showEmail"))
/// |> field.with_directive(directive.deprecated(Some("Use emailAddress instead")))
/// // Generates: email @include(if: $showEmail) @deprecated(reason: "Use emailAddress instead")
/// ```
///
pub fn with_directive(fld: Field(a), dir: Directive) -> Field(a) {
  let Field(
    name: name,
    alias: alias,
    args: args,
    directives: dirs,
    selection: selection,
    decoder: decoder,
    fragments: fragments,
  ) = fld

  Field(
    name: name,
    alias: alias,
    args: args,
    directives: [dir, ..dirs],
    selection: selection,
    decoder: decoder,
    fragments: fragments,
  )
}

/// Add multiple directives to a field at once.
///
/// This is a convenience function for adding multiple directives in one call.
///
/// ## Example
///
/// ```gleam
/// import gleamql/directive
///
/// field.string("profile")
/// |> field.with_directives([
///   directive.include("showProfile"),
///   directive.deprecated(Some("Use profileV2")),
/// ])
/// ```
///
pub fn with_directives(fld: Field(a), dirs: List(Directive)) -> Field(a) {
  let Field(
    name: name,
    alias: alias,
    args: args,
    directives: existing_dirs,
    selection: selection,
    decoder: decoder,
    fragments: fragments,
  ) = fld

  Field(
    name: name,
    alias: alias,
    args: args,
    directives: list.append(dirs, existing_dirs),
    selection: selection,
    decoder: decoder,
    fragments: fragments,
  )
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
  let Field(
    name: name,
    alias: alias,
    args: args,
    directives: directives,
    selection: selection,
    ..,
  ) = field

  let alias_prefix = case alias {
    option.Some(a) -> a <> ": "
    option.None -> ""
  }

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

  let directives_string = case directives {
    [] -> ""
    dirs -> {
      " "
      <> {
        dirs
        |> list.reverse()
        |> list.map(directive.to_string)
        |> string.join(" ")
      }
    }
  }

  let selection_string = case selection {
    Scalar -> ""
    Object(fields) -> " { " <> fields <> " }"
    FragmentSpread(frag_name) -> "..." <> frag_name
    InlineFragment(type_cond, fields) -> {
      let type_part = case type_cond {
        option.Some(type_name) -> " on " <> type_name
        option.None -> ""
      }
      "..." <> type_part <> directives_string <> " { " <> fields <> " }"
    }
    PhantomRoot(fields) -> fields
  }

  // For fragment spreads, inline fragments, and phantom roots, directives have special placement
  case selection {
    PhantomRoot(fields) -> fields
    FragmentSpread(_) -> alias_prefix <> selection_string <> directives_string
    InlineFragment(_, _) -> alias_prefix <> selection_string
    // directives already included in selection_string
    _ ->
      alias_prefix
      <> name
      <> args_string
      <> directives_string
      <> selection_string
  }
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
/// This is used internally to generate GraphQL query strings and is also
/// exposed for use by the directive module.
///
pub fn argument_to_string(arg: Argument) -> String {
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

// FRAGMENT SUPPORT ------------------------------------------------------------

/// Create a field from a fragment spread (internal use by fragment module).
///
/// This creates a field that represents a fragment spread (...FragmentName)
/// in the GraphQL query. The field has an empty name since fragment spreads
/// don't have field names.
///
pub fn from_fragment_spread(
  fragment_name: String,
  fragment_decoder: Decoder(a),
) -> Field(a) {
  Field(
    name: "",
    alias: option.None,
    args: [],
    directives: [],
    selection: FragmentSpread(fragment_name),
    decoder: fragment_decoder,
    fragments: [],
  )
}

/// Create a field from a fragment spread with the fragment definition (internal use by fragment module).
///
pub fn from_fragment_spread_with_definition(
  fragment_name: String,
  fragment_decoder: Decoder(a),
  fragment_definition: String,
) -> Field(a) {
  Field(
    name: "",
    alias: option.None,
    args: [],
    directives: [],
    selection: FragmentSpread(fragment_name),
    decoder: fragment_decoder,
    fragments: [fragment_definition],
  )
}

/// Create a field from a fragment spread with directives (internal use by fragment module).
///
pub fn from_fragment_spread_with_directives(
  fragment_name: String,
  fragment_decoder: Decoder(a),
  fragment_definition: String,
  fragment_directives: List(Directive),
) -> Field(a) {
  Field(
    name: "",
    alias: option.None,
    args: [],
    directives: fragment_directives,
    selection: FragmentSpread(fragment_name),
    decoder: fragment_decoder,
    fragments: [fragment_definition],
  )
}

/// Get the fragments used by this field (internal use).
///
pub fn fragments(field: Field(a)) -> List(String) {
  field.fragments
}

/// Extract the selection string from an ObjectBuilder (internal use).
///
/// This is used by the fragment module to get the field selection string
/// from an ObjectBuilder.
///
pub fn object_builder_to_selection(builder: ObjectBuilder(a)) -> String {
  let ObjectBuilder(fields: fields, ..) = builder
  string.join(fields, " ")
}

/// Get the decoder from an ObjectBuilder (internal use).
///
pub fn object_builder_decoder(builder: ObjectBuilder(a)) -> Decoder(a) {
  let ObjectBuilder(decoder: dec, ..) = builder
  dec
}

// INLINE FRAGMENTS ------------------------------------------------------------

/// Create an inline fragment with a type condition.
///
/// Inline fragments with type conditions are used to select fields based on
/// the runtime type of an interface or union field. This is essential for
/// querying polymorphic types in GraphQL.
///
/// ## Example - Querying a union type
///
/// ```gleam
/// // GraphQL schema:
/// // union SearchResult = User | Post | Comment
/// 
/// field.object("search", fn() {
///   use user_result <- field.field(
///     field.inline_on("User", fn() {
///       use name <- field.field(field.string("name"))
///       use email <- field.field(field.string("email"))
///       field.build(UserResult(name:, email:))
///     })
///   )
///   use post_result <- field.field(
///     field.inline_on("Post", fn() {
///       use title <- field.field(field.string("title"))
///       field.build(PostResult(title:))
///     })
///   )
///   field.build(SearchResults(user: user_result, post: post_result))
/// })
/// // Generates: search { ... on User { name email } ... on Post { title } }
/// ```
///
/// ## Example - Querying an interface type
///
/// ```gleam
/// field.object("node", fn() {
///   use common_id <- field.field(field.id("id"))
///   use user_fields <- field.field(
///     field.inline_on("User", fn() {
///       use name <- field.field(field.string("name"))
///       field.build(name)
///     })
///   )
///   field.build(#(common_id, user_fields))
/// })
/// // Generates: node { id ... on User { name } }
/// ```
///
pub fn inline_on(
  type_condition: String,
  builder: fn() -> ObjectBuilder(a),
) -> Field(a) {
  let object_builder = builder()
  let selection = object_builder_to_selection(object_builder)
  let decoder = object_builder_decoder(object_builder)

  Field(
    name: "",
    alias: option.None,
    args: [],
    directives: [],
    selection: InlineFragment(
      type_condition: option.Some(type_condition),
      fields: selection,
    ),
    decoder: decoder,
    fragments: [],
  )
}

/// Create an inline fragment without a type condition.
///
/// Inline fragments without type conditions are used to group fields together,
/// typically to apply directives to multiple fields at once without affecting
/// the parent type condition.
///
/// ## Example - Grouping fields with directives
///
/// ```gleam
/// field.object("user", fn() {
///   use name <- field.field(field.string("name"))
///   use private_data <- field.field(
///     field.inline(fn() {
///       use email <- field.field(field.string("email"))
///       use phone <- field.field(field.string("phone"))
///       field.build(#(email, phone))
///     })
///     |> field.with_directive(directive.include("showPrivate"))
///   )
///   field.build(User(name:, private: private_data))
/// })
/// // Generates: user { name ... @include(if: $showPrivate) { email phone } }
/// ```
///
pub fn inline(builder: fn() -> ObjectBuilder(a)) -> Field(a) {
  let object_builder = builder()
  let selection = object_builder_to_selection(object_builder)
  let decoder = object_builder_decoder(object_builder)

  Field(
    name: "",
    alias: option.None,
    args: [],
    directives: [],
    selection: InlineFragment(type_condition: option.None, fields: selection),
    decoder: decoder,
    fragments: [],
  )
}

// PHANTOM ROOT ----------------------------------------------------------------

/// Create a phantom root field for multiple root-level selections.
///
/// **Internal use only** - Users should use `operation.root()` instead.
///
/// A phantom root exists only in the builder API. When rendered to GraphQL,
/// its child fields are output directly at the operation level without any
/// wrapper field. This enables type-safe multiple root field operations.
///
/// ## Example
///
/// ```gleam
/// // Internal usage (via operation.root):
/// let phantom = field.phantom_root(fn() {
///   use user <- field.field(user_field())
///   use posts <- field.field(posts_field())
///   field.build(#(user, posts))
/// })
/// ```
///
/// Generates: `user { ... } posts { ... }` (no wrapper)
///
pub fn phantom_root(builder: fn() -> ObjectBuilder(a)) -> Field(a) {
  let ObjectBuilder(fields: fields, decoder: dec, fragments: frags) = builder()
  let fields_string = string.join(fields, " ")

  Field(
    name: "",
    alias: option.None,
    args: [],
    directives: [],
    selection: PhantomRoot(fields_string),
    decoder: dec,
    fragments: frags,
  )
}

/// Check if a field is a phantom root.
///
/// Phantom roots are used internally by `operation.root()` to support
/// multiple root fields while maintaining type safety.
///
/// ## Example
///
/// ```gleam
/// let phantom = field.phantom_root(builder)
/// field.is_phantom_root(phantom)  // -> True
///
/// let regular = field.object("user", builder)
/// field.is_phantom_root(regular)  // -> False
/// ```
///
pub fn is_phantom_root(field: Field(a)) -> Bool {
  case field.selection {
    PhantomRoot(_) -> True
    _ -> False
  }
}
