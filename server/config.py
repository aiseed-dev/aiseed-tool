from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    host: str = "0.0.0.0"
    port: int = 8100
    data_dir: str = "./data"

    # CDS API (optional — set if using ERA5-Land monthly from Copernicus)
    cds_url: str = ""
    cds_key: str = ""

    # AMeDAS 定期取得（カンマ区切りの地点ID、最大3箇所）
    amedas_stations: str = ""

    # SwitchBot Cloud API（温湿度計ポーリング）
    switchbot_token: str = ""
    switchbot_secret: str = ""
    switchbot_devices: str = ""  # カンマ区切りのデバイスID

    model_config = {"env_prefix": "CLIMATE_", "env_file": ".env"}


settings = Settings()
