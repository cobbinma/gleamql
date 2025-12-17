//// GraphQL directive support for fields, fragments, and operations.
////
//// This module provides support for GraphQL directives, which are annotations
//// that can be applied to fields, fragments, and other GraphQL elements to
//// modify their behavior at execution time.
////
//// ## Basic Usage
////
//// ```gleam
//// import gleamql/directive
//// import gleamql/field
////
//// // Use @skip directive to conditionally exclude a field
//// let name_field = 
////   field.string("name")
////   |> field.with_directive(directive.skip("skipName"))
////
//// // Use @include directive to conditionally include a field
//// let email_field =
////   field.string("email")
////   |> field.with_directive(directive.include("includeEmail"))
////
//// // Multiple directives on one field
//// let profile_field =
////   field.string("profile")
////   |> field.with_directive(directive.include("showProfile"))
////   |> field.with_directive(directive.deprecated(Some("Use profileV2 instead")))
//// ```
////
//// ## Built-in Directives
////
//// GraphQL defines several standard directives:
////
//// - **@skip(if: Boolean!)** - Skip field if condition is true
//// - **@include(if: Boolean!)** - Include field if condition is true
//// - **@deprecated(reason: String)** - Mark field as deprecated
//// - **@specifiedBy(url: String!)** - Provide scalar specification URL
////
//// ## Custom Directives
////
//// You can also create custom directives using the `new()` and `with_arg()` functions:
////
//// ```gleam
//// directive.new("customDirective")
//// |> directive.with_arg("arg1", directive.InlineString("value"))
//// |> directive.with_arg("arg2", directive.InlineInt(42))
//// ```
////

import gleam/list
import gleam/option.{type Option}
import gleam/string

// TYPES -----------------------------------------------------------------------

/// Arguments that can be passed to directive parameters.
///
/// This type is defined here to avoid circular dependencies with the field module.
///
pub type DirectiveArgument {
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
  InlineObject(fields: List(#(String, DirectiveArgument)))
  /// An inline list: [item1, item2, ...]
  InlineList(items: List(DirectiveArgument))
}

/// A GraphQL directive that can be applied to fields, fragments, and other elements.
///
/// Directives are prefixed with @ in GraphQL and can have arguments.
/// Example: @skip(if: $shouldSkip)
///
pub opaque type Directive {
  Directive(name: String, arguments: List(#(String, DirectiveArgument)))
}

// CONSTRUCTORS ----------------------------------------------------------------

/// Create a new directive with the given name and no arguments.
///
/// ## Example
///
/// ```gleam
/// let custom = directive.new("myDirective")
/// // Generates: @myDirective
/// ```
///
pub fn new(name: String) -> Directive {
  Directive(name: name, arguments: [])
}

/// Add an argument to a directive.
///
/// Arguments can be inline values or variable references.
///
/// ## Example
///
/// ```gleam
/// directive.new("customDirective")
/// |> directive.with_arg("limit", directive.InlineInt(10))
/// |> directive.with_arg("filter", directive.Variable("filterVar"))
/// // Generates: @customDirective(limit: 10, filter: $filterVar)
/// ```
///
pub fn with_arg(
  dir: Directive,
  arg_name: String,
  arg_value: DirectiveArgument,
) -> Directive {
  let Directive(name: name, arguments: args) = dir
  Directive(name: name, arguments: [#(arg_name, arg_value), ..args])
}

// BUILT-IN DIRECTIVES ---------------------------------------------------------

/// Create a @skip directive that conditionally excludes a field.
///
/// The @skip directive is one of the standard GraphQL directives. When the
/// condition evaluates to true, the field is excluded from the response.
///
/// ## Example
///
/// ```gleam
/// field.string("name")
/// |> field.with_directive(directive.skip("shouldSkipName"))
/// // Generates: name @skip(if: $shouldSkipName)
/// ```
///
/// You must define the corresponding variable in your operation:
///
/// ```gleam
/// operation.query("GetUser")
/// |> operation.variable("shouldSkipName", "Boolean!")
/// |> operation.field(user_field())
/// ```
///
pub fn skip(variable_name: String) -> Directive {
  Directive(name: "skip", arguments: [#("if", Variable(variable_name))])
}

/// Create a @skip directive with an inline boolean value.
///
/// This variant uses an inline boolean instead of a variable reference.
///
/// ## Example
///
/// ```gleam
/// field.string("name")
/// |> field.with_directive(directive.skip_if(True))
/// // Generates: name @skip(if: true)
/// ```
///
pub fn skip_if(condition: Bool) -> Directive {
  Directive(name: "skip", arguments: [#("if", InlineBool(condition))])
}

/// Create an @include directive that conditionally includes a field.
///
/// The @include directive is one of the standard GraphQL directives. When the
/// condition evaluates to true, the field is included in the response.
///
/// ## Example
///
/// ```gleam
/// field.string("email")
/// |> field.with_directive(directive.include("shouldIncludeEmail"))
/// // Generates: email @include(if: $shouldIncludeEmail)
/// ```
///
/// You must define the corresponding variable in your operation:
///
/// ```gleam
/// operation.query("GetUser")
/// |> operation.variable("shouldIncludeEmail", "Boolean!")
/// |> operation.field(user_field())
/// ```
///
pub fn include(variable_name: String) -> Directive {
  Directive(name: "include", arguments: [#("if", Variable(variable_name))])
}

/// Create an @include directive with an inline boolean value.
///
/// This variant uses an inline boolean instead of a variable reference.
///
/// ## Example
///
/// ```gleam
/// field.string("email")
/// |> field.with_directive(directive.include_if(True))
/// // Generates: email @include(if: true)
/// ```
///
pub fn include_if(condition: Bool) -> Directive {
  Directive(name: "include", arguments: [#("if", InlineBool(condition))])
}

/// Create a @deprecated directive to mark a field as deprecated.
///
/// The @deprecated directive is typically used in schema definitions, but can
/// also be useful for documentation purposes in queries.
///
/// ## Example
///
/// ```gleam
/// directive.deprecated(Some("Use newField instead"))
/// // Generates: @deprecated(reason: "Use newField instead")
///
/// directive.deprecated(None)
/// // Generates: @deprecated
/// ```
///
pub fn deprecated(reason: Option(String)) -> Directive {
  case reason {
    option.Some(r) ->
      Directive(name: "deprecated", arguments: [#("reason", InlineString(r))])
    option.None -> Directive(name: "deprecated", arguments: [])
  }
}

/// Create a @specifiedBy directive to reference a scalar specification.
///
/// The @specifiedBy directive provides a URL to the specification of a custom scalar.
///
/// ## Example
///
/// ```gleam
/// directive.specified_by("https://tools.ietf.org/html/rfc3339")
/// // Generates: @specifiedBy(url: "https://tools.ietf.org/html/rfc3339")
/// ```
///
pub fn specified_by(url: String) -> Directive {
  Directive(name: "specifiedBy", arguments: [#("url", InlineString(url))])
}

// SERIALIZATION ---------------------------------------------------------------

/// Convert a directive to its GraphQL string representation.
///
/// This is used internally to generate the GraphQL query string.
///
/// ## Example
///
/// ```gleam
/// directive.to_string(directive.skip("var"))
/// // Returns: "@skip(if: $var)"
///
/// directive.to_string(directive.include_if(true))
/// // Returns: "@include(if: true)"
/// ```
///
pub fn to_string(dir: Directive) -> String {
  let Directive(name: name, arguments: args) = dir

  let args_string = case args {
    [] -> ""
    args -> {
      let formatted_args =
        args
        |> list.reverse()
        |> list.map(fn(arg) {
          let #(key, value) = arg
          key <> ": " <> argument_to_string(value)
        })
        |> string.join(", ")
      "(" <> formatted_args <> ")"
    }
  }

  "@" <> name <> args_string
}

/// Convert a DirectiveArgument to its GraphQL string representation.
///
fn argument_to_string(arg: DirectiveArgument) -> String {
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

// FFI for string conversion
@external(erlang, "erlang", "integer_to_binary")
@external(javascript, "../gleam_stdlib.mjs", "to_string")
fn int_to_string(i: Int) -> String

@external(erlang, "gleam_stdlib", "float_to_string")
@external(javascript, "../gleam_stdlib.mjs", "float_to_string")
fn float_to_string(f: Float) -> String

// ACCESSORS -------------------------------------------------------------------

/// Get the name of a directive.
///
pub fn name(dir: Directive) -> String {
  dir.name
}

/// Get the arguments of a directive.
///
pub fn arguments(dir: Directive) -> List(#(String, DirectiveArgument)) {
  dir.arguments
}
