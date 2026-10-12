defmodule PortfolioWeb.RecruitingDemo.Hooks do
  @moduledoc """
  `on_mount` hooks of the demo live_session: locale, visitor session and
  the enabled flag (checked again because the socket outlives the request).
  """
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [redirect: 2]

  alias Portfolio.RecruitingDemo
  alias PortfolioWeb.RecruitingDemo.Plug, as: DemoPlug

  def on_mount(:default, params, session, socket) do
    locale = put_locale(params["locale"])
    session_id = session[DemoPlug.session_key()]

    if RecruitingDemo.enabled?() and is_binary(session_id) do
      {:cont,
       socket
       |> assign(:locale, locale)
       |> assign(:session_id, session_id)
       |> assign(:client_ip, session[DemoPlug.ip_key()])}
    else
      {:halt, redirect(socket, to: "/#{locale}")}
    end
  end

  defp put_locale(locale) do
    if locale in Gettext.known_locales(PortfolioWeb.Gettext) do
      Gettext.put_locale(PortfolioWeb.Gettext, locale)
      locale
    else
      Gettext.get_locale(PortfolioWeb.Gettext)
    end
  end
end
