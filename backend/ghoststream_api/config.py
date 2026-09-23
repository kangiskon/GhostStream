from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file='.env', extra='ignore')

    database_url: str = 'sqlite:///./ghoststream.db'
    jwt_secret: str = 'dev-only-change-me'
    access_token_minutes: int = 15
    refresh_token_days: int = 30
    apple_allowed_audiences: str = ''
    apple_team_id: str = ''
    smtp_host: str = ''
    smtp_port: int = 587
    smtp_username: str = ''
    smtp_password: str = ''
    smtp_from: str = 'support@ghoststreams.ink'
    public_web_base_url: str = 'https://ghoststreams.ink'


@lru_cache
def get_settings() -> Settings:
    return Settings()
