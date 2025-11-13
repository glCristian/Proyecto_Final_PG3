defmodule Taxi.UserManager do
  @moduledoc """
  File-backed users and scores.
  users.dat format: username;role;passhash;score
  roles: "cliente" | "conductor"
  """
  use GenServer

  @path Path.expand("data/users.dat", File.cwd!())

  # --- Public API ---

  # Función para iniciar el GenServer (se llamará desde application.ex)
  def start_link(_opts), do: GenServer.start_link(__MODULE__, %{}, name: __MODULE__)

  # Las funciones públicas ahora llaman al GenServer
  def login_or_register(username, password, role) do
    GenServer.call(__MODULE__, {:login_or_register, username, password, role})
  end

  def add_score(username, delta) do
    GenServer.call(__MODULE__, {:add_score, username, delta})
  end

  def get_score(username) do
    GenServer.call(__MODULE__, {:get_score, username})
  end

  def ranking(top_n \\ 10) do
    GenServer.call(__MODULE__, {:ranking, top_n})
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(_opts) do
    # Aseguramos el storage y cargamos los usuarios
    # en el estado del GenServer una sola vez.
    ensure_storage!()
    users_map = load()
    {:ok, users_map}
  end

  @impl true
  def handle_call({:login_or_register, username, password, role}, _from, store)
      when role in ["cliente", "conductor"] do
    case Map.fetch(store, username) do
      {:ok, {r, h, s}} ->
        if h == hash(password) and r == role do
          {:reply, {:ok, %{username: username, role: r, score: s}}, store}
        else
          {:reply, {:error, :invalid_credentials_or_role}, store}
        end

      :error ->
        h = hash(password)
        # Se actualiza el estado INTERNO y se persiste
        new_store = Map.put(store, username, {role, h, 0})
        flush(new_store) # Escribe en el archivo
        {:reply, {:ok, %{username: username, role: role, score: 0}}, new_store}
    end
  end

  @impl true
  def handle_call({:add_score, username, delta}, _from, store) do
    case Map.fetch(store, username) do
      {:ok, {r, h, s}} ->
        s2 = s + delta
        # Se actualiza el estado INTERNO y se persiste
        new_store = Map.put(store, username, {r, h, s2})
        flush(new_store) # Escribe en el archivo
        {:reply, {:ok, s2}, new_store}

      :error ->
        {:reply, {:error, :not_found}, store}
    end
  end

  @impl true
  def handle_call({:get_score, username}, _from, store) do
    reply =
      with {:ok, {_, _, s}} <- Map.fetch(store, username),
           do: {:ok, s},
           else: (_ -> {:error, :not_found})

    {:reply, reply, store}
  end

  @impl true
  def handle_call({:ranking, top_n}, _from, store) do
    reply =
      store
      |> Enum.map(fn {u, {r, _h, s}} -> %{username: u, role: r, score: s} end)
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.take(top_n)

    {:reply, reply, store}
  end


  defp ensure_storage! do
    File.mkdir_p!(Path.dirname(@path))
    unless File.exists?(@path), do: File.write!(@path, "")
  end

  defp hash(pass), do: :crypto.hash(:sha256, pass) |> Base.encode16(case: :lower)

  defp parse(line) do
    case String.split(line, ";") do
      [u, r, h, s] -> {u, r, h, String.to_integer(s)}
      _ -> nil
    end
  end

  defp serialize({u, r, h, s}), do: Enum.join([u, r, h, Integer.to_string(s)], ";")

  defp load() do
    @path
    |> File.read!()
    |> String.split(["\r", "\n"], trim: true)
    |> Enum.map(&parse/1)
    |> Enum.reject(&is_nil/1)
    |> Map.new(fn {u, r, h, s} -> {u, {r, h, s}} end)
  end

  defp flush(map) do
    body =
      map
      |> Enum.map(fn {u, {r, h, s}} -> serialize({u, r, h, s}) end)
      |> Enum.join("\n")

    File.write!(@path, body <> if(body == "", do: "", else: "\n"))
    :ok
  end
end
