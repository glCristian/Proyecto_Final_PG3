# UrbanFleet — Proyecto Final de Programación III / Final Programming Project

---

## 🇪🇸 Descripción General

**UrbanFleet** es un sistema multijugador basado en consola (CLI) desarrollado en **Elixir** que simula una flota de taxis en tiempo real. El sistema permite que múltiples usuarios se conecten como **clientes** o **conductores**, soliciten viajes y gestionen la asignación de servicios utilizando concurrencia y supervisión dinámica.

El proyecto implementa conceptos fundamentales de **Programación Concurrente**, **Procesos**, **GenServer**, **DynamicSupervisor**, y **persistencia en archivos**, cumpliendo con los requisitos típicos de un proyecto final de la asignatura **Programación III**.

---

## 🇺🇸 Overview

**UrbanFleet** is a multiplayer command-line system developed in **Elixir** that simulates a real-time taxi fleet. The system allows multiple users to connect as **clients** or **drivers**, request trips, and manage service assignments using concurrency and dynamic supervision.

This project implements key concepts of **Concurrent Programming**, **Processes**, **GenServer**, **DynamicSupervisor**, and **file-based persistence**, meeting the typical requirements of a **Programming III final project**.

---

# Objetivos del Proyecto / Project Objectives

## 🇪🇸 Objetivos

* Implementar un sistema concurrente utilizando Elixir y OTP.
* Simular un entorno multiusuario en tiempo real.
* Gestionar solicitudes de viajes mediante procesos independientes.
* Utilizar supervisores dinámicos para la administración de procesos.
* Persistir información en archivos de texto.
* Implementar un sistema de puntuación y ranking.
* Aplicar principios de programación concurrente y manejo de procesos.

## 🇺🇸 Objectives

* Implement a concurrent system using Elixir and OTP.
* Simulate a real-time multi-user environment.
* Manage trip requests using independent processes.
* Use dynamic supervisors to manage processes.
* Persist information in text files.
* Implement a scoring and ranking system.
* Apply concurrency and process management principles.

---

# Tecnologías Utilizadas / Technologies Used

* Elixir
* Erlang OTP
* GenServer
* DynamicSupervisor
* Registry
* File-based persistence
* Command Line Interface (CLI)

---

# Arquitectura del Sistema / System Architecture

## Componentes principales / Main Components

### Taxi.Application

Supervisor principal del sistema.

Responsabilidades:

* Inicializar los componentes principales
* Gestionar la jerarquía de procesos
* Supervisar el sistema

---

### Taxi.Server

Servidor central del sistema.

Responsabilidades:

* Gestionar usuarios conectados
* Crear solicitudes de viaje
* Coordinar la comunicación entre procesos

---

### Taxi.Trip

Proceso independiente que representa un viaje.

Responsabilidades:

* Controlar el estado del viaje
* Manejar temporizadores
* Finalizar o cancelar el viaje

Estados posibles:

* pending
* in_progress
* completed
* expired

---

### Taxi.TripSupervisor

Supervisor dinámico encargado de administrar los procesos de viajes.

Responsabilidades:

* Crear procesos de viajes
* Supervisar procesos activos
* Reiniciar procesos si es necesario

---

### Taxi.UserManager

Módulo encargado de gestionar los usuarios.

Responsabilidades:

* Registro de usuarios
* Inicio de sesión
* Gestión de puntaje
* Persistencia en archivo

---

### Taxi.Logger

Módulo encargado de registrar eventos del sistema.

Responsabilidades:

* Registrar eventos
* Guardar historial
* Registrar fecha y hora

---

### Taxi.Location

Módulo encargado de validar ubicaciones.

Responsabilidades:

* Leer ubicaciones válidas
* Validar origen y destino

---

# Estructura del Proyecto / Project Structure

```
urbanfleet/

 ├── mix.exs
 ├── README.md

 ├── lib/
 │    └── taxi/
 │         ├── application.ex
 │         ├── server.ex
 │         ├── trip.ex
 │         ├── supervisor.ex
 │         ├── user_manager.ex
 │         ├── location.ex
 │         ├── logger.ex
 │         └── cli.ex

 ├── data/
 │    ├── users.dat
 │    ├── locations.dat
 │    └── results.log

 └── test/
```

---

# Requisitos del Sistema / System Requirements

## 🇪🇸 Requisitos

* Elixir 1.15 o superior
* Erlang OTP 25 o superior
* Terminal o consola

## 🇺🇸 Requirements

* Elixir 1.15 or higher
* Erlang OTP 25 or higher
* Terminal or command line

---

# Instalación / Installation

## Paso 1 — Instalar Elixir

### Windows

Descargar desde:

[https://elixir-lang.org/install.html](https://elixir-lang.org/install.html)

### Mac

```
brew install elixir
```

### Linux

```
sudo apt install elixir
```

---

## Paso 2 — Verificar instalación

```
elixir -v
```

---

## Paso 3 — Compilar el proyecto

```
cd urbanfleet

mix deps.get

mix compile
```

---

# Ejecución del Sistema / Running the System

## Ejecutar la aplicación

```
mix run -e "Taxi.CLI.start()"
```

---

# Comandos Disponibles / Available Commands

```
connect <usuario> <password> <cliente|conductor>

disconnect

request_trip origen=<Lugar> destino=<Lugar>

list_trips

accept_trip <trip_id>

my_score

ranking

help

quit
```

---

# Ejemplo de Uso / Usage Example

## Cliente

```
connect ana 123 cliente

request_trip origen=Parque destino=Centro
```

## Conductor

```
connect luis 123 conductor

list_trips

accept_trip trip_1
```

---

# Sistema de Puntaje / Scoring System

Acción | Puntos

Cliente completa viaje | +10

Conductor completa viaje | +15

Cliente cancela o expira viaje | -5

---

# Persistencia de Datos / Data Persistence

Archivo | Descripción

users.dat | Usuarios registrados

locations.dat | Ubicaciones válidas

results.log | Historial de eventos

---

# Concurrencia / Concurrency

Cada viaje es ejecutado como:

```
Un proceso independiente
```

Esto permite:

* Múltiples viajes simultáneos
* Ejecución en tiempo real
* Manejo seguro de procesos
* Escalabilidad del sistema

---

# Manejo de Errores / Error Handling

El sistema valida:

* Usuario conectado
* Ubicación válida
* Viaje disponible
* Estado del viaje

---

# Características Principales / Main Features

* Sistema multijugador
* Concurrencia en tiempo real
* Procesos independientes
* Supervisión dinámica
* Persistencia en archivos
* Sistema de ranking
* Interfaz CLI interactiva

---

# Autores / Author

Nombre: Jose Rodriguez, Cristian Bonilla, Juan Ospina

Programa: Ingeniería de Sistemas

Asignatura: Programación III

Universidad: Universidad del Quindio

Año: 2025

---

# Licencia / License

Proyecto académico desarrollado con fines educativos.
