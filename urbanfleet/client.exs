defmodule Taxi.Client do
  use GenServer
  require Jason

  @moduledoc """
  El Cliente CLI de UrbanFleet (Versión GenServer).
  Uso: mix run --no-start client.exs ws://localhost:4000/ws
  """

  # --- Punto de Entrada (Cliente) ---
  def main(args) do
    case args do
      [url] ->
        {:ok, _} = Application.ensure_all_started(:gun)
        {:ok, _} = Application.ensure_all_started(:jason)
        {:ok, _} = Application.ensure_all_started(:crypto)

        IO.puts("Conectando a #{url}...")

        case GenServer.start_link(__MODULE__, %{url: url}) do
          {:ok, pid} ->
            Process.monitor(pid)
            wait_for_shutdown()
          {:error, {:shutdown, reason}} ->
            IO.puts(:stderr, "Error al iniciar el cliente: #{inspect(reason)}")
        end

      _ ->
        IO.puts(:stderr, @moduledoc)
    end
  end

  defp wait_for_shutdown do
    receive do
      {:DOWN, _, :process, _, reason} ->
        IO.puts("\nCliente desconectado (Razón: #{reason}).")
    end
  end

  # --- GenServer: Inicialización ---
  @impl true
  def init(%{url: url}) do
    uri = URI.parse(url)
    host_charlist = String.to_charlist(uri.host)
    path_string = uri.path || "/"
    path_charlist = String.to_charlist(path_string)
    port = uri.port || 80

    {:ok, conn} = :gun.open(host_charlist, port)

    ws_key = :crypto.strong_rand_bytes(16) |> :base64.encode()
    headers = [
      {"connection", "upgrade"},
      {"upgrade", "websocket"},
      {"sec-websocket-version", "13"},
      {"sec-websocket-key", ws_key}
    ]

    case :gun.ws_upgrade(conn, path_charlist, headers, %{owner: self()}) do
      {:ok, stream_ref} ->
        spawn(fn -> read_user_input(self()) end)
        {:ok, %{conn: conn, stream: stream_ref}}

      {:error, reason} ->
        {:stop, {:ws_upgrade_failed, reason}}
    end
  rescue
    e ->
      {:stop, {:connection_failed, e}}
  end

  # --- GenServer: Manejo de Mensajes (Eventos) ---
  @impl true
  def handle_info({:user_command, line}, state) do
    json_cmd = parse_line_to_json(line)
    :gun.ws_send(state.conn, state.stream, {:text, json_cmd})
    {:noreply, state}
  end

  @impl true
  def handle_info(:quit, state) do
    :gun.close(state.conn)
    {:stop, :normal, state}
  end

  # --- INICIO DE CORRECCIÓN ---
  # Evento 3: Recibimos un mensaje de texto (JSON) de :gun (el Servidor)
  @impl true
  def handle_info({:gun_ws, _conn, _stream, {:text, json_string}}, state) do
    IO.puts("") # Salto de línea
    handle_server_message(json_string) # Imprimimos la respuesta
    # LA LÍNEA ERRÓNEA 'IO.puts_prompt("> ")' HA SIDO ELIMINADA.
    {:noreply, state}
  end
  # --- FIN DE CORRECCIÓN ---

  @impl true
  def handle_info({:gun_ws_upgrade, _conn, _stream, _headers}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:gun_ws_close, _conn, _stream, status, reason}, state) do
    IO.puts("\nConexión cerrada por el servidor. Código: #{status}, Razón: #{reason}")
    {:stop, :remote_close, state}
  end

  @impl true
  def handle_info({:gun_error, _conn, _stream, reason}, state) do
    IO.puts("\nError de conexión: #{inspect(reason)}")
    {:stop, :gun_error, state}
  end

  @impl true
  def handle_info(_other, state) do
    {:noreply, state}
  end

  # --- Proceso Hijo: Lector de Teclado (Sin cambios) ---
  defp read_user_input(parent_pid) do
    case IO.gets("> ") |> String.trim() do
      "" ->
        read_user_input(parent_pid)
      "quit" ->
        send(parent_pid, :quit)
      line ->
        send(parent_pid, {:user_command, line})
        read_user_input(parent_pid)
    end
  end

  # --- Parseo de Comandos (Sin cambios) ---
  defp parse_line_to_json("connect " <> rest) do
    case String.split(rest, " ") do
      [u, p, r] -> Jason.encode!(%{command: "connect", user: u, pass: p, role: r})
      _ -> Jason.encode!(%{command: "invalid", message: "Uso: connect <user> <pass> <role>"})
    end
  end
  defp parse_line_to_json("request_trip " <> rest) do
    try do
      kv = Enum.map(String.split(rest, " "), fn pair ->
        [k, v] = String.split(pair, "=")
        {k, v}
      end) |> Map.new()
      Jason.encode!(%{command: "request_trip", origen: kv["origen"], destino: kv["destino"]})
    rescue
      _ -> Jason.encode!(%{command: "invalid", message: "Uso: request_trip origen=A destino=B"})
    end
  end
  defp parse_line_to_json("accept_trip " <> id) do
    Jason.encode!(%{command: "accept_trip", id: id})
  end
  defp parse_line_to_json("list_trips"), do: Jason.encode!(%{command: "list_trips"})
  defp parse_line_to_json("my_score"), do: Jason.encode!(%{command: "my_score"})
  defp parse_line_to_json("ranking"), do: Jason.encode!(%{command: "ranking"})
  defp parse_line_to_json("disconnect"), do: Jason.encode!(%{command: "disconnect"})
  defp parse_line_to_json("help"), do: Jason.encode!(%{command: "help"})
  defp parse_line_to_json(other) do
     Jason.encode!(%{command: "unknown", input: other})
  end

  # --- Manejo de Mensajes (Sin cambios) ---
  defp handle_server_message(json_string) do
    map = Jason.decode!(json_string)
    case map["type"] do
      "welcome" -> IO.puts("[SERVIDOR] #{map["message"]}")
      "ok_connect" -> IO.puts("[SERVIDOR] Conectado como: #{map["user"]["username"]} (#{map["user"]["role"]})")
      "ok_disconnect" -> IO.puts("[SERVIDOR] Desconectado.")
      "ok_trip_request" -> IO.puts("[SERVIDOR] Viaje creado. ID: #{map["id"]}")
      "ok_trip_accepted" -> IO.puts("[SERVIDOR] ¡Viaje aceptado! El viaje ha comenzado.")
      "ok_list_trips" ->
        IO.puts("[SERVIDOR] Viajes Disponibles:")
        Enum.each(map["trips"], fn t ->
          IO.puts("  - ID: #{t["id"]} | De: #{t["origin"]} | A: #{t["destination"]} | Cliente: #{t["client"]}")
        end)
        if Enum.empty?(map["trips"]), do: IO.puts("  (No hay viajes disponibles)")
      "ok_ranking" ->
        IO.puts("[SERVIDOR] Ranking:")
        Enum.each(map["ranking"], fn r ->
          IO.puts("  - #{r["username"]} (#{r["role"]}) | Puntos: #{r["score"]}")
        end)
      "ok_my_score" -> IO.puts("[SERVIDOR] Tu puntaje actual: #{map["score"]}")
      "error" -> IO.puts("[SERVIDOR] ERROR: #{map["message"]}")
      _ -> IO.puts("[SERVIDOR] (raw): #{json_string}")
    end
  rescue
    e -> IO.puts("[CLIENTE] Error al parsear JSON del servidor: #{inspect(e)}")
  end
end
