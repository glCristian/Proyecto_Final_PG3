# UrbanFleet - Simulación de Flota de Taxis Distribuida

UrbanFleet es una aplicación de línea de comandos (CLI) desarrollada en Elixir que simula la gestión de una flota de taxis. Utiliza el framework OTP de Elixir para manejar procesos concurrentes, permitiendo que múltiples usuarios (clientes y conductores) interactúen en tiempo real a través de una red.

## Características

*   **Sistema de Usuarios:** Registro y login para roles de `cliente` y `conductor`. Las contraseñas se almacenan de forma segura usando `bcrypt`.
*   **Gestión de Viajes:** Los clientes pueden solicitar viajes, que se convierten en procesos `GenServer` individuales.
*   **Aceptación de Viajes:** Los conductores pueden listar y aceptar viajes pendientes.
*   **Sistema de Puntuación:** Los usuarios ganan o pierden puntos según sus acciones (viajes completados, expirados, etc.).
*   **Ranking:** Muestra una tabla de clasificación de usuarios basada en su puntuación.
*   **Arquitectura Distribuida:** Diseñado para funcionar en una red local (LAN), permitiendo que múltiples instancias de la CLI se conecten a un único nodo servidor central.

---

## Guía de Ejecución (Modo Distribuido en LAN)

Para que la aplicación funcione correctamente con múltiples usuarios, debe ejecutarse en modo distribuido. Esto implica un nodo **servidor** (que ejecuta la lógica principal) y uno o más nodos **cliente** (que se conectan al servidor).

### Requisitos Previos (en AMBOS PCs)

1.  **Instalar Elixir y Erlang.**
2.  Tener una copia completa del proyecto en ambos ordenadores.
3.  Abrir una terminal en la carpeta del proyecto y ejecutar:
    ```bash
    mix deps.get
    mix compile
    ```

### Paso 1: Sincronizar la "Cookie" de Seguridad

Ambos PCs deben compartir un secreto para poder comunicarse.

1.  **En el PC Servidor**, obtén la cookie:
    ```bash
    cat ~/.erlang.cookie
    ```
    Si el archivo no existe, puedes crear uno con `echo "un-secreto-muy-largo-y-dificil" > ~/.erlang.cookie`.

2.  **En el PC Cliente**, asegúrate de que el archivo `~/.erlang.cookie` tenga exactamente el mismo contenido que el del servidor.
    ```bash
    # Reemplaza "LA_COOKIE_DEL_SERVIDOR" con el valor real
    echo "LA_COOKIE_DEL_SERVIDOR" > ~/.erlang.cookie
    
    # Asegura los permisos correctos (muy importante)
    chmod 400 ~/.erlang.cookie
    ```

### Paso 2: Iniciar el Nodo Servidor

En el PC que actuará como servidor (ej. IP `192.168.1.8`):

```bash
# 1. Navega a la carpeta del proyecto
cd /ruta/a/urbanfleet

# 2. Establece la variable de entorno 'ROLE' para iniciar todos los procesos
export ROLE=server

# 3. Inicia el nodo con un nombre y su IP
iex --name server@192.168.1.8 -S mix
```
Deja esta terminal abierta. Verás un mensaje `[info] Starting in SERVER mode...`.

### Paso 3: Iniciar y Conectar el Nodo Cliente

En el PC cliente (ej. IP `192.168.1.3`):

```bash
# 1. Navega a la carpeta del proyecto
cd /ruta/a/urbanfleet

# 2. Apunta a la dirección del servidor con la variable de entorno 'SERVER_NODE'
export SERVER_NODE="server@192.168.1.8"

# 3. Inicia el nodo cliente con su propio nombre y IP
iex --name client@192.168.1.3 -S mix
```

### Paso 4: Usar la Aplicación

En **cualquiera de las terminales `iex`** (tanto la del servidor como la del cliente), puedes iniciar la interfaz de línea de comandos:

```elixir
# Dentro del prompt iex(...)>
Taxi.CLI.start()
```

Ahora puedes empezar a usar los comandos. Puedes abrir múltiples terminales cliente y todas se conectarán al mismo servidor.

---

## Comandos de la CLI

Una vez iniciada la CLI con `Taxi.CLI.start()`, puedes usar los siguientes comandos:

| Comando                                           | Descripción                                                  |
| ------------------------------------------------- | ------------------------------------------------------------ |
| `help`                                            | Muestra la lista de todos los comandos disponibles.          |
| `connect <user> <pass> <rol>`                     | Inicia sesión o registra un nuevo usuario. `rol` debe ser `cliente` o `conductor`. |
| `disconnect`                                      | Cierra la sesión del usuario actual.                         |
| `my_score`                                        | Muestra tu puntuación actual.                                |
| `ranking`                                         | Muestra una tabla con las puntuaciones de todos los usuarios. |
| `request_trip origen=<lugar> destino=<lugar>`     | **(Cliente)** Solicita un nuevo viaje.                       |
| `list_trips`                                      | **(Conductor)** Muestra los viajes pendientes de ser aceptados. |
| `accept_trip <id_del_viaje>`                      | **(Conductor)** Acepta un viaje de la lista.                 |
| `quit`                                            | Cierra la CLI.                                               |

---

## Nota sobre Firewalls

Si los nodos no se pueden conectar (especialmente en redes que no son domésticas), es probable que un firewall esté bloqueando la comunicación. En el **PC servidor**, necesitarás abrir el puerto `4369` y un rango de puertos para la comunicación de Elixir.

Ejemplo para `firewalld` en Linux:
```bash
# Abrir el puerto del "directorio" de nodos
sudo firewall-cmd --add-port=4369/tcp --permanent

# Abrir un rango para la comunicación
sudo firewall-cmd --add-port=4000-4050/tcp --permanent

# Aplicar los cambios
sudo firewall-cmd --reload
```
Luego, inicia el servidor indicando que use ese rango de puertos:
```bash
export ERL_AFLAGS="-kernel inet_dist_listen_min 4000 inet_dist_listen_max 4050"
iex --name server@192.168.1.8 -S mix
```
