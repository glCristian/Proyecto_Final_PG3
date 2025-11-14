defmodule Taxi.WebSocketHandler do
  @behaviour Plug.Cowboy.WebSocket
  require Jason

  # 1. init/2
  def init(req, state) do
    {:cowboy_websocket, req, state}
  end

  # 2. websocket_init/1
  # CORRECCIÓN: 'state' ahora es '_state' porque no se usa.
  def websocket_init(_state) do
    initial_state = %{current_user: nil}
    welcome_msg = Jason.encode!(%{type: "welcome", message: "UrbanFleet Server Connected. Ready for commands."})
    {:reply, {:text, welcome_msg}, initial_state}
  end

  # 3. websocket_handle/2
  def websocket_handle({:text, json_string}, state) do
    try do
      command_map = Jason.decode!(json_string)
      {response_map, new_state} = handle_json_command(command_map, state)
      {:reply, {:text, Jason.encode!(response_map)}, new_state}
    rescue
      _e ->
        error_map = %{type: "error", message: "Invalid JSON command"}
        {:reply, {:text, Jason.encode!(error_map)}, state}
    end
  end

  def websocket_handle(_frame, state) do
    {:ok, state}
  end

  # 4. websocket_info/2
  def websocket_info(_info, state) do
    {:ok, state}
  end

  # 5. terminate/2
  # CORRECCIÓN: 'state' ahora es '_state' porque no se usa.
  def terminate(_reason, %{current_user: user} = _state) do
    if user do
      Taxi.Server.disconnect(user.username)
    end
    :ok
  end
  def terminate(_reason, _state), do: :ok

  # --- LÓGICA DE COMANDOS ---

  # --- Comando: connect ---
  defp handle_json_command(%{"command" => "connect", "user" => u, "pass" => p, "role" => r}, state) do
    case Taxi.Server.connect(u, p, r) do
      {:ok, user} ->
        response = %{type: "ok_connect", user: user}
        new_state = %{state | current_user: user}
        {response, new_state}
      {:error, reason} ->
        response = %{type: "error", message: "Login failed: #{reason}"}
        {response, state}
    end
  end

  # --- Comando: disconnect ---
  defp handle_json_command(%{"command" => "disconnect"}, %{current_user: user} = state) do
    if user do
      Taxi.Server.disconnect(user.username)
      response = %{type: "ok_disconnect"}
      new_state = %{state | current_user: nil}
      {response, new_state}
    else
      # CORRECCIÓN: Aquí estaba el error.
      # No se puede usar 'response'. Llamamos al helper 'handle_not_connected'.
      handle_not_connected(state)
    end
  end
  defp handle_json_command(%{"command" => "disconnect"}, state), do: handle_not_connected(state)

  # --- Comando: request_trip ---
  defp handle_json_command(%{"command" => "request_trip", "origen" => o, "destino" => d}, %{current_user: user} = state) do
    if user do
      case Taxi.Server.request_trip(user.username, o, d) do
        {:ok, id} ->
          response = %{type: "ok_trip_request", id: id}
          {response, state}
        {:error, :invalid_location} ->
          response = %{type: "error", message: "Invalid location"}
          {response, state}
        {:error, reason} ->
          response = %{type: "error", message: "Error: #{inspect(reason)}"}
          {response, state}
      end
    else
      handle_not_connected(state)
    end
  end
  defp handle_json_command(%{"command" => "request_trip"}, state), do: handle_not_connected(state)

  # --- Comando: accept_trip ---
  defp handle_json_command(%{"command" => "accept_trip", "id" => id}, %{current_user: user} = state) do
    if user do
      case Taxi.Server.accept_trip(user.username, id) do
        {:ok, :started} ->
          response = %{type: "ok_trip_accepted"}
          {response, state}
        {:error, :not_available} ->
          response = %{type: "error", message: "Trip not available"}
          {response, state}
        {:error, reason} ->
          response = %{type: "error", message: "Error: #{inspect(reason)}"}
          {response, state}
      end
    else
      handle_not_connected(state)
    end
  end
  defp handle_json_command(%{"command" => "accept_trip"}, state), do: handle_not_connected(state)

  # --- Comandos "Get" ---
  defp handle_json_command(%{"command" => "list_trips"}, state) do
    trips = Taxi.Server.list_trips()
    response = %{type: "ok_list_trips", trips: trips}
    {response, state}
  end

  defp handle_json_command(%{"command" => "ranking"}, state) do
    ranking = Taxi.Server.ranking()
    response = %{type: "ok_ranking", ranking: ranking}
    {response, state}
  end

  defp handle_json_command(%{"command" => "my_score"}, %{current_user: user} = state) do
    if user do
      case Taxi.Server.my_score(user.username) do
        {:ok, score} ->
          response = %{type: "ok_my_score", score: score}
          {response, state}
        _ ->
          response = %{type: "error", message: "User score not found"}
          {response, state}
      end
    else
      handle_not_connected(state)
    end
  end
  defp handle_json_command(%{"command" => "my_score"}, state), do: handle_not_connected(state)

  # --- Comandos desconocidos o inválidos ---
  defp handle_json_command(%{"command" => cmd}, state) do
    response = %{type: "error", message: "Unknown command: #{cmd}"}
    {response, state}
  end

  defp handle_json_command(_, state) do
    response = %{type: "error", message: "Invalid command structure"}
    {response, state}
  end

  # Helper para cuando se requiere estar conectado
  defp handle_not_connected(state) do
    response = %{type: "error", message: "Not connected. Please 'connect' first."}
    {response, state}
  end
end
