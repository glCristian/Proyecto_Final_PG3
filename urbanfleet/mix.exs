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
      extra_applications: [:logger, :crypto, :plug_cowboy], # <-- Añade :plug_cowboy aquí
      mod: {Taxi.Application, []}
    ]
  end

  defp deps do
    [
      {:plug_cowboy, "~> 2.6"},
      {:jason, "~> 1.4"},
      {:gun, "~> 2.0"}
    ]
  end
end
