defmodule PortfolioWeb.PageControllerTest do
  use PortfolioWeb.ConnCase

  test "GET / redirects to a locale", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) =~ ~r"^/(en|fr)$"
  end

  test "GET /en renders the english CV", %{conn: conn} do
    conn = get(conn, ~p"/en")
    assert html_response(conn, 200) =~ "Passionate about new technologies"
  end

  test "GET /fr renders the french CV", %{conn: conn} do
    conn = get(conn, ~p"/fr")
    assert html_response(conn, 200) =~ "Passionné par les nouvelles technologies"
  end
end
