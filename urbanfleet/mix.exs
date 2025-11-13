defmodule Urbanfleet.MixProject do
  use Mix.Project

  def project do
    [
      app: :urbanfleet,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: [main_module: Taxi.CLI]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Taxi.Application, []}
    ]
  end

  defp deps do
    []
  end
end
