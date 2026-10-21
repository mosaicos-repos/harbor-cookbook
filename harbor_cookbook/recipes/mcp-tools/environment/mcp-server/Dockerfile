FROM python:3.12-slim

COPY --from=ghcr.io/astral-sh/uv:0.13.4 /uv /uvx /bin/

WORKDIR /app

COPY server.py .

EXPOSE 8000

CMD ["uv", "run", "server.py"]
