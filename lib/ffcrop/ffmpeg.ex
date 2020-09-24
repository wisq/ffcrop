defmodule Ffcrop.Ffmpeg do
  require Logger
  alias Ffcrop.Ffprobe
  alias IO.ANSI

  def process(input, output, options) do
    {start, stop} = crop_args(input, options)

    args =
      [
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

    :exec.run(
      [ffmpeg] ++ args,
      [
        :sync,
        {:stdout, &exec_stdout/3},
        {:stderr, &exec_stderr/3}
      ]
    )
    |> exec_result()
  end

  defp find_ffmpeg do
    case System.find_executable("ffmpeg") do
      path when is_binary(path) -> path
      nil -> raise "Cannot find ffmpeg in $PATH"
    end
  end

  defp exec_stdout(:stdout, _, message) do
    IO.write(:stdio, [ANSI.cyan(), message, ANSI.default_color()])
  end

  defp exec_stderr(:stderr, _, message) do
    IO.write(:stderr, [ANSI.light_yellow(), message, ANSI.default_color()])
  end

  defp exec_result({:error, [exit_status: code]}) do
    IO.puts(:stderr, "\n")
    raise "ffmpeg exited with code #{code}"
  end

  defp exec_result({:ok, []}) do
    IO.puts([
      "\n",
      ANSI.light_green(),
      "Success: ffmpeg exited normally.",
      ANSI.default_color()
    ])
  end

  defp crop_args(file, %{start: start_arg, stop: stop_arg, keyframe: mode}) do
    start_time = calculate_start(file, mode, start_arg)
    duration = calculate_duration(start_arg, start_time, stop_arg)

    {
      ["-ss", Float.to_string(start_time)],
      ["-t", Float.to_string(duration)]
    }
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
