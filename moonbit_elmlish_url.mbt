///|
pub fn fib(n : Int) -> Int64 {
  loop (n, 0L, 1L) {
    (0, _, b) => b
    (i, a, b) => continue (i - 1, b, a + b)
  }
}

///|
/// data is a labelled argument without default value having type Array[Int]
/// start is an optional labelled argument with default value 0 having type Int
/// length is an optional labelled argument without default value having type Option[Int]
pub fn sum(data~ : Array[Int], start? : Int = 0, length? : Int) -> Int {
  let end = if length is Some(length) { start + length } else { data.length() }
  for i = start, sum = 0; i < end; i = i + 1, sum = sum + data[i] {

  } else {
    sum
  }
}

// type Parser a b =
//   Parser (State a -> List (State b))

// type Parser[A, B] = (State[A]) -> Array[State[B]]

///|
struct Parser[In, Out]((State[In]) -> Array[State[Out]])

///|
fn[A, B] Parser::parse(
  self : Parser[A, B],
  state : State[A],
) -> Array[State[B]] {
  let Parser(parseFn) = self
  parseFn(state)
}

///|
priv struct State[Value] {
  visited : Array[String]
  unvisited : Array[String]
  params : Map[String, Array[String]]
  frag : String?
  value : Value
}

// string : Parser (String -> a) a
// string =
//   custom "STRING" Just

// custom : String -> (String -> Maybe a) -> Parser (a -> b) b
// custom tipe stringToSomething =
//   Parser <| \{ visited, unvisited, params, frag, value } ->
//     case unvisited of
//       [] ->
//         []

//       next :: rest ->
//         case stringToSomething next of
//           Just nextValue ->
//             [ State (next :: visited) rest params frag (value nextValue) ]

//           Nothing ->
//             []

///|
fn[A, B] custom(_ : String, f : (String) -> A?) -> Parser[(A) -> B, B] {
  Parser(fn(state) {
    match state.unvisited {
      [] => []
      [next, .. rest] =>
        match f(next) {
          Some(nextValue) =>
            [
              State::{
                visited: [next, ..state.visited],
                unvisited: rest.to_array(),
                params: state.params,
                frag: state.frag,
                value: (state.value)(nextValue),
              },
            ]
          None => []
        }
    }
  })
}

///|
fn[A] string() -> Parser[(String) -> A, A] {
  custom("STRING", Some(_))
}

///|
fn[A] int() -> Parser[(Int) -> A, A] {
  custom("INT", (str : String) => {
    let st = try? @strconv.from_str(str)
    match st {
      Ok(v) => Some(v)
      Err(_) => None
    }
  })
}

///|
fn[A] s(str : String) -> Parser[A, A] {
  Parser(fn(state) {
    match state.unvisited {
      [] => []
      [next, .. rest] =>
        if next == str {
          [
            State::{
              visited: [next, ..state.visited],
              unvisited: rest.to_array(),
              params: state.params,
              frag: state.frag,
              value: state.value,
            },
          ]
        } else {
          []
        }
    }
  })
}

///|
fn[A] top() -> Parser[A, A] {
  Parser(fn(state) { [state] })
}

///|
fn[A, B, C] slash(
  parser1 : Parser[A, B],
  parser2 : Parser[B, C],
) -> Parser[A, C] {
  Parser(fn(state) {
    parser1.parse(state) |> Array::map(_, parser2.parse(_)) |> Array::flatten
  })
}

///|
pub fn p2() -> Unit {
  let u = top()
    |> slash(s("users"))
    |> slash(string())
    |> slash(s("posts"))
    |> slash(int())
    |> map(userId => postId => (userId, postId), _)
  let st = parse(u, "users/alice/posts/123")
  println(st)
  let u2 = s("users") |> slash(_, string()) |> map(userId => userId, _)
  let st2 = parse(u2, "/users/bob")
  println(st2)
}

///|

///|
fn[A, B, C] map(subValue : A, parser : Parser[A, B]) -> Parser[(B) -> C, C] {
  Parser(fn(state) {
    mapState(state.value, _)
    |> Array::map(
      parser.parse(State::{
        visited: state.visited,
        unvisited: state.unvisited,
        params: state.params,
        frag: state.frag,
        value: subValue,
      }),
      _,
    )
  })
}

// mapState : (a -> b) -> State a -> State b
// mapState func { visited, unvisited, params, frag, value } =
//   State visited unvisited params frag (func value)

///|
fn[A, B] mapState(func : (A) -> B, state : State[A]) -> State[B] {
  State::{
    visited: state.visited,
    unvisited: state.unvisited,
    params: state.params,
    frag: state.frag,
    value: func(state.value),
  }
}

// map : a -> Parser a b -> Parser (b -> c) c
// map subValue (Parser parseArg) =
//   Parser <| \{ visited, unvisited, params, frag, value } ->
//     List.map (mapState value) <| parseArg <|
//       State visited unvisited params frag subValue

// parse : Parser (a -> a) a -> Url -> Maybe a
// parse (Parser parser) url =
//   getFirstMatch <| parser <|
//     State [] (preparePath url.path) (prepareQuery url.query) url.fragment identity

///|
fn[A] parse(parser : Parser[(A) -> A, A], url : String) -> A? {
  let state = State::{
    visited: [],
    unvisited: prepare_path(url) |> Array::map(_, StringView::to_string(_)),
    params: Map::new(),
    frag: None,
    value: (subValue : A) => subValue,
  }
  get_first_match(parser.parse(state))
}

// get_first_match <| parser <|
//   State [] (prepare_path url.path) (prepare_query url.query) url.fragment identity

///|
fn prepare_path(path : String) -> Array[StringView] {
  let segments = String::split(path, "/").to_array()
  match segments {
    ["", .. rest] => remove_final_empty(rest.to_array())
    _ => remove_final_empty(segments)
  }
}

///|
fn remove_final_empty(segments : Array[StringView]) -> Array[StringView] {
  match segments {
    [] => []
    [""] => []
    [segment, .. rest] => [segment, ..remove_final_empty([..rest])]
  }
}

///|
fn[A] get_first_match(states : Array[State[A]]) -> A? {
  match states {
    [] => None
    [state, .. rest] =>
      match state.unvisited {
        [] => Some(state.value)
        [""] => Some(state.value)
        _ => get_first_match(rest.to_array())
      }
  }
}
