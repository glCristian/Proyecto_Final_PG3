defmodule Taxi.Trip do
  @moduledoc """
  A single trip request lifecycle with pending -> in_progress -> completed/expired.
  Start with start_link(%{id, client, origin, destination, duration: seconds, pending_ttl: seconds}).
  """
  use GenServer

  def start_link(args) do
    id = Map.fetch!(args, :id)
    GenServer.start_link(__MODULE__, args, name: via(id))
  end

  def via(id), do: {:via, Registry, {Taxi.TripsRegistry, id}}

  # API
  def info(id), do: GenServer.call(via(id), :info)
  def accept(id, driver), do: GenServer.call(via(id), {:accept, driver})

  # Server
  @impl true
  def init(%{id: id, client: client, origin: o, destination: d, duration: dur, pending_ttl: ttl}) do
    state = %{
      id: id,
      client: client,
      driver: nil,
      origin: o,
      destination: d,
      status: :pending,
      duration: dur,
      pending_ttl: ttl,
      timers: %{expire: Process.send_after(self(), :expire_pending, ttl * 1000), trip: nil}
    }
    {:ok, state}
  end

  @impl true
  def handle_call(:info, _from, state), do: {:reply, state, state}

  def handle_call({:accept, driver}, _from, %{status: :pending} = st) do
    st = cancel_expiry(st)
    trip_ref = Process.send_after(self(), :complete, st.duration * 1000)
    Taxi.Logger.append("trip #{st.id} accepted by #{driver}; client=#{st.client}; from=#{st.origin}; to=#{st.destination}; duration=#{st.duration}s")
    {:reply, {:ok, :started}, %{st | status: :in_progress, driver: driver, timers: %{expire: nil, trip: trip_ref}}}
  end
  def handle_call({:accept, _}, _from, st), do: {:reply, {:error, :not_available}, st}

  @impl true
  def handle_info(:expire_pending, %{status: :pending} = st) do
    Taxi.Logger.append("trip #{st.id} expired without driver; client=#{st.client}; from=#{st.origin}; to=#{st.destination}")
    Taxi.UserManager.add_score(st.client, -5)
    {:stop, :normal, %{st | status: :expired}}
  end

  def handle_info(:complete, %{status: :in_progress} = st) do
    Taxi.UserManager.add_score(st.client, 10)
    Taxi.UserManager.add_score(st.driver, 15)
    Taxi.Logger.append("trip #{st.id} completed; client=#{st.client}; driver=#{st.driver}; from=#{st.origin}; to=#{st.destination}")
    {:stop, :normal, %{st | status: :completed}}
  end

  defp cancel_expiry(%{timers: %{expire: nil}} = st), do: st
  defp cancel_expiry(%{timers: %{expire: tref}} = st) do
    Process.cancel_timer(tref)
    put_in(st.timers.expire, nil)
  end
end
