defmodule Taxi.Application do
  use Application

  def start(_type, _args) do
    # Vamos a definir nuestras reglas de enrutamiento (dispatch) aquí
    # en el formato exacto que Cowboy espera.
    dispatch_rules = [
      {:_, # <-- Hacemos match en cualquier "host"
       [
         # 1. Si la ruta (path) es "/ws", la maneja el WebSocketHandler
         {"/ws", Taxi.WebSocketHandler, []},
         # 2. Cualquier otra ruta, la maneja nuestro Router (para el 404)
         {:_, Taxi.Router, []}
       ]}
    ]

    children = [
      # Hijos de tu lógica de negocio (los que ya tenías)
      {Registry, keys: :unique, name: Taxi.TripsRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Taxi.TripSupervisor},
      {Taxi.UserManager, []}, # (Asegúrate que este esté si hiciste la corrección de concurrencia)
      {Taxi.Server, []},

      # --- INICIO DE CÓDIGO CORREGIDO ---
      {Plug.Cowboy,
        scheme: :http,
        # El plug que usamos es el 'Dispatch' de Plug.Cowboy
        plug: Plug.Cowboy.Dispatch,
        # Las opciones para Plug.Cowboy y para el plug 'Dispatch'
        options: [
          port: 4000,
          # Pasamos nuestras reglas de enrutamiento bajo la llave :dispatch
          dispatch: dispatch_rules
        ]
      }
      # --- FIN DE CÓDIGO CORREGIDO ---
    ]

    opts = [strategy: :one_for_one, name: Taxi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
