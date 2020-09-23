defmodule FfprobeTest do
  use ExUnit.Case, async: true
  doctest Ffcrop.Ffprobe
  alias Ffcrop.Ffprobe

  @blank "test/fixtures/blank.mp4"
  @cats "test/fixtures/cats.mp4"

  test "finds keyframes around time index" do
    assert Ffprobe.find_keyframes(@blank, 5.0) == [0.0, 10.0]
    assert Ffprobe.find_keyframes(@blank, 15.0) == [10.0, 20.0]
    assert Ffprobe.find_keyframes(@blank, 23.333) == [20.0, 30.0]

    assert Ffprobe.find_keyframes(@cats, 5) == [4.0, 5.7]
    assert Ffprobe.find_keyframes(@cats, 23) == [22.366667, 24.133333]
  end

  test "finds exact keyframe if matched" do
    assert Ffprobe.find_keyframes(@blank, 0.0) == [0.0]
    assert Ffprobe.find_keyframes(@blank, 10.0) == [10.0]
    assert Ffprobe.find_keyframes(@blank, 30.0) == [30.0]
    assert Ffprobe.find_keyframes(@blank, 50.0) == [50.0]

    assert Ffprobe.find_keyframes(@cats, 4.0) == [4.0]
    assert Ffprobe.find_keyframes(@cats, 5.7) == [5.7]
  end

  test "finds last keyframe if time is greater" do
    assert Ffprobe.find_keyframes(@blank, 60.0) == [50.0]
    assert Ffprobe.find_keyframes(@blank, 3600.0) == [50.0]

    assert Ffprobe.find_keyframes(@cats, 30.0) == [28.866667]
    assert Ffprobe.find_keyframes(@cats, 86400.0) == [28.866667]
  end

  test "finds first keyframe if time is less" do
    assert Ffprobe.find_keyframes(@blank, -1) == [0.0]
    assert Ffprobe.find_keyframes(@blank, -600) == [0.0]

    assert Ffprobe.find_keyframes(@cats, -1) == [0.0]
    assert Ffprobe.find_keyframes(@cats, -86400) == [0.0]
  end
end
