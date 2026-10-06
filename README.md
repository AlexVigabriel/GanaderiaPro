# GanaderíaPro

Sistema de gestión ganadera: sitio público informativo, API (backend) y aplicación web/móvil.

## Contenido del repositorio

| Carpeta | Qué es |
|---|---|
| `GanaderiaPro.Api` | API en ASP.NET Core: controladores y punto de entrada (`Program.cs`). |
| `GanaderiaPro.Application` | Reglas de negocio: servicios, DTOs e interfaces. |
| `GanaderiaPro.Domain` | Entidades del negocio (`Rancho`, `Usuario`, `Animal`), sin dependencias externas. |
| `GanaderiaPro.Infrastructure` | Base de datos con Entity Framework Core / PostgreSQL, repositorios, migraciones y seguridad (hash de contraseñas, JWT). |
| `GanaderiaPro.Tests` | Pruebas automatizadas del backend (xUnit + Moq). |
| `GanaderiaPro.App` | Aplicación Flutter (web y móvil) con sus pruebas. |
| `GanaderiaPro.SitioPublico` | Sitio público en HTML, CSS y JavaScript. |

## Ramas

- **`main`**: solo sprints cerrados. Cada cierre lleva una etiqueta (`sprint-1`, `sprint-2`, …).
- **`develop`**: integración. **Acá se trabaja.**
- **`feature/…`, `fix/…`, `docs/…`, `chore/…`**: ramas cortas que salen de `develop` y vuelven a ella por Pull Request.

## Requisitos

- [Git](https://git-scm.com/downloads)
- [.NET SDK 10](https://dotnet.microsoft.com/download)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Flutter](https://docs.flutter.dev/get-started/install) 3.47 o superior (canal stable)
- [Python 3](https://www.python.org/downloads/) (solo para servir el sitio público)
- Herramienta de migraciones de Entity Framework Core (una sola vez por computadora):

  ```
  dotnet tool install --global dotnet-ef
  ```

## 1. Descargar el código

**Primera vez:**

```
git clone https://github.com/AlexVigabriel/GanaderiaPro.git
cd GanaderiaPro
git checkout develop
```

**Actualizar una copia que ya tenés:**

```
git checkout develop
git pull origin develop
```

> Si tu copia es anterior al 01/10/2026, borrala y cloná de nuevo: ese día se reorganizó el historial y las copias viejas ya no coinciden.

## 2. Preparar el entorno (solo la primera vez)

1. Abrí Docker Desktop y levantá PostgreSQL. Crea el contenedor `ganaderiapro-db`, con los datos en un volumen para que no se pierdan al reiniciar:

   ```
   docker compose up -d
   ```

   El usuario y la contraseña del `docker-compose.yml` (`postgres` / `postgres`) son solo para tu base local en Docker.

2. Configurá tus claves locales. **No se suben al repositorio**: se guardan en tu computadora con el Secret Manager de .NET.

   ```
   dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Host=localhost;Port=5432;Database=ganaderiapro;Username=postgres;Password=postgres" --project GanaderiaPro.Api
   dotnet user-secrets set "Jwt:SigningKey" "una-clave-propia-de-32-caracteres-o-mas" --project GanaderiaPro.Api
   ```

   La segunda es la clave con la que se firman los inicios de sesión: sin ella la API no arranca. Inventá la tuya y no la compartas.

3. Creá las tablas en tu base local:

   ```
   dotnet ef database update --project GanaderiaPro.Infrastructure --startup-project GanaderiaPro.Api
   ```

## 3. Levantar el sistema

Cada parte va en su propia terminal, desde la raíz del repositorio:

| Parte | Comandos | Se abre en |
|---|---|---|
| API | `cd GanaderiaPro.Api`<br>`dotnet run --urls "http://localhost:5199"` | http://localhost:5199 |
| App | `cd GanaderiaPro.App`<br>`flutter pub get`<br>`flutter run -d chrome --web-port=8090` | http://localhost:8090 |
| Sitio público | `cd GanaderiaPro.SitioPublico`<br>`python -m http.server 8091` | http://localhost:8091 |

Los puertos importan: la app busca la API en el **5199**, y los botones del sitio llevan a la app en el **8090**.

> Si Docker Desktop se cerró o reiniciaste la computadora, abrilo y encendé la base con `docker start ganaderiapro-db`.

## 4. Cada vez que bajes cambios

```
git checkout develop
git pull origin develop
dotnet ef database update --project GanaderiaPro.Infrastructure --startup-project GanaderiaPro.Api
cd GanaderiaPro.App
flutter pub get
```

El `database update` aplica las tablas o columnas nuevas, si las hay. Si no hay nada nuevo, no cambia nada.

## 5. Pruebas

```
dotnet test
cd GanaderiaPro.App
flutter test
```

GitHub Actions corre las dos (`Backend (.NET)` y `App (Flutter)`) en cada push y Pull Request a `main` o `develop`.

## 6. Cómo trabajar una historia de usuario

1. Partí de la última versión de `develop`:

   ```
   git checkout develop
   git pull origin develop
   git checkout -b feature/HU-XX-nombre-corto
   ```

2. Hacé commits chicos, con mensajes en español que digan qué cambia.
3. Subí tu rama: `git push -u origin feature/HU-XX-nombre-corto`
4. Abrí un **Pull Request hacia `develop`** (nunca hacia `main`) y mencioná el Issue de la historia (por ejemplo `Refs #8`).
5. Se une cuando las pruebas están en verde y lo aprueba @AlexVigabriel.

## Agregar una entidad nueva (migración)

```
dotnet ef migrations add NombreDeLaMigracion --project GanaderiaPro.Infrastructure --startup-project GanaderiaPro.Api --output-dir Persistence/Migrations
dotnet ef database update --project GanaderiaPro.Infrastructure --startup-project GanaderiaPro.Api
```
