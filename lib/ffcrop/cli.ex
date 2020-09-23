defmodule Ffcrop.CLI do
  alias Ffcrop.Timestamp

  def main(args) do
    parse_args(args)
    |> IO.inspect()
  end

  @options [
    help: :boolean,
    start: :string,
    stop: :string,
    keyframe: :string,
    audio: :integer
  ]

  @defaults [
    keyframe: "best",
    audio: 0
  ]

  @help """
  Takes the video file `inputfile`, crops it down to a shorter length, and
  puts the result in `outputfile`.  Can also do other operations like
  selecting audio tracks, etc.

  Uses `ffmpeg` under the hood.  Copies the input video and audio as-is, so
  it doesn't need to do a slow reencode and potentially lose quality.

  Because cropping on non-keyframes can lead to issues, there's some extra
  logic to find keyframes and snap to them (unless disabled).

  Valid options:

    --start <timestamp>
      Any video before this timestamp will be discarded.
      Note that this value is affected by the "--keyframe" option.

      Valid formats include fractional seconds ("123.456"), and can
      optionally include minutes ("12:34.56") and hours ("1:23:45.67").

    --stop <timestamp>
      Any video after this point will be discarded.  Same format as "--start".

    --keyframe <before/after/best/none>
      Determines behaviour if --start doesn't fall exactly on a keyframe.

      "before": Always snap (rewind) to the previous keyframe.
      "after":  Always snap (fast forward) to the next keyframe.
      "best":   Use "before" or "after", whichever is closest.
      "none":   Don't change the start time -- try to crop precisely.
                (May cause problems in some video players!)

      Defaults to "best".

    --audio <number>
      Pick a given audio track as the output track.

    --help
      This text.
  """

  defp parse_args(args) do
    {raw_opts, raw_args, invalid} = OptionParser.parse(args, strict: @options)

    {args, arg_errors} = check_args(raw_args)
    {opts, opt_errors} = Keyword.merge(@defaults, raw_opts) |> check_options()
    errors = check_invalid(invalid) ++ opt_errors ++ arg_errors

    if Enum.empty?(errors) do
      {args, opts}
    else
      usage(errors)
    end
  end

  defp check_invalid([]), do: []

  defp check_invalid(invalid) do
    valid_options = Enum.map(@options, fn {key, _} -> "--#{key}" end)

    Enum.map(invalid, fn {opt, _} ->
      case opt do
        "--host" ->
          "--host should be followed by a hostname or IP."

        opt ->
          if opt in valid_options do
            "Option #{opt} requires a value."
          else
            "Invalid option: #{opt}"
          end
      end
    end)
  end

  defp check_args([input, output]), do: {{input, output}, []}
  defp check_args(_), do: {nil, ["Must specify both input and output files."]}

  defp check_options(raw_opts) do
    Enum.reduce(raw_opts, {%{}, []}, &check_option/2)
  end

  def check_option({key, value}, {opts, errs}) do
    case option(key, value) do
      :ok ->
        {
          Map.put(opts, key, value),
          errs
        }

      {:ok, new_value} ->
        {
          Map.put(opts, key, new_value),
          errs
        }

      {:error, message} ->
        {
          opts,
          ["--#{key}: #{message}" | errs]
        }
    end
  rescue
    e in ArgumentError ->
      {
        opts,
        ["--#{key}: #{e.message}" | errs]
      }
  end

  defp option(:start, ts), do: {:ok, Timestamp.parse(ts)}
  defp option(:stop, ts), do: {:ok, Timestamp.parse(ts)}

  defp option(:keyframe, "before"), do: {:ok, :before}
  defp option(:keyframe, "after"), do: {:ok, :after}
  defp option(:keyframe, "best"), do: {:ok, :best}
  defp option(:keyframe, "none"), do: {:ok, :none}
  defp option(:keyframe, m), do: {:error, "Unknown mode: #{m}"}

  defp option(:audio, n) when is_integer(n), do: :ok

  defp option(:help, true) do
    IO.puts([
      "\n",
      usage_line(),
      "\n",
      @help
    ])

    exit(:normal)
  end

  defp usage_line do
    usage_line(:with_help) |> Enum.take(1)
  end

  defp usage_line(:with_help) do
    whoami = :escript.script_name()

    [
      ~s{Usage: #{whoami} [options] inputfile outputfile\n},
      ~s{  Run "#{whoami} --help" for more details.\n}
    ]
  end

  defp usage(errors) do
    IO.puts(:stderr, [
      "\n",
      errors |> Enum.map(fn e -> "ERROR: #{e}\n" end),
      "\n",
      usage_line(:with_help)
    ])

    System.halt(1)
    raise "should not get here"
  end
end
