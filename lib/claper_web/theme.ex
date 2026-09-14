defmodule ClaperWeb.Theme do
  @moduledoc """
  Turns a user's custom colors into CSS variable overrides for the `claper`
  daisyUI theme. Colors the user hasn't set keep the default theme.
  """

  alias Claper.Accounts.User
  alias Claper.Color

  @ink "#0F1522"
  @white "#FFFFFF"
  @black "#000000"

  # Lighter shades mix toward white, darker ones toward black; 500 is the color itself.
  @shades [
    {50, @white, 0.9},
    {100, @white, 0.8},
    {200, @white, 0.6},
    {300, @white, 0.4},
    {400, @white, 0.2},
    {600, @black, 0.15},
    {700, @black, 0.3},
    {800, @black, 0.45},
    {900, @black, 0.6}
  ]

  # Muted text, borders and raised surfaces are the background mixed toward white,
  # mirroring the default theme where neutral-900 is the page background.
  @neutrals [
    {800, 0.12},
    {700, 0.2},
    {600, 0.35},
    {500, 0.55},
    {400, 0.78},
    {300, 0.85},
    {200, 0.9},
    {100, 0.95},
    {50, 0.97}
  ]

  # The claper theme's own colors, as set in assets/css/theme-config.css.
  @defaults %{
    "theme_background" => "#303A52",
    "theme_accent" => "#FC85AE",
    "theme_surface" => "#2B354A"
  }

  @doc "The default theme's colors, keyed by the user's theme field."
  def defaults, do: @defaults

  @doc """
  Blanks submitted colors equal to the default. A color picker can't be left empty,
  so this keeps untouched pickers on the default theme instead of storing its hex.
  """
  def blank_defaults(params) do
    Map.new(params, fn {field, color} ->
      if is_binary(color) and String.upcase(color) == @defaults[field],
        do: {field, ""},
        else: {field, color}
    end)
  end

  @doc "Returns a `:root` rule overriding the theme tokens, or `\"\"` for the default theme."
  @spec css(User.t()) :: String.t()
  def css(%User{} = user) do
    vars =
      accent_vars(user.theme_accent) ++
        background_vars(user.theme_background) ++ surface_vars(user.theme_surface)

    case vars do
      [] ->
        ""

      # `:root:root` outranks the daisyUI theme's `:root`/`[data-theme]` selectors.
      vars ->
        ":root:root{" <>
          Enum.map_join(vars, fn {name, value} -> "--color-#{name}:#{value};" end) <> "}"
    end
  end

  defp accent_vars(nil), do: []

  defp accent_vars(accent) do
    content = readable_text_on(accent)

    [
      {"primary", accent},
      {"primary-content", content},
      {"secondary", accent},
      {"secondary-content", content}
    ] ++ scale("primary", accent) ++ scale("secondary", accent)
  end

  defp background_vars(nil), do: []

  defp background_vars(background) do
    [
      {"base-100", background},
      {"base-300", Color.mix(background, @white, 0.12)},
      {"neutral-900", background}
    ] ++
      for(
        {shade, amount} <- @neutrals,
        do: {"neutral-#{shade}", Color.mix(background, @white, amount)}
      )
  end

  defp surface_vars(nil), do: []

  defp surface_vars(surface) do
    [
      {"base-200", surface},
      {"neutral", surface},
      {"neutral-content", readable_text_on(surface)}
    ]
  end

  defp scale(group, color) do
    [
      {"#{group}-500", color}
      | for(
          {shade, toward, amount} <- @shades,
          do: {"#{group}-#{shade}", Color.mix(color, toward, amount)}
        )
    ]
  end

  defp readable_text_on(fill) do
    if Color.contrast(@white, fill) >= Color.contrast(@ink, fill), do: @white, else: @ink
  end
end
