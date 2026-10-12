defmodule PortfolioWeb.RecruitingDemo.DemoLive do
  use PortfolioWeb, :live_view

  import PortfolioWeb.MainComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, gettext("Recruiting demo"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="container mx-auto scroll-my-12 overflow-auto p-4 md:p-16">
      <section class="mx-auto w-full max-w-4xl space-y-8 bg-white">
        <div class="flex-1 space-y-1.5">
          <h1 class="text-2xl font-bold">{gettext("Recruiting demo")}</h1>
          <p class="text-pretty font-mono text-sm text-muted-foreground">
            {gettext(
              "Four AI agents with partitioned rights screen a CV. You play the recruiter: you alone decide and send the email."
            )}
          </p>
        </div>
        <.section>
          <div class="rounded border p-3">
            <p class="font-mono text-xs text-muted-foreground">
              {gettext(
                "All data is fictitious and is not kept: everything is erased when your session ends. Web research is simulated."
              )}
            </p>
          </div>
        </.section>
      </section>
    </main>
    """
  end
end
