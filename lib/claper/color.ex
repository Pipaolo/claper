defmodule Claper.Color do
  @moduledoc "Math on `#RRGGBB` colors for user themes: WCAG contrast and mixing."

  @doc "WCAG 2.x contrast ratio between two colors, from 1.0 to 21.0."
  @spec contrast(String.t(), String.t()) :: float()
  def contrast(a, b) do
    [darker, lighter] = Enum.sort([luminance(a), luminance(b)])
    (lighter + 0.05) / (darker + 0.05)
  end

  @doc "Mixes `color` toward `toward` by `amount`, from 0.0 (unchanged) to 1.0 (`toward`)."
  @spec mix(String.t(), String.t(), float()) :: String.t()
  def mix(color, toward, amount) do
    hex =
      Enum.zip_with(channels(color), channels(toward), fn from, to ->
        round(from + (to - from) * amount)
        |> Integer.to_string(16)
        |> String.pad_leading(2, "0")
      end)

    "#" <> Enum.join(hex)
  end

  defp luminance(color) do
    [r, g, b] =
      for channel <- channels(color) do
        c = channel / 255
        if c <= 0.03928, do: c / 12.92, else: :math.pow((c + 0.055) / 1.055, 2.4)
      end

    0.2126 * r + 0.7152 * g + 0.0722 * b
  end

  defp channels("#" <> hex),
    do: for(<<channel::binary-size(2) <- hex>>, do: String.to_integer(channel, 16))
end
