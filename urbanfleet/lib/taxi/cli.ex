defmodule Taxi.CLI do
  @moduledoc """
  Interactive CLI. Build escript with `mix escript.build` then run `./urbanfleet`.
  Or run with `mix run -e "Taxi.CLI.start()"`.
  Commands:
    connect <username> <password> <cliente|conductor>
    disconnect
    request_trip origen=<Loc> destino=<Loc>
    list_trips
    accept_trip <trip_id>
    my_score
    ranking
    help | quit
  """

  def start do
    IO.puts("UrbanFleet CLI — type 'help' for commands.\n")
    loop(%{current_user: nil})
  end

  defp loop(state) do
    prompt = if state.current_user, do: "(#{state.current_user.username})> ", else: "> "
    case IO.gets(prompt) do
      :eof -> :ok
      nil -> :ok
      line ->
        state = handle(String.trim(line), state)
        loop(state)
    end
  end

  defp handle("", st), do: st
  defp handle("quit", st), do: (IO.puts("bye"); System.halt(0); st)
  defp handle("help", st) do
    IO.puts(@moduledoc)
    st
  end

  defp handle("list_trips", st) do
    trips = Taxi.Server.list_trips()
    Enum.each(trips, fn t ->
      IO.puts("#{t.id} | #{t.status} | #{t.client} -> #{t.destination} (from #{t.origin}) driver=#{inspect t.driver}")
    end)
    st
  end

  defp handle("ranking", st) do
    Taxi.Server.ranking()
    |> Enum.with_index(1)
    |> Enum.each(fn {r, i} -> IO.puts("#{i}. #{r.username} (#{r.role}) - #{r.score}") end)
    st
  end

  defp handle("my_score", %{current_user: nil} = st), do: (IO.puts("Not connected." ); st)
  defp handle("my_score", %{current_user: u} = st) do
    case Taxi.Server.my_score(u.username) do
      {:ok, s} -> IO.puts("score=#{s}")
      _ -> IO.puts("not found")
    end
    st
  end

  defp handle("disconnect", %{current_user: nil} = st), do: (IO.puts("Not connected." ); st)
  defp handle("disconnect", %{current_user: u} = st) do
    Taxi.Server.disconnect(u.username)
    IO.puts("disconnected")
    %{st | current_user: nil}
  end

  defp handle(<<"connect ", rest::binary>>, st) do
    case String.split(rest, ~r/\s+/, trim: true) do
      [u, p, role] ->
        case Taxi.Server.connect(u, p, role) do
          {:ok, user} -> IO.puts("connected as #{user.username} (#{user.role})"); %{st | current_user: user}
          {:error, _} -> IO.puts("invalid credentials or role"); st
        end
      _ -> IO.puts("usage: connect <username> <password> <cliente|conductor>"); st
    end
  end

  defp handle(<<"request_trip ", rest::binary>>, %{current_user: nil} = st), do: (IO.puts("Not connected." ); st)
  defp handle(<<"request_trip ", rest::binary>>, %{current_user: u} = st) do
    kv = parse_kv(rest)
    with o when is_binary(o) <- Map.get(kv, "origen"),
         d when is_binary(d) <- Map.get(kv, "destino") do
      case Taxi.Server.request_trip(u.username, o, d) do
        {:ok, id} -> IO.puts("trip created id=#{id}")
        {:error, :invalid_location} -> IO.puts("invalid location (check data/locations.dat)")
        {:error, :not_connected} -> IO.puts("not connected")
        other -> IO.puts("error: #{inspect other}")
      end
    else
      _ -> IO.puts("usage: request_trip origen=<Loc> destino=<Loc>")
    end
    st
  end

  defp handle(<<"accept_trip ", id::binary>>, %{current_user: nil} = st), do: (IO.puts("Not connected." ); st)
  defp handle(<<"accept_trip ", id::binary>>, %{current_user: u} = st) do
    case Taxi.Server.accept_trip(u.username, String.trim(id)) do
      {:ok, :started} -> IO.puts("trip started; will auto-complete")
      {:error, :not_available} -> IO.puts("trip not available")
      {:error, :not_connected} -> IO.puts("not connected")
      other -> IO.puts("error: #{inspect other}")
    end
    st
  end

  defp handle(other, st) do
    IO.puts("unknown command: #{other}")
    st
  end

  defp parse_kv(s) do
    s
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(fn pair -> String.split(pair, "=", parts: 2) end)
    |> Enum.filter(fn l -> length(l) == 2 end)
    |> Map.new(fn [k,v] -> {k,v} end)
  end
end
