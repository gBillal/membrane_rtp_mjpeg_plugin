defmodule Membrane.RTP.MJPEG.DepayloaderTest do
  @moduledoc false

  use ExUnit.Case

  alias Membrane.Buffer
  alias Membrane.RTP.MJPEG.Depayloader
  alias Membrane.RTP.MJPEG.Fixtures

  @empty_state %Depayloader.State{}
  @ctx %{pads: %{output: %{stream_format: nil}}}

  test "depayload rtp packets" do
    [last_buffer | buffers] = Fixtures.all() |> Enum.map(&%Buffer{payload: &1}) |> Enum.reverse()
    last_buffer = %{last_buffer | metadata: %{rtp: %{marker: true}}}
    buffers = Enum.reverse([last_buffer | buffers])

    {actions, @empty_state} =
      Enum.reduce(buffers, {[], @empty_state}, fn buffer, {actions, state} ->
        assert {new_actions, new_state} = Depayloader.handle_buffer(:input, buffer, @ctx, state)
        {actions ++ new_actions, new_state}
      end)

    assert {:output, %Buffer{payload: payload}} = Keyword.fetch!(actions, :buffer)
    assert payload == Fixtures.glued_fixtures()
  end

  test "lost last packet reset state" do
    packets = Fixtures.all()

    buffers =
      Fixtures.all()
      |> Enum.take(4)
      |> Enum.concat(Enum.take(packets, 1))
      |> Enum.map(&%Buffer{payload: &1})

    assert {[], %{frame: [_first_frame]}} =
             Enum.reduce(buffers, {[], @empty_state}, fn buffer, {actions, state} ->
               assert {new_actions, new_state} =
                        Depayloader.handle_buffer(:input, buffer, nil, state)

               {actions ++ new_actions, new_state}
             end)
  end

  test "ignore first packet if fragment offset is not 0" do
    [buffer] = Fixtures.all() |> Enum.drop(1) |> Enum.take(1) |> Enum.map(&%Buffer{payload: &1})
    assert {[], @empty_state} == Depayloader.handle_buffer(:input, buffer, nil, @empty_state)
  end

  test "invalid packet" do
    buffer = %Buffer{payload: <<1::10-integer>>}

    assert {[], @empty_state} == Depayloader.handle_buffer(:input, buffer, nil, @empty_state)
  end
end
