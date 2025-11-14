defmodule Taxi.Location do
  @moduledoc """
  Loads and validates city locations from data/locations.dat (one per line).
  """
  @path Path.expand("data/locations.dat", File.cwd!())

  def list() do
    if File.exists?(@path) do
      @path
      |> File.read!()
      |> String.split(["\r", "\n"], trim: true)
      |> Enum.reject(&(&1 == ""))
      |> MapSet.new()
    else
      MapSet.new()
    end
  end

  def valid?(loc), do: MapSet.member?(list(), loc)
end
