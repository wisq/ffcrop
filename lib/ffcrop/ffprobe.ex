defmodule Ffcrop.Ffprobe do
  defmodule Frame do
    def parse(output) do
      String.split(output, "\n")
      |> parse_lines()
    end

    defp parse_lines([""]), do: []

    defp parse_lines(["[FRAME]" | lines]) do
      index =
        Enum.find_index(lines, fn
          "[/FRAME]" -> true
          _ -> false
        end)

      frame = Enum.take(lines, index) |> parse_frame()
      rest = Enum.drop(lines, index + 1)

      [frame | parse_lines(rest)]
    end

    defp parse_frame(lines) do
      Map.new(lines, fn line ->
        [key, value] = String.split(line, "=", parts: 2)
        frame_attr(key, value)
      end)
    end

    defp frame_attr("pkt_pts_time", secs) do
      {:time, String.to_float(secs)}
    end
  end

  def find_keyframes(file, time) do
    start = max(time - 30, 0)
    stop = max(time + 30, 30)

    args = [
      ["-read_intervals", "#{start}%#{stop}"],
      ["-select_streams", "v"],
      ["-skip_frame", "nokey"],
      "-show_frames",
      ["-show_entries", "frame=pkt_pts_time"],
      ["-v", "quiet"],
      file
    ]

    {out, 0} = System.cmd("ffprobe", List.flatten(args))
    Frame.parse(out) |> select_around(time)
  end

  defp select_around(frames, time) do
    frames
    |> Enum.map(fn %{time: t} -> t end)
    |> Enum.reduce_while([nil], fn t, [last_t] ->
      case t do
        ^time -> {:halt, [t]}
        t when t < time -> {:cont, [t]}
        t when t > time -> {:halt, [last_t, t]}
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
