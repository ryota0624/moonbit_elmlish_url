///|
fn main {
  let u = @lib.top()
    |> @lib.slash(@lib.s("users"))
    |> @lib.slash(@lib.string())
    |> @lib.slash(@lib.s("posts"))
    |> @lib.slash(@lib.int())
    |> @lib.map(userId => postId => (userId, postId), _)
  let st = @lib.parse(u, "users/alice/posts/123")
  println(st)
}
