defmodule PortfolioWeb.MainComponents do
  use PortfolioWeb, :html

  attr(:href, :string, required: true)
  attr(:icon, :string, required: true, doc: "icon as used with heroicons: hero-arrow-solid")
  attr(:label, :string, required: true, doc: "label for the link")
  attr(:target, :string, default: "_self", values: ["_self", "_blank", "_parent", "_top"])

  def icon_link(%{icon: "hero-" <> _} = assigns) do
    ~H"""
    <a
      href={@href}
      target={@target}
      class="border p-1 rounded text-gray-500 hover:text-gray-800 hover:border-gray-500"
      aria-label={@label}
    >
      <.icon name={@icon} />
    </a>
    """
  end

  def icon_link(assigns) do
    ~H"""
    <a
      href={@href}
      target={@target}
      class="border p-1 rounded text-gray-500 hover:text-gray-800 hover:border-gray-500"
      aria-label={@label}
    >
      <.custom_icon icon={@icon} />
    </a>
    """
  end

  slot(:inner_block)
  attr(:class, :string, default: nil)

  def section(assigns) do
    ~H"""
    <section class={["flex min-h-0 flex-col gap-y-3", @class]}>
      <%= render_slot(@inner_block) %>
    </section>
    """
  end

  attr(:image, :string, required: true)

  def avatar(assigns) do
    ~H"""
    <div class="relative w-[112px] h-[112px] flex shrink-0 overflow-hidden rounded-xl ">
      <img src={@image} alt="Aimé Risson Picture" class="aspect-square h-full w-full" />
    </div>
    """
  end

  attr(:variant, :string,
    values: ["default", "secondary", "destructive", "outline"],
    default: "default"
  )

  attr(:text, :string, required: true)

  def tag(assigns) do
    ~H"""
    <div class={[
      "inline-flex items-center rounded-md border px-2 py-0.5 text-xs font-semibold font-mono transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2 text-nowrap align-middle text-xs",
      tag_variant(@variant)
    ]}>
      <%= @text %>
    </div>
    """
  end

  attr(:title, :string, required: true)
  attr(:description, :string, required: true)
  attr(:tags, :list, required: true)
  attr(:link, :string, default: nil)

  def project(assigns) do
    ~H"""
    <div class="flex flex-col min-h-[100px] p-3 border rounded hover:border-gray-400">
      <a href={@link} target="_blank" class="flex flex-col h-full justify-between">
        <div class="flex flex-col gap-y-2">
          <h3 class="font-semibold gr-1 leading-none"><%= @title %></h3>
          <p class="text-xs font-mono text-muted-foreground"><%= @description %></p>
        </div>
        <span class="mt-1" alt="skills used">
          <%= for tag <- @tags do %>
            <.tag text={tag} variant="secondary" />
          <% end %>
        </span>
      </a>
    </div>
    """
  end

  attr(:title, :string, required: true)
  attr(:date, :string)
  attr(:job_title, :string, default: "")
  attr(:summary, :string, required: true)
  attr(:skills, :list, default: [])
  attr(:link, :string, default: nil)
  # TODO : Move to another file
  def event(assigns) do
    ~H"""
    <div class="flex justify-between mb-4">
      <div class="flex flex-col gap-x-2 gap-y-1 w-full">
        <div class="flex flex-col-reverse md:flex-row w-full justify-between">
          <a
            href={@link}
            target="_blank"
            class={"font-semibold gr-1  leading-none #{if @link != nil, do: " underline"}"}
          >
            <%= @title %>
            <%= if @link != nil do %>
              <.icon name="hero-link" />
            <% end %>
          </a>

          <p class="text-muted-foreground text-sm tabular-nums"><%= @date %></p>
        </div>
        <p class="text-sm font-mono leading-none"><%= @job_title %></p>
        <div class="text-xs font-mono text-muted-foreground">
          <%= @summary %>
        </div>

        <span class="mt-1" alt="skills used">
          <%= for tag <- @skills do %>
            <.tag text={tag} variant="secondary" />
          <% end %>
        </span>
      </div>
    </div>
    """
  end

  # ------------------- PRIVATE FUNCTIONS ---------------------
  defp tag_variant("default"),
    do:
      "align-middle text-xs border-transparent bg-primary/80 text-primary-foreground hover:bg-primary/60"

  defp tag_variant("secondary"),
    do: "border-transparent bg-secondary text-secondary-foreground hover:bg-secondary/60"

  defp tag_variant("destructive"),
    do: "border-transparent bg-destructive text-black hover:bg-destructive/80"

  defp tag_variant("outline"), do: "text-foreground"
  attr(:icon, :string, required: true)

  def custom_icon(%{icon: "linkedin" <> _} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      x="0px"
      y="0px"
      width="20"
      height="20"
      viewBox="0 0 50 50"
      class="fill-current"
      aria-label="LinkedIn logo"
    >
      <path d="M 8 3.0117188 C 6.3243556 3.0117186 4.8517223 3.4556501 3.7636719 4.3105469 C 2.6756214 5.1654436 2.0117188 6.4640138 2.0117188 7.9003906 C 2.0117188 10.773144 4.6048 12.988281 8 12.988281 C 9.7412258 12.988281 11.234704 12.477413 12.304688 11.5625 C 13.374671 10.647587 13.988281 9.3224486 13.988281 7.9003906 A 0.98809878 0.98809878 0 0 0 13.986328 7.8554688 C 13.861647 5.1114423 11.373244 3.0117188 8 3.0117188 z M 8 4.9882812 C 10.612452 4.9882814 11.919564 6.27684 12.007812 7.9199219 C 12.002386 8.7882363 11.669223 9.5069667 11.019531 10.0625 C 10.364515 10.622587 9.3587742 11.011719 8 11.011719 C 5.3952 11.011719 3.9882813 9.627637 3.9882812 7.9003906 C 3.9882812 7.0367674 4.3243786 6.3853376 4.9863281 5.8652344 C 5.6482777 5.3451311 6.6756444 4.9882813 8 4.9882812 z M 3 15 A 1.0001 1.0001 0 0 0 2 16 L 2 45 A 1.0001 1.0001 0 0 0 3 46 L 13 46 A 1.0001 1.0001 0 0 0 14 45 L 14 35.699219 L 14 16 A 1.0001 1.0001 0 0 0 13 15 L 3 15 z M 18 15 A 1.0001 1.0001 0 0 0 17 16 L 17 45.099609 A 1.0001 1.0001 0 0 0 18 46.099609 L 28 46.099609 A 1.0001 1.0001 0 0 0 29 45.099609 L 29 29.099609 L 29 28.800781 L 29 28.5 C 29 26.533333 30.533333 25 32.5 25 C 34.466667 25 36 26.533333 36 28.5 L 36 45 A 1.0001 1.0001 0 0 0 37 46 L 47 46 A 1.0001 1.0001 0 0 0 48 45 L 48 28 C 48 23.855907 46.781684 20.586343 44.736328 18.361328 C 42.690972 16.136313 39.844829 15 36.800781 15 C 32.892578 15 30.522592 16.421774 29 17.583984 L 29 16 A 1.0001 1.0001 0 0 0 28 15 L 18 15 z M 4 17 L 12 17 L 12 35.699219 L 12 44 L 4 44 L 4 17 z M 19 17 L 27 17 L 27 19.599609 A 1.0001 1.0001 0 0 0 28.736328 20.275391 C 28.736328 20.275391 31.737145 17 36.800781 17 C 39.356734 17 41.609028 17.914859 43.263672 19.714844 C 44.918316 21.514828 46 24.244093 46 28 L 46 44 L 38 44 L 38 28.5 A 1.0001 1.0001 0 0 0 37.916016 28.089844 C 37.6949 25.257915 35.387842 23 32.5 23 C 29.466667 23 27 25.466667 27 28.5 L 27 28.800781 L 27 29.099609 L 27 44.099609 L 19 44.099609 L 19 17 z">
      </path>
    </svg>
    """
  end

  def custom_icon(%{icon: "github" <> _} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      x="0px"
      y="0px"
      width="20"
      height="20"
      class="fill-current"
      viewBox="0 0 50 50"
      aria-label="GitHub"
    >
      <path d="M 25 2 C 12.311335 2 2 12.311335 2 25 C 2 37.688665 12.311335 48 25 48 C 37.688665 48 48 37.688665 48 25 C 48 12.311335 37.688665 2 25 2 z M 25 4 C 36.607335 4 46 13.392665 46 25 C 46 25.071371 45.994849 25.141688 45.994141 25.212891 C 45.354527 25.153853 44.615508 25.097776 43.675781 25.064453 C 42.347063 25.017336 40.672259 25.030987 38.773438 25.125 C 38.843852 24.634651 38.893205 24.137377 38.894531 23.626953 C 38.991361 21.754332 38.362521 20.002464 37.339844 18.455078 C 37.586913 17.601352 37.876747 16.515218 37.949219 15.283203 C 38.031819 13.878925 37.910599 12.321765 36.783203 11.269531 L 36.494141 11 L 36.099609 11 C 33.416539 11 31.580023 12.12321 30.457031 13.013672 C 28.835529 12.386022 27.01222 12 25 12 C 22.976367 12 21.135525 12.391416 19.447266 13.017578 C 18.324911 12.126691 16.486785 11 13.800781 11 L 13.408203 11 L 13.119141 11.267578 C 12.020956 12.287321 11.919778 13.801759 11.988281 15.199219 C 12.048691 16.431506 12.321732 17.552142 12.564453 18.447266 C 11.524489 20.02486 10.900391 21.822018 10.900391 23.599609 C 10.900391 24.111237 10.947969 24.610071 11.017578 25.101562 C 9.2118173 25.017808 7.6020996 25.001668 6.3242188 25.046875 C 5.3845143 25.080118 4.6454422 25.135713 4.0058594 25.195312 C 4.0052628 25.129972 4 25.065482 4 25 C 4 13.392665 13.392665 4 25 4 z M 14.396484 13.130859 C 16.414067 13.322043 17.931995 14.222972 18.634766 14.847656 L 19.103516 15.261719 L 19.681641 15.025391 C 21.263092 14.374205 23.026984 14 25 14 C 26.973016 14 28.737393 14.376076 30.199219 15.015625 L 30.785156 15.273438 L 31.263672 14.847656 C 31.966683 14.222758 33.487184 13.321554 35.505859 13.130859 C 35.774256 13.575841 36.007486 14.208668 35.951172 15.166016 C 35.883772 16.311737 35.577304 17.559658 35.345703 18.300781 L 35.195312 18.783203 L 35.494141 19.191406 C 36.483616 20.540691 36.988121 22.000937 36.902344 23.544922 L 36.900391 23.572266 L 36.900391 23.599609 C 36.900391 26.095064 36.00178 28.092339 34.087891 29.572266 C 32.174048 31.052199 29.152663 32 24.900391 32 C 20.648118 32 17.624827 31.052192 15.710938 29.572266 C 13.797047 28.092339 12.900391 26.095064 12.900391 23.599609 C 12.900391 22.134903 13.429308 20.523599 14.40625 19.191406 L 14.699219 18.792969 L 14.558594 18.318359 C 14.326866 17.530484 14.042825 16.254103 13.986328 15.101562 C 13.939338 14.14294 14.166221 13.537027 14.396484 13.130859 z M 8.8847656 26.021484 C 9.5914575 26.03051 10.40146 26.068656 11.212891 26.109375 C 11.290419 26.421172 11.378822 26.727898 11.486328 27.027344 C 8.178972 27.097092 5.7047309 27.429674 4.1796875 27.714844 C 4.1152068 27.214494 4.0638483 26.710021 4.0351562 26.199219 C 5.1622058 26.092262 6.7509972 25.994233 8.8847656 26.021484 z M 41.115234 26.037109 C 43.247527 26.010033 44.835728 26.108156 45.962891 26.214844 C 45.934234 26.718328 45.883749 27.215664 45.820312 27.708984 C 44.24077 27.41921 41.699674 27.086688 38.306641 27.033203 C 38.411945 26.739677 38.499627 26.438219 38.576172 26.132812 C 39.471291 26.084833 40.344564 26.046896 41.115234 26.037109 z M 11.912109 28.019531 C 12.508849 29.215327 13.361516 30.283019 14.488281 31.154297 C 16.028825 32.345531 18.031623 33.177838 20.476562 33.623047 C 20.156699 33.951698 19.86578 34.312595 19.607422 34.693359 L 19.546875 34.640625 C 19.552375 34.634325 19.04975 34.885878 18.298828 34.953125 C 17.547906 35.020374 16.621615 35 15.800781 35 C 14.575781 35 14.03621 34.42121 13.173828 33.367188 C 12.696283 32.72356 12.114101 32.202331 11.548828 31.806641 C 10.970021 31.401475 10.476259 31.115509 9.8652344 31.013672 L 9.7832031 31 L 9.6992188 31 C 9.2325521 31 8.7809835 31.03379 8.359375 31.515625 C 8.1485707 31.756544 8.003277 32.202561 8.0976562 32.580078 C 8.1920352 32.957595 8.4308563 33.189581 8.6445312 33.332031 C 10.011254 34.24318 10.252795 36.046511 11.109375 37.650391 C 11.909298 39.244315 13.635662 40 15.400391 40 L 18 40 L 18 44.802734 C 10.967811 42.320535 5.6646795 36.204613 4.3320312 28.703125 C 5.8629338 28.414776 8.4265387 28.068108 11.912109 28.019531 z M 37.882812 28.027344 C 41.445538 28.05784 44.08105 28.404061 45.669922 28.697266 C 44.339047 36.201504 39.034072 42.31987 32 44.802734 L 32 39.599609 C 32 38.015041 31.479642 36.267712 30.574219 34.810547 C 30.299322 34.368135 29.975945 33.949736 29.615234 33.574219 C 31.930453 33.11684 33.832364 32.298821 35.3125 31.154297 C 36.436824 30.284907 37.287588 29.220424 37.882812 28.027344 z M 23.699219 34.099609 L 26.5 34.099609 C 27.312821 34.099609 28.180423 34.7474 28.875 35.865234 C 29.569577 36.983069 30 38.484177 30 39.599609 L 30 45.398438 C 28.397408 45.789234 26.72379 46 25 46 C 23.27621 46 21.602592 45.789234 20 45.398438 L 20 39.599609 C 20 38.508869 20.467828 37.011307 21.208984 35.888672 C 21.950141 34.766037 22.886398 34.099609 23.699219 34.099609 z M 12.308594 35.28125 C 13.174368 36.179258 14.222525 37 15.800781 37 C 16.579948 37 17.552484 37.028073 18.476562 36.945312 C 18.479848 36.945018 18.483042 36.943654 18.486328 36.943359 C 18.36458 37.293361 18.273744 37.645529 18.197266 38 L 15.400391 38 C 14.167057 38 13.29577 37.55443 12.894531 36.751953 L 12.886719 36.738281 L 12.880859 36.726562 C 12.716457 36.421191 12.500645 35.81059 12.308594 35.28125 z">
      </path>
    </svg>
    """
  end

  def custom_icon(%{icon: "malt" <> _} = assigns) do
    ~H"""
    <svg wwidth="20" height="20" viewBox="0 0 338 338" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path
        d="M289.247 48.7706C263.734 23.2571 236.48 39.7703 219.424 56.8264L58.3011 217.954C41.2451 235.009 23.3928 260.922 50.2454 287.771C77.0979 314.629 103.011 296.773 120.064 279.717L281.19 118.593C298.246 101.535 314.759 74.2806 289.247 48.7706Z"
        fill="#FC5757"
      />
      <path
        d="M135.312 42.1715L169.43 76.2873L204.157 41.5599C206.515 39.1967 208.909 37.0037 211.317 34.9354C207.68 16.5874 197.211 0 169.413 0C141.564 0 131.107 16.6526 127.49 35.0404C130.09 37.2896 132.685 39.5442 135.312 42.1715Z"
        fill="#FC5757"
      />
      <path
        d="M204.137 295.593L169.432 260.886L135.332 294.982C132.743 297.573 130.166 299.94 127.6 302.163C131.51 320.868 142.577 338 169.417 338C196.327 338 207.38 320.776 211.265 302.011C208.878 299.958 206.489 297.944 204.137 295.593Z"
        fill="#FC5757"
      />
      <path
        d="M120.842 124.877H55.0676C30.951 124.877 0 132.475 0 168.552C0 195.472 17.2298 206.526 35.9976 210.409C38.2196 207.843 120.842 124.877 120.842 124.877Z"
        fill="#FC5757"
      />
      <path
        d="M302.969 126.629C300.888 129.05 218.092 212.225 218.092 212.225H282.932C307.051 212.225 338 206.527 338 168.552C338 140.706 321.353 130.244 302.969 126.629Z"
        fill="#FC5757"
      />
      <path
        d="M142.393 103.286L154.143 91.5357L120.047 57.4344C102.99 40.3801 77.0798 22.5261 50.2273 49.3786C30.5366 69.0693 34.9101 88.2334 45.3544 103.791C48.5354 103.556 142.393 103.286 142.393 103.286Z"
        fill="#FC5757"
      />
      <path
        d="M196.456 233.816L184.674 245.598L219.405 280.325C236.462 297.383 263.716 313.892 289.226 288.382C308.261 269.345 303.893 249.35 293.369 233.333C289.982 233.577 196.456 233.816 196.456 233.816Z"
        fill="#FC5757"
      />
    </svg>
    """
  end
end
