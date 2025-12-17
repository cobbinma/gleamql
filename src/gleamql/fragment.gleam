//// Fragment definitions for reusable GraphQL field selections.
////
//// This module provides support for GraphQL fragments, allowing you to define
//// reusable sets of fields that can be included in multiple queries and mutations.
////
//// ## Basic Usage
////
//// ```gleam
//// import gleamql/fragment
//// import gleamql/field
////
//// // Define a reusable fragment
//// let user_fields = 
////   fragment.on("User", "UserFields", fn() {
////     use id <- field.field(field.id("id"))
////     use name <- field.field(field.string("name"))
////     use email <- field.field(field.string("email"))
////     field.build(User(id:, name:, email:))
////   })
////
//// // Use in a query
//// operation.query("GetUsers")
//// |> operation.fragment(user_fields)
//// |> operation.field(
////   field.object("users", fn() {
////     field.field(fragment.spread(user_fields))
////   })
//// )
//// ```
////

import gleam/dynamic/decode.{type Decoder}
import gleam/list
import gleamql/directive.{type Directive}
import gleamql/field.{type Field, type ObjectBuilder}

// TYPES -----------------------------------------------------------------------

/// A named GraphQL fragment that can be reused across queries.
///
/// Fragments define a set of fields on a specific GraphQL type and can be
/// spread into selection sets using the `spread()` function.
///
pub opaque type Fragment(a) {
  Fragment(
    name: String,
    type_condition: String,
    directives: List(Directive),
    selection: String,
    decoder: Decoder(a),
  )
}

// CONSTRUCTORS ----------------------------------------------------------------

/// Create a named fragment with a type condition.
///
/// Fragments allow you to define reusable sets of fields for a specific type.
/// The fragment can then be spread into multiple places in your queries.
///
/// ## Example
///
/// ```gleam
/// pub type User {
///   User(id: String, name: String, email: String)
/// }
///
/// let user_fields = 
///   fragment.on("User", "UserFields", fn() {
///     use id <- field.field(field.id("id"))
///     use name <- field.field(field.string("name"))
///     use email <- field.field(field.string("email"))
///     field.build(User(id:, name:, email:))
///   })
/// ```
///
/// This generates:
/// ```graphql
/// fragment UserFields on User {
///   id
///   name
///   email
/// }
/// ```
///
pub fn on(
  type_condition: String,
  name: String,
  builder: fn() -> ObjectBuilder(a),
) -> Fragment(a) {
  let object_builder = builder()
  let selection = field.object_builder_to_selection(object_builder)
  let decoder = field.object_builder_decoder(object_builder)

  Fragment(
    name: name,
    type_condition: type_condition,
    directives: [],
    selection: selection,
    decoder: decoder,
  )
}

// SPREADS ---------------------------------------------------------------------

/// Create a fragment spread field that can be used in object builders.
///
/// This function converts a fragment into a field that spreads the fragment's
/// fields into the selection set. The resulting field can be used with
/// `field.field()` in object builders.
///
/// The fragment definition is automatically included in the operation's
/// fragment list, so you no longer need to manually call `operation.fragment()`.
///
/// ## Example
///
/// ```gleam
/// field.object("user", fn() {
///   use user_data <- field.field(fragment.spread(user_fields))
///   field.build(user_data)
/// })
/// ```
///
/// This generates:
/// ```graphql
/// user {
///   ...UserFields
/// }
/// ```
///
pub fn spread(fragment: Fragment(a)) -> Field(a) {
  field.from_fragment_spread_with_directives(
    fragment.name,
    fragment.decoder,
    to_definition(fragment),
    fragment.directives,
  )
}

/// Add a directive to a fragment spread.
///
/// Directives on fragment spreads control whether the fragment is included
/// in the query at execution time.
///
/// ## Example
///
/// ```gleam
/// import gleamql/directive
///
/// let user_fields = fragment.on("User", "UserFields", fn() {
///   use id <- field.field(field.id("id"))
///   use name <- field.field(field.string("name"))
///   field.build(User(id:, name:))
/// })
///
/// // Add directive to the fragment spread
/// let conditional_user = fragment.with_directive(
///   user_fields,
///   directive.include("includeUser")
/// )
///
/// // Use in a field
/// field.object("data", fn() {
///   use user <- field.field(fragment.spread(conditional_user))
///   field.build(user)
/// })
/// // Generates: data { ...UserFields @include(if: $includeUser) }
/// ```
///
pub fn with_directive(frag: Fragment(a), dir: Directive) -> Fragment(a) {
  let Fragment(
    name: name,
    type_condition: type_cond,
    directives: dirs,
    selection: sel,
    decoder: dec,
  ) = frag

  Fragment(
    name: name,
    type_condition: type_cond,
    directives: [dir, ..dirs],
    selection: sel,
    decoder: dec,
  )
}

/// Add multiple directives to a fragment spread at once.
///
/// ## Example
///
/// ```gleam
/// import gleamql/directive
///
/// fragment.with_directives(user_fields, [
///   directive.include("showUser"),
///   directive.skip("hideUser"),
/// ])
/// ```
///
pub fn with_directives(frag: Fragment(a), dirs: List(Directive)) -> Fragment(a) {
  let Fragment(
    name: name,
    type_condition: type_cond,
    directives: existing_dirs,
    selection: sel,
    decoder: dec,
  ) = frag

  Fragment(
    name: name,
    type_condition: type_cond,
    directives: list.append(dirs, existing_dirs),
    selection: sel,
    decoder: dec,
  )
}

// ACCESSORS -------------------------------------------------------------------

/// Get the fragment definition as a GraphQL string.
///
/// This generates the fragment definition that will be included in the
/// operation's query string.
///
/// ## Example
///
/// ```gleam
/// fragment.to_definition(user_fields)
/// // Returns: "fragment UserFields on User { id name email }"
/// ```
///
pub fn to_definition(fragment: Fragment(a)) -> String {
  "fragment "
  <> fragment.name
  <> " on "
  <> fragment.type_condition
  <> " { "
  <> fragment.selection
  <> " }"
}

/// Get the fragment name.
///
pub fn name(fragment: Fragment(a)) -> String {
  fragment.name
}

/// Get the fragment's type condition.
///
pub fn type_condition(fragment: Fragment(a)) -> String {
  fragment.type_condition
}

/// Get the decoder for the fragment.
///
pub fn decoder(fragment: Fragment(a)) -> Decoder(a) {
  fragment.decoder
}
