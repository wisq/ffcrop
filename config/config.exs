import Config

config :elixir, ansi_enabled: true
config :logger, :console, format: "$metadata[$level] $message\n"
