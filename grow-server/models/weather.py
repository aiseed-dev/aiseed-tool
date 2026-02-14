from datetime import datetime
from typing import Optional
from sqlalchemy import String, DateTime, Float, Integer, Index
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class WeatherRecord(Base):
    __tablename__ = "weather_records"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    recorded_at: Mapped[datetime] = mapped_column(DateTime, index=True)
    received_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow
    )

    # Device info
    station_type: Mapped[str] = mapped_column(String(50), default="")
    passkey: Mapped[str] = mapped_column(String(100), default="")

    # Indoor (GW3000)
    temp_indoor_c: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    humidity_indoor: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    pressure_rel_hpa: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    pressure_abs_hpa: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    # Outdoor (WS90)
    temp_outdoor_c: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    humidity_outdoor: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    # Wind
    wind_dir: Mapped[Optional[float]] = mapped_column(Float, nullable=True)  # degrees
    wind_speed_ms: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    wind_gust_ms: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    wind_gust_max_daily_ms: Mapped[Optional[float]] = mapped_column(
        Float, nullable=True
    )

    # Solar / UV
    solar_radiation: Mapped[Optional[float]] = mapped_column(Float, nullable=True)  # W/m²
    uv_index: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    # Rain (mm)
    rain_rate_mm: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    rain_event_mm: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    rain_hourly_mm: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    rain_daily_mm: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    rain_weekly_mm: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    rain_monthly_mm: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    rain_yearly_mm: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    # Raw data (JSON string for any extra fields)
    raw_data: Mapped[str] = mapped_column(String, default="")

    __table_args__ = (
        Index("ix_weather_date", "recorded_at"),
    )
