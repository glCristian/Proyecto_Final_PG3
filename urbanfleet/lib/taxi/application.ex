defmodule Taxi.Application do
  @moduledoc "OTP tree for UrbanFleet (Registry + DynamicSupervisor + Server)."
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Taxi.TripsRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Taxi.TripSupervisor},
      # AÑADIR ESTA LÍNEA ANTES DE Taxi.Server
      {Taxi.UserManager, []},
      {Taxi.Server, []}
    ]

    opts = [strategy: :one_for_one, name: Taxi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
