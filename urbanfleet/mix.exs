defmodule Urbanfleet.MixProject do
  use Mix.Project

  def project do
    [
      app: :urbanfleet,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      # configurar la cookie por defecto
      erl_opts: [cookie: :my_super_secret_cookie],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Taxi.Application, []}
    ]
  end

  defp deps do
    # AÑADIR ESTA DEPENDENCIA PARA HASHEO SEGURO DE CONTRASEÑAS
    [
      {:bcrypt_elixir, "~> 3.0"}
    ]
  end
end
