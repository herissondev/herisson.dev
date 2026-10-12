defmodule PortfolioWeb.RecruitingDemo.DemoLiveTest do
  use PortfolioWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # The pipeline runs in the background; wait until the page reaches a state
  defp await(view, selector, attempts \\ 100) do
    cond do
      has_element?(view, selector) ->
        :ok

      attempts == 0 ->
        flunk("#{selector} never appeared:\n#{render(view)}")

      true ->
        Process.sleep(20)
        await(view, selector, attempts - 1)
    end
  end

  defp submit(conn, template \\ "aligned") do
    {:ok, view, _html} = live(conn, "/en/demo/recruiting")

    view |> element("#pick-#{template}") |> render_click()
    view |> element("#submit-application") |> render_click()

    {view, assert_patch(view)}
  end

  test "full journey: candidate, agents, decision, edited draft, fake outbox", %{conn: conn} do
    {view, path} = submit(conn)
    assert path =~ ~r"^/en/demo/recruiting/[0-9a-f-]{36}$"

    await(view, "#decide-yes")
    html = render(view)
    assert html =~ "The AI&#39;s opinion"
    assert html =~ "Strong yes"
    assert html =~ "3 searches in parallel"

    view |> element("#decide-yes") |> render_click()
    await(view, "#draft-form")

    [_, body] =
      Regex.run(
        ~r{<textarea[^>]*>(.*)</textarea>}s,
        view |> element("#draft-form textarea") |> render()
      )

    assert body =~ "Hello Camille Martin"

    edited = body <> "\nSee you soon"

    view
    |> form("#draft-form", draft: %{subject: "Your application", body: edited})
    |> render_change()

    view |> form("#draft-form") |> render_submit()

    html = render(view)
    assert html =~ "Sent to the fake outbox"
    assert html =~ "human:recruiter"
    assert html =~ "See you soon"
    assert html =~ "You send the email"
  end

  test "the visitor can edit the position and the CV before sending", %{conn: conn} do
    {:ok, view, _html} = live(conn, "/en/demo/recruiting")

    view |> form("#offer-form", offer: %{title: "Head of Sales"}) |> render_change()
    view |> form("#cv-form", cv: %{name: "Ada Lovelace"}) |> render_change()
    view |> element("#submit-application") |> render_click()

    assert_patch(view)
    await(view, "#decide-yes")
    html = render(view)
    assert html =~ "Ada Lovelace"
    assert html =~ "Head of Sales"
  end

  test "injection CV: manual review, then the refused call is shown", %{conn: conn} do
    {view, _path} = submit(conn, "injection")

    await(view, ~s(button[phx-value-approve="true"]))
    assert render(view) =~ "suspect"

    view |> element(~s(button[phx-value-approve="true"])) |> render_click()
    await(view, "#decide-yes")

    assert render(view) =~ "Refused: Matcher tried to send the email."
  end

  test "off-topic document is rejected at sorting, later steps are skipped", %{conn: conn} do
    {view, _path} = submit(conn, "off_topic")
    await(view, "#step-triage")
    Process.sleep(100)

    html = render(view)
    assert html =~ "unrelated"
    assert html =~ "line-through"
    refute has_element?(view, "#decide-yes")
  end

  test "agent context, integrity check, replay and export", %{conn: conn} do
    {view, path} = submit(conn)
    await(view, "#decide-yes")

    view
    |> element(~s(button[phx-click="show_context"][phx-value-agent="triage"]))
    |> render_click()

    modal = view |> element("#agent-context") |> render()
    assert modal =~ "Context received by Triage"
    assert modal =~ "cv_text"
    refute modal =~ "salary_max"

    view |> element("button", "Verify integrity") |> render_click()
    assert render(view) =~ "Hash chain verified"

    view |> element("button", "Replay") |> render_click()
    assert render(view) =~ "Replaying from the journal"

    conn = get(build_conn() |> Plug.Test.init_test_session(%{}), path <> "/journal.json")
    assert json_response(conn, 200)["events"] == []
  end

  test "an application id from another session is not shown", %{conn: conn} do
    {_view, path} = submit(conn)

    assert {:error, {:live_redirect, %{to: "/en/demo/recruiting"}}} = live(build_conn(), path)
  end
end
