defmodule Taxi.Router do
  use Plug.Router
  require Jason

  # Configura Plug para que use este router
  plug(:match)
  plug(:dispatch)

  # --- RUTAS ---

  # Si alguien hace un GET a la ruta "/", le respondemos
  get "/" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      200,
      Jason.encode!(%{status: "ok", app: "urbanfleet", transport: "websocket_only_at_ws"})
    )
  end

  # Si se intenta cualquier otra ruta, devolvemos un 404
  match _ do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(404, Jason.encode!(%{error: "not_found"}))
  end
end
