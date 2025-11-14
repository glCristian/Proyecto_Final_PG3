defmodule Taxi.Logger do
  @moduledoc """
  Lightweight logger that appends human-readable events to data/results.log.
  """

  @log_path Path.expand("data/results.log", File.cwd!())

  def append(line) do
    ts = DateTime.utc_now() |> DateTime.to_iso8601()
    File.mkdir_p!(Path.dirname(@log_path))
    File.write!(@log_path, "#{ts}; #{line}\n", [:append])
    :ok
  end
end
