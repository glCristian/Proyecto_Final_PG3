defmodule Taxi.Application do
  @moduledoc """
  OTP tree for UrbanFleet (Registry + UserManager + DynamicSupervisor + Server).
  """
  use Application
  require Logger

  def start(_type, _args) do
    children =
      if System.get_env("ROLE") == "server" do
        # Si ROLE es "server", inicia toda la lógica
        Logger.info("Starting in SERVER mode...")
        [
          {Registry, keys: :unique, name: Taxi.TripsRegistry},
          {Taxi.UserManager, name: Taxi.UserManager},
          {DynamicSupervisor, strategy: :one_for_one, name: Taxi.TripSupervisor},
          {Taxi.Server, []}
        ]
      else
        # Si no, inicia vacío (modo cliente)
        Logger.info("Starting in CLIENT mode...")
        []
      end

    opts = [strategy: :one_for_one, name: Taxi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
