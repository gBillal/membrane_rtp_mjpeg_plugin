defmodule Membrane.RTP.MJPEG.Fixtures do
  @moduledoc false

  @spec all() :: [binary()]
  def all() do
    {result, _size} =
      Enum.map_reduce(all_without_header(), 0, fn fixture, size ->
        header = <<0, size::24, 1, 60, 80, 60>>
        {header <> fixture, size + byte_size(fixture)}
      end)

    result
  end

  @spec all_without_header() :: [binary()]
  def all_without_header() do
    1..5
    |> Enum.map(&fixture_name/1)
    |> Enum.map(&File.read!/1)
  end

  @spec glued_fixtures() :: binary()
  def glued_fixtures() do
    header() <> (all_without_header() |> Enum.join())
  end

  @spec header() :: binary()
  def header(), do: File.read!("test/fixtures/header.bin")

  defp fixture_name(idx), do: "test/fixtures/pkt-#{idx}.bin"
end
