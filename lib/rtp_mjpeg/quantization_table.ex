defmodule Membrane.RTP.MJPEG.QuantizationTable do
  @moduledoc false

  @jpeg_luma_quantizer [
                         [16, 11, 10, 16, 24, 40, 51, 61],
                         [12, 12, 14, 19, 26, 58, 60, 55],
                         [14, 13, 16, 24, 40, 57, 69, 56],
                         [14, 17, 22, 29, 51, 87, 80, 62],
                         [18, 22, 37, 56, 68, 109, 103, 77],
                         [24, 35, 55, 64, 81, 104, 113, 92],
                         [49, 64, 78, 87, 103, 121, 120, 101],
                         [72, 92, 95, 98, 112, 100, 103, 99]
                       ]
                       |> List.flatten()

  @jpeg_chroma_quantizer [
                           [17, 18, 24, 47, 99, 99, 99, 99],
                           [18, 21, 26, 66, 99, 99, 99, 99],
                           [24, 26, 56, 99, 99, 99, 99, 99],
                           [47, 66, 99, 99, 99, 99, 99, 99],
                           [99, 99, 99, 99, 99, 99, 99, 99],
                           [99, 99, 99, 99, 99, 99, 99, 99],
                           [99, 99, 99, 99, 99, 99, 99, 99],
                           [99, 99, 99, 99, 99, 99, 99, 99]
                         ]
                         |> List.flatten()

  @spec make_tables(integer()) :: {[integer()], [integer()]}
  def make_tables(q) do
    factor = clamp(q, 1, 99)
    q = if q < 50, do: div(5000, factor), else: 200 - factor * 2

    @jpeg_luma_quantizer
    |> Stream.zip(@jpeg_chroma_quantizer)
    |> Enum.reduce({[], []}, fn {luma, chroma}, {luma_acc, chroma_acc} ->
      lq = div(luma * q + 50, 100)
      cq = div(chroma * q + 50, 100)

      {[clamp(lq, 1, 255) | luma_acc], [clamp(cq, 1, 255) | chroma_acc]}
    end)
    |> then(fn {luma_q, chroma_q} ->
      {Enum.reverse(luma_q), Enum.reverse(chroma_q)}
    end)
  end

  defp clamp(value, min, _max) when value < min, do: min
  defp clamp(value, _min, max) when value > max, do: max
  defp clamp(value, _min, _max), do: value
end
