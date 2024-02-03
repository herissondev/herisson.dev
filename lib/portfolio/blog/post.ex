defmodule Portfolio.Blog.Post do
  @enforce_keys [:id, :author, :title, :body, :description, :tags, :date]
  defstruct [:id, :author, :title, :body, :description, :tags, :date, :json_ld]

  def build(filename, attrs, body) do
    [year, month_day_id] = filename |> Path.rootname() |> Path.split() |> Enum.take(-2)
    [month, day, id] = String.split(month_day_id, "-", parts: 3)
    date = Date.from_iso8601!("#{year}-#{month}-#{day}")
    struct!(__MODULE__, [id: id, date: date, body: body, json_ld: post_json_ld(attrs, date)] ++ Map.to_list(attrs))
  end


  def post_json_ld(attrs, date) do

    """
    {
          "@context": "https://schema.org",
          "@type": "BlogPosting",
          "headline": "#{attrs.title}",
          "image": [],
          "datePublished": "#{date}",
          "dateModified": "#{date}",
          "author": [{
              "@type": "Person",
              "name": "Aimé Risson",
              "url": "https://herisson.dev"
            }]
        }
    """
  end
end
