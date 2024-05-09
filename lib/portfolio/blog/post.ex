defmodule Portfolio.Blog.Post do
  @enforce_keys [:id,:og_image, :author, :title, :body, :description, :tags, :date]
  defstruct [:id,:og_image, :author, :title, :body, :description, :tags, :date, :json_ld]

  def build(filename, attrs, body) do
    [year, month_day_id] = filename |> Path.rootname() |> Path.split() |> Enum.take(-2)
    [month, day, id] = String.split(month_day_id, "-", parts: 3)
    date = Date.from_iso8601!("#{year}-#{month}-#{day}")

    attrs = Map.put(attrs, :og_image, generate_og_image(year, filename, attrs.title, attrs.tags))
    struct!(__MODULE__, [id: id, date: date, body: body, json_ld: post_json_ld(attrs, date)] ++ Map.to_list(attrs))
  end


  def post_json_ld(attrs, date) do
    """
    {
          "@context": "https://schema.org",
          "@type": "BlogPosting",
          "headline": "#{attrs.title}",
          "image": [],
          "datePublished": "#{Date.to_iso8601(date)}",
          "dateModified": "#{date}",
          "author": [{
              "@type": "Person",
              "name": "Aimé Risson",
              "url": "https://herisson.dev"
            }]
        }
    """
  end

  defp generate_og_image(year, filename, title, tags) do
      # Og images by Dan Shultzer
      #  https://danschultzer.com/posts/dynamic-image-generation-with-elixir
      {filename, basename} = og_image_paths(year, filename)
      {title_line_1, title_line_2} = og_image_title_lines(title)
      tags = Enum.join(tags, ", ")

      svg =
        """
        <svg viewbox="0 0 1200 600" width="1200" height="600" xmlns="http://www.w3.org/2000/svg">
          <defs>
            <linearGradient y2="1" x2="1" y1="0.14844" x1="0.53125" id="gradient">
            <stop offset="0" stop-opacity="0.99609" stop-color="#5b21b6"/>
            <stop offset="0.99219" stop-opacity="0.97656" stop-color="#ff8300"/>
            </linearGradient>
          </defs>
          <g>
            <rect stroke="#000" height="800" width="1800" y="0" x="0" stroke-width="0" fill="url(#gradient)"/>
            <text font-style="normal" font-weight="normal" xml:space="preserve" text-anchor="start" font-family="'Alumni Sans'" font-size="70" y="250" x="100" stroke-width="0" stroke="#000" fill="#f8fafc">#{title_line_1}</text>
            <text font-style="normal" font-weight="normal" xml:space="preserve" text-anchor="start" font-family="'Alumni Sans'" font-size="70" y="350" x="100" stroke-width="0" stroke="#000" fill="#f8fafc">#{title_line_2}</text>
            <text font-style="normal" font-weight="normal" xml:space="preserve" text-anchor="start" font-family="'Alumni Sans'" font-size="30" y="550" x="50" stroke-width="0" stroke="#000" fill="#f8fafc" opacity="0.5">By Aimé Risson</text>
            <text font-style="normal" font-weight="normal" xml:space="preserve" text-anchor="end" font-family="'Alumni Sans'" font-size="30" y="550" x="1150" stroke-width="0" stroke="#000" fill="#f8fafc" opacity="0.5">#{tags}</text>
          </g>
        </svg>
        """

      write_og_image(filename, svg)

      %{year: year, basename: basename}
    end

    defp og_image_paths(year, filename) do
      [root_dir, file] = filename |> Path.rootname() |> String.split(Path.join("posts", year))
      basename = Path.basename(file, ".md") <> ".open-graph.png"
      filename = Path.join([root_dir, "static", "images", "posts", year, basename])

      File.mkdir_p!(Path.dirname(filename))

      {filename, basename}
    end

    @max_length 31

    defp og_image_title_lines(title) do
      title
      |> String.split(" ")
      |> Enum.reduce_while({"", ""}, fn word, {title_line_1, title_line_2} ->
        cond do
          String.length(title_line_1 <> " " <> word) <= @max_length -> {:cont, {title_line_1 <> " " <> word, title_line_2}}
          String.length(title_line_2 <> " " <> word) <= (@max_length - 3) -> {:cont, {title_line_1, title_line_2 <> " " <> word}}
          true -> {:halt, {title_line_1, title_line_2 <> "..."}}
        end
      end)
    end

    defp write_og_image(filename, svg) do
      {image, _} = Vix.Vips.Operation.svgload_buffer!(svg)

      Image.write!(image, filename)
    end
end
