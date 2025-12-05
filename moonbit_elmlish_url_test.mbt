// TODO: write tests for moonbit_elmlish_url///|

///|
test {
  let u = top()
    |> slash(s("users"))
    |> slash(string())
    |> slash(s("posts"))
    |> slash(int())
    |> map(userId => postId => (userId, postId), _)
  let st = parse(u, "users/alice/posts/123")
  inspect(st, content="Some((\"alice\", 123))")
  let u2 = s("users") |> slash(_, string()) |> map(userId => userId, _)
  let st2 = parse(u2, "/users/bob")
  inspect(st2, content="Some(\"bob\")")
}
