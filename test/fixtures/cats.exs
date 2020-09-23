#! /usr/bin/env elixir

# To generate cats.mp4, I grabbed a bunch of random images of the internet's
# favourite animal, then resized them down to 200x200:
#
#   convert -background white -gravity center orig/cat1.* -resize 200x200 -extent 200x200 cat1.png
#
# I ran this script to generate `frame_####.png` files, with each image lasting
# for 15-90 frames (average 52.5 frames).  Then I converted that into a
# slideshow video:
#
#   ffmpeg -framerate 30 -i frame_%04d.png output.mp4
#
# Since changing images typically results in an iframe, this gives us a file
# with more interesting iframe intervals.

defmodule Cats do
  @cats 0..9 |> Enum.map(fn n -> "../cat#{n}.png" end)

  def generate(frames) do
    1..frames
    |> Enum.reduce({0, nil}, &next_frame/2)
  end

  defp next_frame(num, old_cat) do
    {_, image} = new_cat = next_cat(old_cat)
    link_frame(image, frame_file(num))
    new_cat
  end

  defp next_cat({n, cat}) when n > 0, do: {n - 1, cat}

  defp next_cat({0, old_cat}) do
    new_cat =
      @cats
      |> List.delete(old_cat)
      |> Enum.random()

    frames = Enum.random(5..30) + Enum.random(5..30) + Enum.random(5..30)

    {frames, new_cat}
  end

  defp link_frame(source, target) do
    IO.puts("#{source} => #{target}")
    File.ln!(source, target)
  end

  defp frame_file(num) do
    :io_lib.format("frame_~4..0B.png", [num])
    |> List.to_string()
  end
end

[frames] = System.argv()

frames
|> String.to_integer()
|> Cats.generate()
