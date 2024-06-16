defmodule Membrane.RTP.MJPEG.DepayloaderPipelineTest do
  @moduledoc false

  use ExUnit.Case

  import Membrane.ChildrenSpec
  import Membrane.Testing.Assertions

  alias Membrane.Buffer
  alias Membrane.RTP.MJPEG.{Depayloader, Fixtures}
  alias Membrane.Testing

  test "depayloader in pipeline" do
    data_base = 1..10
    glued_data = Fixtures.glued_fixtures()
    header = Fixtures.header()
    header_size = byte_size(header)

    pid =
      data_base
      |> Enum.flat_map(fn _idx ->
        Fixtures.all()
        |> Enum.map(&%Buffer{payload: &1})
        |> List.update_at(4, &%{&1 | metadata: %{rtp: %{marker: true}}})
      end)
      |> Testing.Source.output_from_buffers()
      |> start_pipeline()

    Enum.each(data_base, fn _i ->
      assert_sink_buffer(pid, :sink, %Buffer{payload: ^glued_data})
      assert <<^header::binary-size(header_size), _rest::binary>> = glued_data
    end)

    Testing.Pipeline.terminate(pid)
  end

  defp start_pipeline(data) do
    structure = [
      child(:source, %Testing.Source{output: data, stream_format: %Membrane.RTP{}})
      |> child(:depayloader, Depayloader)
      |> child(:sink, Testing.Sink)
    ]

    Testing.Pipeline.start_supervised!(spec: structure)
  end
end
