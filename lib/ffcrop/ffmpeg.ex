defmodule Ffcrop.Ffmpeg do
  require Logger
  alias Ffcrop.Ffmpeg.Args
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
    args = Args.build(input, output, options)
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
end
