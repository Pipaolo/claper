defmodule ClaperWeb.Accessibility.BrandContrastTest do
  use ExUnit.Case, async: true

  @pairs [
    {"ink on pink", "#0F1522", "#FC85AE", 7.0},
    {"ink on blue", "#0F1522", "#51A2FF", 4.5},
    {"off-white on darker navy", "#F4F6FB", "#2B354A", 7.0},
    {"muted copy on navy", "#C5CDDC", "#303A52", 7.0},
    {"ink on info", "#0F1522", "#51A2FF", 4.5},
    {"white on success", "#FFFFFF", "#147A4C", 4.5},
    {"white on error", "#FFFFFF", "#C12B34", 4.5},
    {"pink focus on navy", "#FC85AE", "#303A52", 3.0},
    {"muted boundary on navy", "#C5CDDC", "#303A52", 3.0},
    {"light error action on navy", "#F0A4AA", "#303A52", 4.5},
    {"light success action on navy", "#9DDCBC", "#303A52", 4.5}
  ]

  @semantic_tokens [
    {"color-primary", "#FC85AE"},
    {"color-primary-content", "#0F1522"},
    {"color-secondary", "#FC85AE"},
    {"color-secondary-content", "#0F1522"},
    {"color-base-100", "#303A52"},
    {"color-base-200", "#2B354A"},
    {"color-base-content", "#F4F6FB"},
    {"color-info", "#51A2FF"},
    {"color-info-content", "#0F1522"},
    {"color-success", "#147A4C"},
    {"color-success-content", "#FFFFFF"},
    {"color-error", "#C12B34"},
    {"color-error-content", "#FFFFFF"},
    {"color-neutral-400", "#C5CDDC"},
    {"color-neutral-100", "#F4F6FB"},
    {"color-neutral-900", "#303A52"}
  ]

  test "approved foreground and background pairs meet their WCAG thresholds" do
    for {name, foreground, background, threshold} <- @pairs do
      ratio = contrast_ratio(foreground, background)

      assert ratio >= threshold,
             "#{name} contrast was #{Float.round(ratio, 2)}:1; expected at least #{threshold}:1"
    end
  end

  test "theme config maps semantic tokens to approved literals" do
    theme_config = Path.expand("../../../assets/css/theme-config.css", __DIR__) |> File.read!()

    for {token, value} <- @semantic_tokens do
      pattern = Regex.compile!("--#{Regex.escape(token)}:\\s*#{Regex.escape(value)};")
      assert Regex.match?(pattern, theme_config), "missing #{token}: #{value} mapping"
    end
  end

  test "text-bearing gradient button API uses one contrast-safe background" do
    app_css = Path.expand("../../../assets/css/app.css", __DIR__) |> File.read!()

    [button_rules] =
      Regex.run(~r/@utility btn-gradient \{(.*?)\n\}/s, app_css, capture: :all_but_first)

    assert button_rules =~ "background: #FC85AE;"
    assert button_rules =~ "color: #0F1522;"
    refute button_rules =~ "linear-gradient"
  end

  @spec contrast_ratio(String.t(), String.t()) :: float()
  defp contrast_ratio(foreground, background) do
    foreground_luminance = relative_luminance(foreground)
    background_luminance = relative_luminance(background)

    lighter = max(foreground_luminance, background_luminance)
    darker = min(foreground_luminance, background_luminance)

    (lighter + 0.05) / (darker + 0.05)
  end

  defp relative_luminance(hex) do
    [red, green, blue] =
      hex
      |> String.trim_leading("#")
      |> String.graphemes()
      |> Enum.chunk_every(2)
      |> Enum.map(fn channel -> String.to_integer(Enum.join(channel), 16) / 255 end)
      |> Enum.map(&linearize/1)

    0.2126 * red + 0.7152 * green + 0.0722 * blue
  end

  defp linearize(channel) when channel <= 0.03928, do: channel / 12.92
  defp linearize(channel), do: :math.pow((channel + 0.055) / 1.055, 2.4)
end
