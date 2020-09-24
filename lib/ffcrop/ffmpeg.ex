defmodule Ffcrop.Ffmpeg do
  require Logger
  alias Ffcrop.Ffprobe
  alias IO.ANSI

  defmodule Progress do
    defstruct(output: [])

    def add(prog, str) do
      report_time(str)
      %Progress{prog | output: [str | prog.output]}
    end

    @time_regex ~r/ time=(?<time>[\d:\.]+) /

    def report_time(str) do
      case Regex.named_captures(@time_regex, str) do
        %{"time" => t} -> IO.puts("Encoding: #{t}")
        nil -> :noop
      end
    end
  end

  defimpl Collectable, for: Progress do
    def into(original) do
      fun = fn
        thing, {:cont, str} -> Progress.add(thing, str)
        thing, :done -> thing
        _, :halt -> :ok
      end

      {original, fun}
    end
  end

  def process(input, output, options) do
    {start, stop} = crop_args(input, options)

    args =
      [
        "-nostdin",
        start,
        "-i",
        input,
        stop,
        ["-map", "0:v:0"],
        audio_args(options.audio),
        ["-vcodec", "copy"],
        ["-acodec", "copy"],
        output
      ]
      |> List.flatten()

    ffmpeg = find_ffmpeg()
    Logger.debug("Running: #{ffmpeg} #{Enum.join(args, " ")}")

    IO.puts("")

    System.cmd(
      ffmpeg,
      args,
      into: %Progress{},
      stderr_to_stdout: true
    )
    |> cmd_result()
  end

  defp find_ffmpeg do
    case System.find_executable("ffmpeg") do
      path when is_binary(path) -> path
      nil -> raise "Cannot find ffmpeg in $PATH"
    end
  end

  defp cmd_result({%Progress{}, 0}) do
    IO.puts([
      "\n",
      ANSI.light_green(),
      "Success: ffmpeg exited normally.",
      ANSI.default_color()
    ])
  end

  defp cmd_result({%Progress{output: out}, code}) do
    IO.puts(:stderr, [
      ANSI.light_red(),
      Enum.reverse(out),
      ANSI.default_color()
    ])

    raise "ffmpeg exited with code #{code}"
  end

  defp crop_args(file, %{start: start_arg, stop: stop_arg, keyframe: mode}) do
    start_time = calculate_start(file, mode, start_arg)
    duration = calculate_duration(start_arg, start_time, stop_arg)

    {
      ["-ss", Float.to_string(start_time)],
      ["-t", Float.to_string(duration)]
    }
  end

  defp crop_args(file, %{start: start_arg, keyframe: mode}) do
    start_time = calculate_start(file, mode, start_arg)

    {
      ["-ss", Float.to_string(start_time)],
      []
    }
  end

  defp crop_args(file, %{stop: stop_arg, keyframe: mode}) do
    {
      [],
      ["-t", Float.to_string(stop_arg)]
    }
  end

  defp crop_args(file, %{keyframe: _mode}) do
    {[], []}
  end

  defp calculate_start(_file, :none, time) do
    Logger.info("Keyframe snapping disabled; using raw start time of #{time}.")
    time
  end

  defp calculate_start(file, mode, time) do
    Ffprobe.find_keyframes(file, time)
    |> log_keyframes()
    |> select_keyframe(mode, time)
    |> log_selected_keyframe(mode)
  end

  defp calculate_duration(old_start, _new_start, stop_arg) do
    # TODO: fix this
    stop_arg - old_start
  end

  defp log_keyframes(frames) do
    Logger.info("Available keyframes: #{inspect(frames)}")
    frames
  end

  defp log_selected_keyframe(time, mode) do
    Logger.info(~s[Selected keyframe #{time} using mode "#{mode}".])
    time
  end

  defp select_keyframe([f, _], :before, _), do: f
  defp select_keyframe([f], :before, _), do: f

  defp select_keyframe([_f, f], :after, _), do: f
  defp select_keyframe([f], :after, _), do: f

  defp select_keyframe(frames, :best, t) do
    frames
    |> Enum.map(fn f -> {abs(f - t), f} end)
    |> Enum.sort()
    |> List.first()
    |> elem(1)
  end

  defp audio_args(track), do: ["-map", "0:a:#{track}"]
end
