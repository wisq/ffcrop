defmodule TimestampTest do
  use ExUnit.Case, async: true
  doctest Ffcrop.Timestamp
  alias Ffcrop.Timestamp

  test "parses number as seconds" do
    assert Timestamp.parse("123") == 123.0
    assert Timestamp.parse("123.456") == 123.456
  end

  test "parses minutes and seconds" do
    assert Timestamp.parse("5:43") == 343
    assert Timestamp.parse("05:43") == 343
    assert Timestamp.parse("23:34") == 1414
    assert Timestamp.parse("34:56.789") == 2096.789
  end

  test "parses hours, minutes, and seconds" do
    assert Timestamp.parse("5:43:21") == 20601
    assert Timestamp.parse("23:59:59.999") == 86399.999
  end

  test "rejects invalid timestamps" do
    assert_raise ArgumentError, fn -> Timestamp.parse("abc") end
    assert_raise ArgumentError, fn -> Timestamp.parse("123abc") end
    assert_raise ArgumentError, fn -> Timestamp.parse("123.abc") end
    assert_raise ArgumentError, fn -> Timestamp.parse("123.456x") end

    assert_raise ArgumentError, fn -> Timestamp.parse("abc:123") end
    assert_raise ArgumentError, fn -> Timestamp.parse("123abc:123") end
  end
end
