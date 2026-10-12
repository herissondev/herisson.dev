defmodule PortfolioWeb.BlogControllerTest do
  use PortfolioWeb.ConnCase

  alias Portfolio.Blog

  test "GET /:locale/blog lists posts", %{conn: conn} do
    [post | _] = Blog.recent_posts()
    conn = get(conn, ~p"/en/blog")
    assert html_response(conn, 200) =~ post.title
  end

  test "GET /:locale/blog/:id renders a post", %{conn: conn} do
    [post | _] = Blog.recent_posts()
    conn = get(conn, ~p"/en/blog/#{post.id}")
    assert html_response(conn, 200) =~ post.title
  end
end
