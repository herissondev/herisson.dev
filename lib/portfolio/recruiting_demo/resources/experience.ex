defmodule Portfolio.RecruitingDemo.Resources.Experience do
  @moduledoc "One declared experience of a CV."
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :company, :string, allow_nil?: false, public?: true
    attribute :role, :string, allow_nil?: false, public?: true
    attribute :start_year, :integer, public?: true
    attribute :end_year, :integer, public?: true
    attribute :summary, :string, public?: true
  end
end
