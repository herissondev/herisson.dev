defmodule PortfolioWeb.RecruitingDemo.JournalController do
  @moduledoc "JSON export of an application's journal, for its own visitor only."
  use PortfolioWeb, :controller

  alias Portfolio.RecruitingDemo
  alias PortfolioWeb.RecruitingDemo.Plug, as: DemoPlug

  def export(conn, %{"id" => id}) do
    session_id = get_session(conn, DemoPlug.session_key())
    events = RecruitingDemo.journal(session_id, id)

    conn
    |> put_resp_header("content-disposition", ~s(attachment; filename="journal-#{id}.json"))
    |> json(%{
      application_id: id,
      integrity: if(RecruitingDemo.verify_journal(events) == :ok, do: "verified", else: "broken"),
      events: RecruitingDemo.export_journal(events)
    })
  end
end
