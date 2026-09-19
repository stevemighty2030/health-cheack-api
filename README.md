# FastAPI Health Check App

This project is a minimal FastAPI application for a health-check API, containerized with Docker and fronted by Nginx. It includes a PostgreSQL database service and a reverse proxy to demonstrate a simple production-style local stack.

## Features

- FastAPI app with `/` and `/health` endpoints
- PostgreSQL database service
- Nginx reverse proxy
- Docker Compose orchestration
- Environment-based configuration for secrets and database settings

## Project Structure

```text
.
├── app/
│   ├── __init__.py
│   └── main.py
├── Dockerfile
├── docker-compose.yml
├── nginx.conf
├── requirements.txt
├── .env.example
├── .env
├── .dockerignore
├── README.md
└── verify_app.py
```

## Requirements

- Docker
- Docker Compose

## Local Setup

1. Copy the example environment file if needed:

```bash
cp .env.example .env
```

2. Build and start the stack:

```bash
docker compose up --build
```

3. Access the services:

- App: http://localhost:8000
- Health check: http://localhost:8000/health
- Nginx: http://localhost
- PostgreSQL: localhost:5432

## Environment Variables

The app uses environment variables defined in `.env`:

```env
DATABASE_URL=postgresql+asyncpg://appuser:secret@db:5432/healthdb
POSTGRES_DB=healthdb
POSTGRES_USER=appuser
POSTGRES_PASSWORD=secret
```

Do not commit real secrets into version control. In production, use a secure secret management solution.

## API Endpoints

### GET /

Returns a simple welcome message.

Example response:

```json
{
  "message": "FastAPI service is running"
}
```

### GET /health

Returns the health status of the application and the database connection.

Example response:

```json
{
  "status": "ok",
  "database": "connected"
}
```

## Notes

- The app is intentionally simple and meant to be a base for containerization and infrastructure planning.
- A multi-stage Docker build is used to keep the final image smaller.
- Nginx is configured as a reverse proxy to the FastAPI container.
