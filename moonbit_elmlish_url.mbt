///|
/// URLパーサーを表す型。入力型`In`から出力型`Out`への変換を行う
/// 
/// パーサーは状態遷移関数を内部に持ち、URL文字列を段階的に解析します
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
/// パーサーの状態を表す型
/// 
/// - `visited`: すでに処理済みのURLセグメント
/// - `unvisited`: まだ処理されていないURLセグメント
/// - `params`: クエリパラメータのマップ
/// - `frag`: URLフラグメント(ハッシュ)
/// - `value`: 現在の解析結果の値
pub struct State[Value] {
  visited : Array[String]
  unvisited : Array[String]
  params : Map[String, Array[String]]
  frag : String?
  value : Value
}

///|
/// カスタムパーサーを作成する関数
/// 
/// 第1引数: パーサーの名前(デバッグ用)
/// 第2引数: 文字列を受け取り、パース結果を返す関数
/// 
/// 例: `custom("NUMBER", str => Int::from_string(str))`
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
/// 任意の文字列セグメントをパースするパーサー
/// 
/// URLの任意のパスセグメントを文字列として受け取ります
/// 
/// 例: `/users/alice` の `alice` 部分
pub fn[A] string() -> Parser[(String) -> A, A] {
  custom("STRING", Some(_))
}

///|
/// 整数値をパースするパーサー
/// 
/// URLのパスセグメントを整数として解析します
/// 整数に変換できない場合はパースが失敗します
/// 
/// 例: `/posts/123` の `123` 部分
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
/// 特定の文字列リテラルにマッチするパーサー
/// 
/// 指定された文字列と完全一致する場合のみパースが成功します
/// 
/// 例: `s("users")` は `/users` の `users` 部分にマッチ
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
/// パースを開始するための初期パーサー
/// 
/// URLパースチェーンの開始点として使用します
/// 状態を変更せずにそのまま返します
/// 
/// 例: `top() |> slash(s("users")) |> ...`
pub fn[A] top() -> Parser[A, A] {
  Parser(fn(state) { [state] })
}

///|
/// 2つのパーサーをスラッシュ(/)で連結する
/// 
/// 第1引数: 左側のパーサー
/// 第2引数: 右側のパーサー
/// 
/// パーサーを順番に適用し、URLのパスを段階的に解析します
/// 
/// 例: `slash(s("users"), string())` は `/users/alice` にマッチ
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
/// パース結果を変換する関数をパーサーに適用する
/// 
/// 第1引数: 新しい初期値
/// 第2引数: 適用するパーサー
/// 
/// パースされた値を別の値に変換し、最終的な結果の型を構築します
/// 
/// 例: `map(userId => postId => (userId, postId), parser)` でタプルを構築
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
/// パーサーを実行してURL文字列を解析する
/// 
/// 第1引数: 使用するパーサー
/// 第2引数: 解析するURL文字列
/// 
/// 戻り値: パースに成功した場合は `Some(result)`, 失敗した場合は `None`
/// 
/// 例: `parse(urlParser, "/users/alice/posts/123")`
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
