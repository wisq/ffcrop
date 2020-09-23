defmodule Ffcrop.Timestamp do
  def parse(str) do
    case String.split(str, ":") do
      [secs] ->
        parse_secs(secs)

      [mins, secs] ->
        parse_int(mins, "minutes") * 60 + parse_secs(secs)

      [hrs, mins, secs] ->
        parse_int(hrs, "hours") * 3600 + parse_int(mins, "minutes") * 60 + parse_secs(secs)
    end
  end

  defp parse_secs(str) do
    case Float.parse(str) do
      {secs, ""} -> secs
      _ -> raise ArgumentError, "Cannot parse seconds: #{str}"
    end
  end

  defp parse_int(str, field) do
    String.to_integer(str)
  rescue
    ArgumentError -> raise ArgumentError, "Cannot parse #{field}: #{str}"
  end
end
