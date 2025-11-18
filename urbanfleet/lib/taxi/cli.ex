defmodule Taxi.CLI do
  @moduledoc """
  Distributed Interactive CLI.
  Connects to a remote Taxi.Server node specified by SERVER_NODE env var.
  """
  require Logger

  def start do
    IO.puts("UrbanFleet CLI (Distributed) — type 'help' for commands.\n")
    # El check ahora se hace aquí, al iniciar, llamando a la nueva función.
    IO.puts("Attempting to connect to server node: #{server_node()} ...")
    loop(%{current_user: nil})
  end

  defp loop(state) do
    prompt = if state.current_user, do: "(#{state.current_user.username})> ", else: "> "

    case IO.gets(prompt) do
      :eof ->
        :ok

      nil ->
        :ok

      line ->
        state = handle(String.trim(line), state)
        loop(state)
    end
  end

  defp handle("", st), do: st

  defp handle("quit", st),
    do:
      (
        IO.puts("bye")
        System.halt(0)
        st
      )

  defp handle("help", st) do
    IO.puts("""
    +------------------------------------------------------------------+
    |                    UrbanFleet - Comandos                         |
    +------------------------------------------------------------------+

    Uso General:
      connect <usuario> <contraseña> <rol>
          ->Inicia sesión o registra un usuario.
          (rol: cliente | conductor)

      disconnect
          ->Cierra la sesión del usuario actual.

      my_score
          ->Muestra tu puntuación acumulada.

      ranking
          ->Muestra la tabla de puntuaciones de todos los usuarios.

      help
          ->Muestra este mensaje de ayuda.

      quit
          ->Cierra la aplicación.

    Cliente:
      request_trip origen=<lugar> destino=<lugar>
          ->Solicita un nuevo viaje.

    Conductor:
      list_trips
          ->Lista todos los viajes pendientes.

      accept_trip <id_del_viaje(trip_###)>
          ->Acepta un viaje pendiente.
    """)

    st
  end

  # --- Todos los handles apuntan a server_node() ---

  defp handle("list_trips", st) do
    trips = GenServer.call({Taxi.Server, server_node()}, :list_trips)

    Enum.each(trips, fn t ->
      IO.puts(
        "#{t.id} | #{t.status} | #{t.client} -> #{t.destination} (from #{t.origin}) driver=#{inspect(t.driver)}"
      )
    end)

    st
  end

  defp handle("ranking", st) do
    GenServer.call({Taxi.Server, server_node()}, :ranking)
    |> Enum.with_index(1)
    |> Enum.each(fn {r, i} -> IO.puts("#{i}. #{r.username} (#{r.role}) - #{r.score}") end)

    st
  end

  defp handle("my_score", %{current_user: nil} = st),
    do:
      (
        IO.puts("Not connected.")
        st
      )

  defp handle("my_score", %{current_user: u} = st) do
    case GenServer.call({Taxi.Server, server_node()}, {:my_score, u.username}) do
      {:ok, s} -> IO.puts("score=#{s}")
      _ -> IO.puts("not found")
    end

    st
  end

  defp handle("disconnect", %{current_user: nil} = st),
    do:
      (
        IO.puts("Not connected.")
        st
      )

  defp handle("disconnect", %{current_user: u} = st) do
    GenServer.call({Taxi.Server, server_node()}, {:disconnect, u.username})
    IO.puts("disconnected")
    %{st | current_user: nil}
  end

  defp handle(<<"connect ", rest::binary>>, st) do
    case String.split(rest, ~r/\s+/, trim: true) do
      [u, p, role] ->
        case GenServer.call({Taxi.Server, server_node()}, {:connect, u, p, role}) do
          {:ok, user} ->
            IO.puts("connected as #{user.username} (#{user.role})")
            %{st | current_user: user}

          {:error, :invalid_credentials_or_role} ->
            IO.puts("invalid credentials or role")
            st

          {:error, other} ->
            IO.puts("connection error: #{inspect(other)}")
            st
        end

      _ ->
        IO.puts("usage: connect <username> <password> <cliente|conductor>")
        st
    end
  end

  defp handle(<<"request_trip ", _rest::binary>>, %{current_user: nil} = st),
    do:
      (
        IO.puts("Not connected.")
        st
      )

  defp handle(<<"request_trip ", rest::binary>>, %{current_user: u} = st) do
    # Usa la función parse_kv (que ahora sí está incluida)
    kv = parse_kv(rest)

    with o when is_binary(o) <- Map.get(kv, "origen"),
         d when is_binary(d) <- Map.get(kv, "destino") do
      case GenServer.call({Taxi.Server, server_node()}, {:request_trip, u.username, o, d}) do
        {:ok, id} -> IO.puts("trip created id=#{id}")
        {:error, :invalid_location} -> IO.puts("invalid location (check data/locations.dat)")
        {:error, :not_connected} -> IO.puts("not connected")
        other -> IO.puts("error: #{inspect(other)}")
      end
    else
      _ -> IO.puts("usage: request_trip origen=<Loc> destino=<Loc>")
    end

    st
  end

  defp handle(<<"accept_trip ", _id::binary>>, %{current_user: nil} = st),
    do:
      (
        IO.puts("Not connected.")
        st
      )

  defp handle(<<"accept_trip ", id::binary>>, %{current_user: u} = st) do
    case GenServer.call({Taxi.Server, server_node()}, {:accept_trip, u.username, String.trim(id)}) do
      {:ok, :started} -> IO.puts("trip started; will auto-complete")
      {:error, :not_available} -> IO.puts("trip not available")
      {:error, :not_connected} -> IO.puts("not connected")
      other -> IO.puts("error: #{inspect(other)}")
    end

    st
  end

  defp handle(other, st) do
    IO.puts("unknown command: #{other}")
    st
  end

  # --- ¡LA FUNCIÓN QUE FALTABA! ---
  # (Copiada de tu archivo original)
  defp parse_kv(s) do
    s
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(fn pair -> String.split(pair, "=", parts: 2) end)
    |> Enum.filter(fn l -> length(l) == 2 end)
    |> Map.new(fn [k, v] -> {k, v} end)
  end


  defp server_node do
    case System.get_env("SERVER_NODE") do
      nil ->
        if Node.alive?() do
          Node.self()
        else
          raise """
          SERVER_NODE environment variable not set and node is not distributed.
          Use either:
            iex --name client@192.168.1.3 --remsh server@192.168.1.8
          or set SERVER_NODE before starting the CLI.
          """
        end

      name ->
        String.to_atom(name)
    end
  end
end
