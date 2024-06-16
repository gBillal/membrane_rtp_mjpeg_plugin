defmodule Membrane.RTP.MJPEG.JpegHeaderTest do
  @moduledoc false

  use ExUnit.Case

  alias Membrane.RTP.MJPEG.{JpegHeader, QuantizationTable}

  @payload <<0, 1000::24, 1, 60, 80, 60, 0x00, 0x01, 0x02, 0x03, 0xFF>>
  @invalid_type <<0, 0::24, 64, 60, 80, 60, 0x00, 0x01, 0x02, 0x03, 0xFF>>
  @invalid_payload <<0, 0::24>>

  test "parse jpeg header" do
    assert {:ok, {jpeg_header, <<0, 1, 2, 3, 255>>}} = JpegHeader.parse(@payload)

    assert %JpegHeader{
             pixel_format: :I420,
             fragment_offset: 1000,
             type_specific: 0,
             type: 1,
             q: 60,
             width: 640,
             height: 480
           } == jpeg_header
  end

  test "invalid payload" do
    assert {:error, :invalid_header} = JpegHeader.parse(@invalid_type)
    assert {:error, :invalid_header} = JpegHeader.parse(@invalid_payload)
  end

  test "make headers" do
    assert {:ok, {jpeg_header, _rest}} = JpegHeader.parse(@payload)

    {lqt, cqt} = QuantizationTable.make_tables(jpeg_header.q)
    data = JpegHeader.make_headers(jpeg_header, lqt, cqt)

    assert File.read!("test/fixtures/header.bin") == IO.iodata_to_binary(data)
  end
end
