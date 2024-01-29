defmodule PortfolioWeb.BlogController do
  alias Portfolio.Blog
  use PortfolioWeb, :controller

  def index(conn, _params) do
    render(conn, :index, posts: Blog.recent_posts())
  end

  def show(conn, %{"id" => id}) do
    render(conn, :show, post: Blog.get_post_by_id!(id))
  end
end
