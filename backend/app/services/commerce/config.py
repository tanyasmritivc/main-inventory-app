from functools import lru_cache
from urllib.parse import urlsplit

from fastapi import HTTPException
from pydantic import SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class CommerceSettings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix='FINDEZ_COMMERCE_', env_file='.env', extra='ignore')
    enabled: bool = False
    encryption_key: SecretStr | None = None
    shopify_client_id: str | None = None
    shopify_client_secret: SecretStr | None = None
    shopify_redirect_uri: str | None = None
    amazon_client_id: str | None = None
    amazon_client_secret: SecretStr | None = None
    amazon_application_id: str | None = None
    amazon_redirect_uri: str | None = None
    amazon_draft: bool = True

    @field_validator('shopify_redirect_uri', 'amazon_redirect_uri')
    @classmethod
    def https_callback(cls, value):
        if value is not None:
            url = urlsplit(value)
            if url.scheme != 'https' or not url.hostname or url.username or url.password or url.fragment or url.query:
                raise ValueError('Commerce callbacks must be HTTPS URLs without query or fragment.')
        return value

    def require(self, provider=None):
        if not self.enabled:
            raise HTTPException(503, 'Commerce integrations are not enabled yet.')
        if provider in ('shopify', 'amazon_seller'):
            prefix = 'shopify' if provider == 'shopify' else 'amazon'
            names = [f'{prefix}_client_id', f'{prefix}_client_secret', f'{prefix}_redirect_uri', 'encryption_key']
            if provider == 'amazon_seller':
                names.append('amazon_application_id')
            if any(not getattr(self, name) for name in names):
                raise HTTPException(503, 'This provider still needs developer-app configuration.')


@lru_cache
def settings():
    return CommerceSettings()
