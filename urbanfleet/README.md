# UrbanFleet — Proyecto Final Programación III (Elixir)

Sistema multijugador en CLI que simula una flota de taxis con concurrencia, GenServers y un `DynamicSupervisor`.

## Ejecutar

```bash
# Requiere Elixir >= 1.15
cd urbanfleet
mix deps.get
mix compile

# Cargar algunas ubicaciones
printf "Parque\nCentro\nAeropuerto\nEstadio\nUniversidad\n" > data/locations.dat

# Iniciar CLI (instancia 1)
mix run -e "Taxi.CLI.start()"
# o construir escript
mix escript.build && ./urbanfleet
```

En la CLI:

```
> connect ana 123 cliente
> request_trip origen=Parque destino=Centro

# En otra terminal (otro usuario)
> connect luis 123 conductor
> list_trips
> accept_trip trip_...

# Esperar ~20s:
#  - Cliente +10 puntos
#  - Conductor +15 puntos
#  - Cliente -5 si expira sin conductor
```

Archivos de persistencia:

- `data/users.dat` — `username;role;passhash;score`
- `data/results.log` — Eventos con timestamp
- `data/locations.dat` — Ubicaciones válidas (una por línea)
