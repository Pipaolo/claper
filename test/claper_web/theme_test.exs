defmodule ClaperWeb.ThemeTest do
  use ExUnit.Case, async: true

  alias Claper.Accounts.User
  alias ClaperWeb.Theme

  @standard_chartered %User{
    theme_background: "#020B43",
    theme_accent: "#0473EA",
    theme_surface: "#525355"
  }

  test "a user without custom colors keeps the default theme" do
    assert Theme.css(%User{}) == ""
  end

  test "a themed user's colors override the theme tokens" do
    css = Theme.css(@standard_chartered)

    assert css =~ "--color-base-100:#020B43;"
    assert css =~ "--color-base-200:#525355;"
    assert css =~ "--color-primary:#0473EA;"
  end

  test "the accent also drives secondary highlights, as in the default theme" do
    assert Theme.css(@standard_chartered) =~ "--color-secondary:#0473EA;"
  end

  test "the accent's shade scale is replaced, centred on the accent itself" do
    css = Theme.css(@standard_chartered)

    assert css =~ "--color-primary-500:#0473EA;"

    for shade <- [50, 100, 200, 300, 400, 600, 700, 800, 900],
        group <- ["primary", "secondary"] do
      assert css =~ "--color-#{group}-#{shade}:#", "missing #{group}-#{shade}"
    end
  end

  test "neutral tokens follow the background and surface like the default theme" do
    css = Theme.css(@standard_chartered)

    assert css =~ "--color-neutral:#525355;"
    assert css =~ "--color-neutral-900:#020B43;"
    assert css =~ "--color-base-300:#"
  end

  test "muted text stays readable on the background" do
    [_, muted] =
      Regex.run(~r/--color-neutral-400:(#[0-9A-F]{6});/, Theme.css(@standard_chartered))

    assert contrast(muted, "#020B43") >= 7.0
  end

  test "text on the accent uses whichever of white or dark ink reads better" do
    # SC blue: white is 4.52:1, dark ink 4.02:1.
    assert Theme.css(@standard_chartered) =~ "--color-primary-content:#FFFFFF;"
    # Claper pink: dark ink is 7.9:1, white 2.3:1.
    assert Theme.css(%User{theme_accent: "#FC85AE"}) =~ "--color-primary-content:#0F1522;"
  end

  # WCAG 2.x contrast ratio, the same formula the accessibility contrast test uses.
  defp contrast(a, b) do
    [darker, lighter] = Enum.sort([luminance(a), luminance(b)])
    (lighter + 0.05) / (darker + 0.05)
  end

  defp luminance("#" <> hex) do
    [r, g, b] =
      for <<channel::binary-size(2) <- hex>> do
        c = String.to_integer(channel, 16) / 255
        if c <= 0.03928, do: c / 12.92, else: :math.pow((c + 0.055) / 1.055, 2.4)
      end

    0.2126 * r + 0.7152 * g + 0.0722 * b
  end
end
