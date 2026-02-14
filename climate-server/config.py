from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    host: str = "0.0.0.0"
    port: int = 8100
    data_dir: str = "./data"

    # CDS API (optional — set if using ERA5-Land monthly from Copernicus)
    cds_url: str = ""
    cds_key: str = ""

    model_config = {"env_prefix": "CLIMATE_", "env_file": ".env"}


settings = Settings()
