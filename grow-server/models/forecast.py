from datetime import datetime
from typing import Optional
from sqlalchemy import String, DateTime, Float, Integer, Index
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class ForecastRecord(Base):
    """ECMWF forecast record (hourly)."""

    __tablename__ = "forecast_records"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    lat: Mapped[float] = mapped_column(Float)
    lon: Mapped[float] = mapped_column(Float)
    forecast_time: Mapped[datetime] = mapped_column(DateTime, index=True)
    fetched_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Atmospheric
    temperature_2m: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    relative_humidity_2m: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    precipitation: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    weather_code: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    pressure_msl: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    wind_speed_10m: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    wind_direction_10m: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    wind_gusts_10m: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    sunshine_duration: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    surface_temperature: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    # Soil temperature (°C)
    soil_temp_0_7cm: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    soil_temp_7_28cm: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    soil_temp_28_100cm: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    soil_temp_100_255cm: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    # Soil moisture (m³/m³)
    soil_moisture_0_7cm: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    soil_moisture_7_28cm: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    soil_moisture_28_100cm: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    soil_moisture_100_255cm: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    runoff: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    __table_args__ = (
        Index("ix_forecast_loc_time", "lat", "lon", "forecast_time", unique=True),
    )
