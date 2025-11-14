defmodule Taxi.UserManager do
  @moduledoc """
  GenServer-backed users and scores manager to ensure atomic operations.
  users.dat format: username;role;passhash;score
  roles: "cliente" | "conductor"
  """
  use GenServer
  require Logger

  # Usar la API correcta de bcrypt_elixir (módulo Bcrypt)
  alias Bcrypt

  @path Path.expand("data/users.dat", File.cwd!())

  # PUBLIC API (GenServer Calls) --------------------------------------------
  def start_link(opts), do: GenServer.start_link(__MODULE__, :ok, opts)
  def login_or_register(username, password, role), do: GenServer.call(__MODULE__, {:login_or_register, username, password, role})
  def add_score(username, delta), do: GenServer.call(__MODULE__, {:add_score, username, delta})
  def get_score(username), do: GenServer.call(__MODULE__, {:get_score, username})
  def ranking(top_n \\ 10), do: GenServer.call(__MODULE__, {:ranking, top_n})

  # GENSERVER CALLBACKS ------------------------------------------------------
  @impl true
  def init(:ok) do
    ensure_storage!()
    {:ok, load()}
  end

  @impl true
  def handle_call({:login_or_register, u, p, role}, _from, store) when role in ["cliente","conductor"] do
    case Map.fetch(store, u) do
      {:ok, {r, h, s}} ->
        # API correcta: Bcrypt.verify_pass/2
        if Bcrypt.verify_pass(p, h) and r == role do
          {:reply, {:ok, %{username: u, role: r, score: s}}, store}
        else
          {:reply, {:error, :invalid_credentials_or_role}, store}
        end

      :error ->
        # API correcta: Bcrypt.hash_pwd_salt/1
        h = Bcrypt.hash_pwd_salt(p)
        new_store = Map.put(store, u, {role, h, 0})
        flush(new_store)
        {:reply, {:ok, %{username: u, role: role, score: 0}}, new_store}
    end
  end

  @impl true
  def handle_call({:add_score, u, delta}, _from, store) do
    case Map.fetch(store, u) do
      {:ok, {r, h, s}} ->
        s2 = s + delta
        new_store = Map.put(store, u, {r, h, s2})
        flush(new_store)
        {:reply, {:ok, s2}, new_store}

      :error ->
        {:reply, {:error, :not_found}, store}
    end
  end

  @impl true
  def handle_call({:get_score, u}, _from, store) do
    case Map.fetch(store, u) do
      {:ok, {_, _, s}} -> {:reply, {:ok, s}, store}
      :error -> {:reply, {:error, :not_found}, store}
    end
  end

  @impl true
  def handle_call({:ranking, top_n}, _from, store) do
    ranking =
      store
      |> Enum.map(fn {u, {r, _h, s}} -> %{username: u, role: r, score: s} end)
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.take(top_n)

    {:reply, ranking, store}
  end

  @impl true
  def handle_call(msg, from, store) do
    Logger.warning("Received unexpected call: #{inspect(msg)} from #{inspect(from)}")
    {:reply, {:error, :unknown_command}, store}
  end

  # INTERNAL FILE FUNCTIONS --------------------------------------------------

  def ensure_storage! do
    File.mkdir_p!("data")
    if not File.exists?(@path), do: File.write!(@path, "")
    :ok
  end

  defp parse(line) do
    case String.split(line, ";") do
      [u, r, h, s] ->
        score =
          case Integer.parse(s) do
            {n, _} -> n
            :error -> 0
          end

        {u, {r, h, score}}

      [u, r, h] ->
        {u, {r, h, 0}}

      _ ->
        nil
    end
  end

  defp serialize({u, r, h, s}), do: Enum.join([u, r, h, Integer.to_string(s)], ";")

  defp load() do
    ensure_storage!()

    @path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&parse/1)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
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
