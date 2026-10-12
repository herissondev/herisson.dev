defmodule PortfolioWeb.RecruitingDemo.Plug do
  @moduledoc """
  Router plug for the demo routes: answers 404 when the demo is disabled,
  gives the visitor a demo session id and remembers their IP for rate limiting.
  """
  @behaviour Plug

  import Plug.Conn

  alias Portfolio.RecruitingDemo

  @session_key "recruiting_demo_session_id"
  @ip_key "recruiting_demo_ip"

  def session_key, do: @session_key
  def ip_key, do: @ip_key

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    if RecruitingDemo.enabled?() do
      conn
      |> ensure_session_id()
      |> put_session(@ip_key, client_ip(conn))
    else
      conn
      |> put_status(:not_found)
      |> Phoenix.Controller.put_view(PortfolioWeb.ErrorHTML)
      |> Phoenix.Controller.render("404.html")
      |> halt()
    end
  end

  defp ensure_session_id(conn) do
    case get_session(conn, @session_key) do
      nil -> put_session(conn, @session_key, RecruitingDemo.new_session_id())
      _ -> conn
    end
  end

  # Behind the ingress, the client address is the first X-Forwarded-For entry.
  defp client_ip(conn) do
    case get_req_header(conn, "x-forwarded-for") do
      [value | _] -> value |> String.split(",") |> hd() |> String.trim()
      [] -> conn.remote_ip |> :inet.ntoa() |> to_string()
    end
  end
end
