%{
  title: "Building this blog",
  author: "Aimé Risson",
  tags: ~w(Elixir Phoenix NimblePublisher),
  description: "Short post on the technologies used to build this blog and portfolio."
}
---
Since I'm young I've always liked making tutorials on all sorts of things. I first started making videos before my teenage years on how to make a led blink using arduino.  To be honest these were kind of awful :-)  But I liked the experience and I'd like to try myself at it again.

The idea is just to share some fun experiments, solutions or thoughts I might have without thinking much about it.

So here we are, building a blog!
## What I wanted:
For the sake of simplicity I wanted this website to be able to run on its own , so it

should not require
- a database
- external services

should have:
- markdown support
- be highly customizable
- full stack
- fun to work with  :)

All of this made me consider a combination of [Elixir](https://elixir-lang.org/) and [Phoenix](https://www.phoenixframework.org/) a web Framework built for elixir.
Of course I'm biased in these choices as I have discovered Elixir in the past year and **I have fallen for it.**

Phoenix is much more than just a web framework, it allows me to build apps much faster than I used to do. On top of that I love the fact that my whole websites lives in one single codebase that I can update easily. This is without mentioning all the [benefits of elixir](https://www.bairesdev.com/blog/what-is-elixir/) and the functional langage paradigm that I'm starting to adopt.

This set up lets me easily build my blog/portfolio and allows me to further upgrade it when I'll have the time or need.

## Using NimblePublisher
NimblePublisher as of their [github repo](https://github.com/dashbitco/nimble_publisher) is a minimal filesystem-based publishing engine with Markdown support and code highlighting.
Remember I wanted markdown support, well that is exactly it. It allows me to simply write blog post with code as markdown and NimblePublisher takes care of the rest.
Here is how I would define a blog post:

```markdown
%{
  title: "Building this blog",
  author: "Aimé Risson",
  tags: ~w(Elixir Phoenix NimblePublisher),
  description: "Short post on the technologies used to build this blog and portfolio."
}
---


This is a *markdown* document with support for code highlighters:
```

```elixir
IO.puts("test")
```

Effective!

## Hosting
Thanks to Phoenix it's very easy to build a docker image out of my project and after a few github pipelines, my website is deployed on my personal kubernetes hosting multiple projects.


That's all, thanks :)
