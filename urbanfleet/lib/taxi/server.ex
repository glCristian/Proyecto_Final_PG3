defmodule Taxi.Server do
  @moduledoc """
  Command-side façade (GenServer) used by the CLI to coordinate actions.
  """
  use GenServer

  def start_link(_), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  @impl true
  def init(_), do: {:ok, %{sessions: %{}, default_duration: 20, pending_ttl: 60}}

  # Public API (called by CLI)
  def connect(username, password, role) do
    GenServer.call(__MODULE__, {:connect, username, password, role})
  end

  def disconnect(username), do: GenServer.call(__MODULE__, {:disconnect, username})

  def request_trip(client, origin, destination) do
    GenServer.call(__MODULE__, {:request_trip, client, origin, destination})
  end

  def list_trips(), do: GenServer.call(__MODULE__, :list_trips)

  def accept_trip(driver, trip_id),
    do: GenServer.call(__MODULE__, {:accept_trip, driver, trip_id})

  def my_score(username), do: Taxi.UserManager.get_score(username)

  def ranking(), do: Taxi.UserManager.ranking(20)

  # Callbacks
  @impl true
  def handle_call({:connect, u, p, role}, _from, state) do
    Taxi.UserManager.ensure_storage!()

    case Taxi.UserManager.login_or_register(u, p, role) do
      {:ok, user} ->
        {:reply, {:ok, user}, put_in(state, [:sessions, u], %{role: role})}

      {:error, r} ->
        {:reply, {:error, r}, state}
    end
  end

  def handle_call({:disconnect, u}, _from, state) do
    {:reply, :ok, update_in(state, [:sessions], &Map.delete(&1, u))}
  end

  def handle_call({:request_trip, client, o, d}, _from, state) do
    cond do
      !Map.has_key?(state.sessions, client) ->
        {:reply, {:error, :not_connected}, state}

      !Taxi.Location.valid?(o) or !Taxi.Location.valid?(d) ->
        {:reply, {:error, :invalid_location}, state}

      true ->
        id = "trip_" <> Integer.to_string(:erlang.unique_integer([:positive]))

        {:ok, _pid} =
          Taxi.TripSupervisor.start_trip(%{
            id: id,
            client: client,
            origin: o,
            destination: d,
            duration: state.default_duration,
            pending_ttl: state.pending_ttl
          })

        Taxi.Logger.append("trip #{id} created by #{client}; from=#{o}; to=#{d}")
        {:reply, {:ok, id}, state}
    end
  end

  def handle_call(:list_trips, _from, state) do
    trips =
      Registry.select(Taxi.TripsRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
      |> Enum.map(fn id ->
        try do
          Taxi.Trip.info(id)
        rescue
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.filter(&(&1.status == :pending or &1.status == :in_progress))

    {:reply, trips, state}
  end

  def handle_call({:accept_trip, driver, id}, _from, state) do
    with true <- Map.has_key?(state.sessions, driver) do
      case Taxi.Trip.accept(id, driver) do
        {:ok, :started} -> {:reply, {:ok, :started}, state}
        {:error, r} -> {:reply, {:error, r}, state}
      end
    else
      _ -> {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call(:ranking, _from, state) do
    {:reply, Taxi.UserManager.ranking(20), state}
  end

  @impl true
  def handle_call({:my_score, username}, _from, state) do
    {:reply, Taxi.UserManager.get_score(username), state}
  end
end
