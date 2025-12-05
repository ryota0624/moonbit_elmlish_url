///|
pub struct Parser[In, Out]((State[In]) -> Array[State[Out]])

///|
fn[A, B] Parser::parse(
  self : Parser[A, B],
  state : State[A],
) -> Array[State[B]] {
  let Parser(parseFn) = self
  parseFn(state)
}

///|
pub struct State[Value] {
  visited : Array[String]
  unvisited : Array[String]
  params : Map[String, Array[String]]
  frag : String?
  value : Value
}

///|
pub fn[A, B] custom(_ : String, f : (String) -> A?) -> Parser[(A) -> B, B] {
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
pub fn[A] string() -> Parser[(String) -> A, A] {
  custom("STRING", Some(_))
}

///|
pub fn[A] int() -> Parser[(Int) -> A, A] {
  custom("INT", (str : String) => {
    let st = try? @strconv.from_str(str)
    match st {
      Ok(v) => Some(v)
      Err(_) => None
    }
  })
}

///|
pub fn[A] s(str : String) -> Parser[A, A] {
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
pub fn[A] top() -> Parser[A, A] {
  Parser(fn(state) { [state] })
}

///|
pub fn[A, B, C] slash(
  parser1 : Parser[A, B],
  parser2 : Parser[B, C],
) -> Parser[A, C] {
  Parser(state => parser1.parse(state)
    |> Array::map(_, parser2.parse(_))
    |> Array::flatten)
}

///|

///|
pub fn[A, B, C] map(subValue : A, parser : Parser[A, B]) -> Parser[(B) -> C, C] {
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

///|
pub fn[A] parse(parser : Parser[(A) -> A, A], url : String) -> A? {
  let state = State::{
    visited: [],
    unvisited: prepare_path(url) |> Array::map(_, StringView::to_string(_)),
    params: Map::new(),
    frag: None,
    value: (subValue : A) => subValue,
  }
  get_first_match(parser.parse(state))
}

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

