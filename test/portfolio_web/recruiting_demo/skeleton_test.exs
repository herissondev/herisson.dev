defmodule PortfolioWeb.RecruitingDemo.SkeletonTest do
  # Not async: toggles the demo config and kills the demo supervisor
  use PortfolioWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Portfolio.RecruitingDemo

  test "renders the demo in english and french", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/en/demo/recruiting")
    assert html =~ "Recruiting demo"
    assert html =~ "All data is fictitious"

    {:ok, _view, html} = live(build_conn(), "/fr/demo/recruiting")
    assert html =~ "Démo de recrutement"
    assert html =~ "Toutes les données sont fictives"
  end

  test "gives each visitor a demo session id", %{conn: conn} do
    conn = get(conn, "/en/demo/recruiting")
    assert is_binary(get_session(conn, "recruiting_demo_session_id"))
  end

  test "the CV navigation links to the demo", %{conn: conn} do
    assert conn |> get("/fr") |> html_response(200) =~ ~s(href="/fr/demo/recruiting")
  end

  describe "when the demo is disabled" do
    setup do
      config = Application.get_env(:portfolio, RecruitingDemo)
      Application.put_env(:portfolio, RecruitingDemo, Keyword.put(config, :enabled, false))
      on_exit(fn -> Application.put_env(:portfolio, RecruitingDemo, config) end)
    end

    test "the demo answers 404 and the CV still works", %{conn: conn} do
      assert conn |> get("/en/demo/recruiting") |> html_response(404)
      assert build_conn() |> get("/en") |> html_response(200)
    end
  end

  test "the CV keeps serving when the demo process tree dies", %{conn: conn} do
    pid = Process.whereis(RecruitingDemo.Supervisor)
    children = for {_, child, _, _} <- Supervisor.which_children(pid), do: child
    refs = Enum.map([pid | children], &Process.monitor/1)
    Process.exit(pid, :kill)
    for ref <- refs, do: assert_receive({:DOWN, ^ref, :process, _, _})

    assert conn |> get("/en") |> html_response(200)
    assert build_conn() |> get("/en/blog") |> html_response(200)
    assert Process.alive?(Process.whereis(Portfolio.Supervisor))

    {:ok, _} =
      Supervisor.start_child(
        Portfolio.Supervisor,
        Supervisor.child_spec(RecruitingDemo.Supervisor, restart: :temporary)
      )
  end
end
