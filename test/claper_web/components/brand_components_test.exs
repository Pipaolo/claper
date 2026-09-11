defmodule ClaperWeb.BrandComponentsTest do
  use ClaperWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ClaperWeb.BrandComponents

  @png_signature <<137, 80, 78, 71, 13, 10, 26, 10>>
  @runtime_brand_assets ["claper-logo.png", "claper-mark.png"]

  test "committed runtime brand image assets exist and are PNGs" do
    for filename <- @runtime_brand_assets do
      path = Path.join([File.cwd!(), "priv", "static", "images", filename])

      assert File.regular?(path), "expected #{filename} to be committed at #{path}"
      assert File.stat!(path).size > 0, "expected #{filename} to be non-empty"

      assert File.read!(path) |> binary_part(0, 8) == @png_signature,
             "expected #{filename} to begin with the PNG signature"
    end
  end

  test "committed Apple touch icon is a 180px PNG" do
    path = Path.join([File.cwd!(), "priv", "static", "apple-touch-icon.png"])

    assert File.regular?(path), "expected apple-touch-icon.png to be committed at #{path}"
    assert File.stat!(path).size > 0, "expected apple-touch-icon.png to be non-empty"
    assert File.read!(path) |> binary_part(0, 8) == @png_signature
    assert png_dimensions(path) == {180, 180}
  end

  test "renders the accessible full lockup" do
    html = render_component(&BrandComponents.logo/1, %{variant: :full, class: "h-10"})
    assert html =~ ~s(src="/images/claper-logo.png")
    assert html =~ ~s(alt="Claper")
    assert html =~ ~s(class="h-10")
  end

  test "renders the compact mark" do
    html = render_component(&BrandComponents.logo/1, %{variant: :mark})
    assert html =~ ~s(src="/images/claper-mark.png")
  end

  test "renders safe upstream attribution" do
    html = render_component(&BrandComponents.attribution/1, %{})
    assert html =~ "Powered by Claper"
    assert html =~ ~s(href="https://github.com/ClaperCo/Claper")
    assert html =~ ~s(target="_blank")
    assert html =~ ~s(rel="noopener noreferrer")
  end

  defp png_dimensions(path) do
    <<@png_signature, _length::32, "IHDR", width::32, height::32, _rest::binary>> =
      File.read!(path)

    {width, height}
  end
end
