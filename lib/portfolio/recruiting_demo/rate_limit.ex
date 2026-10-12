defmodule Portfolio.RecruitingDemo.RateLimit do
  @moduledoc """
  Per-IP rate limiting for the demo only.
  """
  use Hammer, backend: :ets

  @doc """
  Records one application submission for `ip` and tells whether it is allowed.
  Limits come from the demo config (`:applications_per_hour`).
  """
  def allow_application?(ip) do
    limit = Keyword.get(Portfolio.RecruitingDemo.config(), :applications_per_hour, 10)

    case hit({:application, ip}, :timer.hours(1), limit) do
      {:allow, _count} -> true
      {:deny, _retry_after} -> false
    end
  end
end
