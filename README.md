# GanaderíaPro — Backend

## Requisitos

- [.NET SDK 10](https://dotnet.microsoft.com/download)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)

## Cómo levantar el entorno local

1. Cloná el repositorio.
2. Levantá PostgreSQL con Docker (crea el contenedor `ganaderiapro-db`, con los datos guardados en un volumen para que no se pierdan al reiniciar):

   ```
   docker compose up -d
   ```

   El usuario/contraseña que trae el `docker-compose.yml` (`postgres` / `postgres`) es solo para tu base local en Docker — no es una credencial real ni protege nada expuesto a internet. Si querés, podés cambiarla en tu propia copia.

3. Configurá tu propia cadena de conexión. **No se sube al repositorio por seguridad** — se guarda localmente en tu máquina con el Secret Manager de .NET:

   ```
   dotnet user-secrets init --project GanaderiaPro.Api
   dotnet user-secrets set "ConnectionStrings:DefaultConnection" "Host=localhost;Port=5432;Database=ganaderiapro;Username=postgres;Password=postgres" --project GanaderiaPro.Api
   ```

4. Instalá la herramienta de migraciones de Entity Framework Core (una sola vez por máquina):

   ```
   dotnet tool install --global dotnet-ef
   ```

5. Creá las tablas en tu base local:

   ```
   dotnet ef database update --project GanaderiaPro.Infrastructure --startup-project GanaderiaPro.Api
   ```

6. Corré la API:

   ```
   dotnet run --project GanaderiaPro.Api
   ```

## Estructura del proyecto

- `GanaderiaPro.Domain` — entidades del negocio (`Rancho`, `Usuario`), sin dependencias externas.
- `GanaderiaPro.Application` — reglas de negocio e interfaces (contratos).
- `GanaderiaPro.Infrastructure` — implementación con Entity Framework Core / PostgreSQL, `DbContext` y migraciones.
- `GanaderiaPro.Api` — proyecto ejecutable (controladores, punto de entrada `Program.cs`).

## Si agregás una entidad nueva y necesitás una migración

```
dotnet ef migrations add NombreDeLaMigracion --project GanaderiaPro.Infrastructure --startup-project GanaderiaPro.Api --output-dir Persistence/Migrations
dotnet ef database update --project GanaderiaPro.Infrastructure --startup-project GanaderiaPro.Api
```
