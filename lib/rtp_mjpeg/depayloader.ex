defmodule Membrane.RTP.MJPEG.Depayloader do
  @moduledoc """
  Depayloads MJPEG RTP payloads into JPEG images.

  Based on [RFC 2435](https://datatracker.ietf.org/doc/html/rfc2435)
  """

  use Membrane.Filter

  require Membrane.Logger

  alias Membrane.{Buffer, JPEG, RTP}
  alias Membrane.Event.Discontinuity
  alias Membrane.RTP.MJPEG.{JpegHeader, QuantizationTable}

  def_input_pad :input, accepted_format: RTP, flow_control: :auto

  def_output_pad :output, accepted_format: JPEG, flow_control: :auto

  defmodule State do
    @moduledoc false
    defstruct frame: [], jpeg_header: nil
  end

  @impl true
  def handle_init(_ctx, _opts) do
    {[], %State{}}
  end

  @impl true
  def handle_stream_format(:input, _stream_format, _ctx, state) do
    {[], state}
  end

  @impl true
  def handle_buffer(:input, buffer, ctx, state) do
    with {:ok, pkt} <- JpegHeader.parse(buffer.payload) do
      handle_packet(pkt, buffer, ctx, state)
    else
      {:error, reason} ->
        log_malformed_buffer(buffer.payload, reason)
        {[], %State{}}
    end
  end

  @impl true
  def handle_event(:input, %Discontinuity{} = event, _ctx, state) do
    {[forward: event], %State{state | frame: [], jpeg_header: nil}}
  end

  @impl true
  def handle_event(pad, event, context, state), do: super(pad, event, context, state)

  defp handle_packet({%{fragment_offset: 0} = header, payload}, _buffer, _ctx, state) do
    unless Enum.empty?(state.frame) do
      Membrane.Logger.error("""
      Received new frame while waiting for the last buffer of the previous frame
      """)
    end

    {[], %{state | frame: [payload], jpeg_header: header}}
  end

  defp handle_packet({_header, payload}, buffer, ctx, state) when buffer.metadata.rtp.marker do
    {lqt, cqt} = QuantizationTable.make_tables(state.jpeg_header.q)
    frame_header = JpegHeader.make_headers(state.jpeg_header, lqt, cqt)

    complete_frame = Enum.reverse([payload | state.frame])
    buffer = %Buffer{buffer | payload: IO.iodata_to_binary([frame_header | complete_frame])}

    stream_action = prepare_stream_format_action(state, ctx)

    {stream_action ++ [buffer: {:output, buffer}], %State{state | frame: [], jpeg_header: nil}}
  end

  # invalid first packet
  defp handle_packet(_pkt, _buffer, _ctx, %{frame: []} = state) do
    Membrane.Logger.warning(
      "Received first packet with fragement_offset not equals to 0, discard"
    )

    {[], state}
  end

  defp handle_packet({_header, payload}, _buffer, _ctx, state) do
    {[], %{state | frame: [payload | state.frame]}}
  end

  defp prepare_stream_format_action(%State{jpeg_header: header}, ctx) do
    old_stream_format = ctx.pads.output.stream_format

    stream_format = %JPEG{
      width: header.width,
      height: header.height,
      pixel_format: header.pixel_format
    }

    if stream_format == old_stream_format,
      do: [],
      else: [stream_format: {:output, stream_format}]
  end

  defp log_malformed_buffer(packet, reason) do
    Membrane.Logger.warning("""
    An error occurred while parsing MJPEG RTP payload.
    Reason: #{reason}
    Packet: #{inspect(packet, limit: :infinity)}
    """)
  end
end
