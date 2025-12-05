# ryota0624/moonbit_elmlish_url

elm/url inspired URL parser combinator library for Moonbit

https://github.com/elm/url

```moonbit

///
test {
	let p : Parser[((String, Int)) -> (String, Int), (String, Int)] = @moonbit_elmlish_url.top()
		|> @moonbit_elmlish_url.slash(@moonbit_elmlish_url.s("users"))
		|> @moonbit_elmlish_url.slash(@moonbit_elmlish_url.string())
		|> @moonbit_elmlish_url.slash(@moonbit_elmlish_url.s("posts"))
		|> @moonbit_elmlish_url.slash(@moonbit_elmlish_url.int())
		|> @moonbit_elmlish_url.map(userId => postId => (userId, postId), _)
	let parsed = @moonbit_elmlish_url.parse(p, "users/alice/posts/123")
	println(parsed) // Some(("alice", 123))
}
```

```elm

p = Url.map (\userId -> \postId -> (userId, postId)) (Url.s "users" </> Url.string </> Url.s "posts" </> Url.int)

parsed = Url.parse p "users/alice/posts/123"

```
