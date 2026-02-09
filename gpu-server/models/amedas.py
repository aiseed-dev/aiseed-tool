from datetime import datetime
from typing import Optional
from sqlalchemy import String, DateTime, Float, Integer, Index
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class AmedasStation(Base):
    """Cached AMeDAS station master data."""

    __tablename__ = "amedas_stations"

    station_id: Mapped[str] = mapped_column(String(10), primary_key=True)
    type: Mapped[str] = mapped_column(String(2), default="")  # A, B, C, D, E
    kj_name: Mapped[str] = mapped_column(String(50), default="")  # 漢字名
    kn_name: Mapped[str] = mapped_column(String(50), default="")  # カナ名
    en_name: Mapped[str] = mapped_column(String(50), default="")  # 英語名
    lat: Mapped[float] = mapped_column(Float, default=0.0)
    lon: Mapped[float] = mapped_column(Float, default=0.0)
    alt: Mapped[float] = mapped_column(Float, default=0.0)  # 標高 m
    elems: Mapped[str] = mapped_column(String(20), default="")  # 観測要素フラグ
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow
    )


class AmedasRecord(Base):
    """AMeDAS observation record (10-minute interval)."""

    __tablename__ = "amedas_records"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    station_id: Mapped[str] = mapped_column(String(10), index=True)
    observed_at: Mapped[datetime] = mapped_column(DateTime, index=True)

    # Temperature (°C)
    temp: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    # Humidity (%)
    humidity: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    # Pressure (hPa)
    pressure: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    normal_pressure: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    # Wind
    wind_speed: Mapped[Optional[float]] = mapped_column(Float, nullable=True)  # m/s
    wind_direction: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)  # 16方位(1-16)
    # Precipitation (mm)
    precipitation_10m: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    precipitation_1h: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    precipitation_3h: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    precipitation_24h: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    # Sunshine (hours / 10min fraction)
    sun_10m: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    sun_1h: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    # Snow (cm)
    snow: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    snow_1h: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    snow_6h: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    snow_12h: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    snow_24h: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    # Visibility (m)
    visibility: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    __table_args__ = (
        Index("ix_amedas_station_time", "station_id", "observed_at", unique=True),
    )
