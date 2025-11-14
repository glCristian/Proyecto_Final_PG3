defmodule Taxi.TripSupervisor do
  @moduledoc """
  Dynamic supervisor helper to start trips.
  """

  def start_trip(attrs) do
    spec = %{
      id: {:trip, attrs.id},
      start: {Taxi.Trip, :start_link, [attrs]},
      restart: :temporary,
      type: :worker
    }
    DynamicSupervisor.start_child(Taxi.TripSupervisor, spec)
  end
end
