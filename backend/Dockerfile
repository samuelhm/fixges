# ---------- build ----------
FROM mcr.microsoft.com/dotnet/sdk:10.0.403-noble AS build
WORKDIR /src

COPY Fixges.Api/Fixges.Api.csproj Fixges.Api/
RUN dotnet restore Fixges.Api/Fixges.Api.csproj

COPY Fixges.Api/ Fixges.Api/
RUN dotnet publish Fixges.Api/Fixges.Api.csproj \
    --configuration Release \
    --output /app/publish \
    --no-restore \
    /p:UseAppHost=false

# ---------- runtime ----------
FROM mcr.microsoft.com/dotnet/aspnet:10.0.9-noble AS final
WORKDIR /app

# curl se usa únicamente para el healthcheck de Docker.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:8080 \
    ASPNETCORE_ENVIRONMENT=Production \
    DOTNET_NOLOGO=1 \
    DOTNET_CLI_TELEMETRY_OPTOUT=1

# Usuario no root incluido en la imagen oficial de .NET.
USER $APP_UID
EXPOSE 8080

ENTRYPOINT ["dotnet", "Fixges.Api.dll"]
