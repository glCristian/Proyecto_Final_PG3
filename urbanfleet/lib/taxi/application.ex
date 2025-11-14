# File: Proyecto_Final_PG3/urbanfleet/lib/taxi/application.ex

defmodule Taxi.Application do
  @moduledoc """
  OTP tree for UrbanFleet (Registry + UserManager + DynamicSupervisor + Server).
  """
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Taxi.TripsRegistry},
      # AÑADIDO: UserManager como proceso supervisado
      {Taxi.UserManager, name: Taxi.UserManager},
      {DynamicSupervisor, strategy: :one_for_one, name: Taxi.TripSupervisor},
      {Taxi.Server, []}
    ]

    opts = [strategy: :one_for_one, name: Taxi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
