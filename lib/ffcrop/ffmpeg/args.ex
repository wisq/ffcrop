defmodule Ffcrop.Ffmpeg.Args do
  require Logger
  alias Ffcrop.Ffprobe

  def build(input, output, options) do
    {start, stop} = crop_args(input, options)

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

  defp crop_args(_file, %{stop: stop_arg, keyframe: _mode}) do
    {
      [],
      ["-t", Float.to_string(stop_arg)]
    }
  end

  defp crop_args(_file, %{keyframe: _mode}) do
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
