defmodule Portfolio.RecruitingDemo.Resources.Finding do
  @moduledoc "One fact the Researcher found (or failed to find)."
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :claim, :string, allow_nil?: false, public?: true
    attribute :confirmed, :boolean, default: false, public?: true
    attribute :source, :string, public?: true
  end
end
