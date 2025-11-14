defmodule Taxi.UserManager do
  @moduledoc """
  File-backed users and scores.
  users.dat format: username;role;passhash;score
  roles: "cliente" | "conductor"
  """

  @path Path.expand("data/users.dat", File.cwd!())

  def ensure_storage! do
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
    ensure_storage!()
    @path
    |> File.read!()
    |> String.split(["\r", "\n"], trim: true)
    |> Enum.map(&parse/1)
    |> Enum.reject(&is_nil/1)
    |> Map.new(fn {u,r,h,s} -> {u, {r,h,s}} end)
  end

  defp flush(map) do
    body =
      map
      |> Enum.map(fn {u, {r,h,s}} -> serialize({u,r,h,s}) end)
      |> Enum.join("\n")
    File.write!(@path, body <> if(body == "", do: "", else: "\n"))
    :ok
  end

  @doc """
  Register or login a user. If not exists, creates with score 0 and given role.
  Returns {:ok, %{username: u, role: r, score: s}} | {:error, reason}
  """
  def login_or_register(username, password, role) when role in ["cliente","conductor"] do
    store = load()
    case Map.fetch(store, username) do
      {:ok, {r, h, s}} ->
        if h == hash(password) and r == role do
          {:ok, %{username: username, role: r, score: s}}
        else
          {:error, :invalid_credentials_or_role}
        end
      :error ->
        h = hash(password)
        new_store = Map.put(store, username, {role, h, 0})
        flush(new_store)
        {:ok, %{username: username, role: role, score: 0}}
    end
  end

  def add_score(username, delta) do
    store = load()
    case Map.fetch(store, username) do
      {:ok, {r,h,s}} ->
        s2 = s + delta
        flush(Map.put(store, username, {r,h,s2}))
        {:ok, s2}
      :error -> {:error, :not_found}
    end
  end

  def get_score(username) do
    store = load()
    with {:ok, {_,_,s}} <- Map.fetch(store, username), do: {:ok, s}, else: (_ -> {:error, :not_found})
  end

  def ranking(top_n \\ 10) do
    load()
    |> Enum.map(fn {u,{r,_h,s}} -> %{username: u, role: r, score: s} end)
    |> Enum.sort_by(& &1.score, :desc)
    |> Enum.take(top_n)
  end
end
