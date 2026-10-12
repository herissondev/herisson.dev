defmodule PortfolioWeb.RecruitingDemo do
  @moduledoc """
  Web layer of the recruiting demo. Only the router (and the navigation
  link) reference it; it only uses the demo context and the shared UI.
  """
  use Boundary,
    top_level?: true,
    deps: [PortfolioWeb, Portfolio.RecruitingDemo],
    exports: [Plug, Hooks, DemoLive, JournalController]
end
