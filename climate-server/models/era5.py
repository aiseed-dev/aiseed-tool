"""ERA5 monthly climate data record.

Stores monthly-aggregated climate data from multiple sources:
  - Open-Meteo Historical API  (ERA5 blend, 0.25°, immediate)
  - AWS S3 nsf-ncar-era5       (ERA5, 0.25°, NetCDF)
  - CDS API ERA5-Land monthly   (ERA5-Land, 0.1°)
"""

from datetime import datetime
from typing import Optional
from sqlalchemy import String, DateTime, Float, Integer, Index
from sqlalchemy.orm import Mapped, mapped_column

from database import Base


class ERA5ClimateRecord(Base):
    """Monthly climate data aggregated from ERA5 / ERA5-Land."""

    __tablename__ = "era5_climate_records"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    lat: Mapped[float] = mapped_column(Float)
    lon: Mapped[float] = mapped_column(Float)
    year: Mapped[int] = mapped_column(Integer)
    month: Mapped[int] = mapped_column(Integer)

    # Source metadata
    source: Mapped[str] = mapped_column(String(20))   # open_meteo / aws_s3 / cds_api
    dataset: Mapped[str] = mapped_column(String(20))   # era5 / era5_land
    resolution: Mapped[float] = mapped_column(Float)   # 0.25 or 0.1 degrees
    fetched_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    # Temperature (°C)
    temp_mean: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    temp_min: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    temp_max: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    # Precipitation (mm)
    precipitation_total: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    rain_total: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    snowfall_total: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    # Wind
    wind_speed_mean: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    wind_speed_max: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    wind_gusts_max: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    # Humidity & Pressure
    humidity_mean: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    pressure_mean: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    # Solar
    sunshine_hours: Mapped[Optional[float]] = mapped_column(Float, nullable=True)
    solar_radiation: Mapped[Optional[float]] = mapped_column(Float, nullable=True)  # MJ/m²

    # Evapotranspiration
    et0_total: Mapped[Optional[float]] = mapped_column(Float, nullable=True)  # mm/month

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

    __table_args__ = (
        Index(
            "ix_era5_loc_period_source",
            "lat", "lon", "year", "month", "source",
            unique=True,
        ),
        Index("ix_era5_year_month", "year", "month"),
    )
