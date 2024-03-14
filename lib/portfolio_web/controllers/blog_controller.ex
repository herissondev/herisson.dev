defmodule PortfolioWeb.BlogController do
  alias Portfolio.Blog
  use PortfolioWeb, :controller

  def index(conn, _params) do
    render(conn, :index, posts: Blog.recent_posts(), page_title: "Blog")
  end

  def show(conn, %{"id" => id} = _params) do
    post = Blog.get_post_by_id!(id)
    render(conn, :show, post: post, page_title: post.title)
  end
end
