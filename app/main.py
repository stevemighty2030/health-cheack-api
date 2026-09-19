import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL")
engine = create_async_engine(DATABASE_URL, echo=False) if DATABASE_URL else None
AsyncSessionLocal = (
    sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)
    if engine is not None
    else None
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    if engine is not None:
        try:
            async with engine.begin() as conn:
                await conn.execute(text("SELECT 1"))
        except Exception:
            pass
    yield


app = FastAPI(title="Health Check API", version="1.0.0", lifespan=lifespan)


@app.get("/")
async def read_root() -> dict[str, str]:
    return {"message": "FastAPI service is running"}


@app.get("/health")
async def health_check() -> dict[str, object]:
    if not DATABASE_URL or AsyncSessionLocal is None:
        return {"status": "degraded", "database": "not configured"}

    try:
        async with AsyncSessionLocal() as session:
            result = await session.execute(text("SELECT 1"))
            db_ok = result.scalar_one() == 1
    except Exception as exc:  # pragma: no cover - defensive path
        return {"status": "unhealthy", "database": "unavailable", "error": str(exc)}

    return {"status": "ok", "database": "connected" if db_ok else "unreachable"}
