from datetime import datetime, timezone, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from pydantic import BaseModel, ConfigDict, Field, StrictBool, field_validator


class PreferenceChange(BaseModel):
    model_config = ConfigDict(extra='forbid')
    expected_revision: int = Field(ge=0, strict=True)
    push_enabled: StrictBool | None = None
    in_app_enabled: StrictBool | None = None
    quiet_enabled: StrictBool | None = None
    quiet_start: int | None = Field(default=None, ge=0, le=1439, strict=True)
    quiet_end: int | None = Field(default=None, ge=0, le=1439, strict=True)
    timezone: str | None = Field(default=None, max_length=100)
    inventory_alerts: StrictBool | None = None
    capture_reminders: StrictBool | None = None
    show_details: StrictBool | None = None
    paused_until: datetime | None = None

    @field_validator('timezone')
    @classmethod
    def valid_timezone(cls, value):
        if value is None:
            raise ValueError('Choose a timezone')
        try:
            ZoneInfo(value)
        except (ZoneInfoNotFoundError, ValueError):
            raise ValueError('Choose a valid IANA timezone') from None
        return value

    @field_validator('paused_until')
    @classmethod
    def bounded_pause(cls, value):
        if value is not None and (value.tzinfo is None or value > datetime.now(timezone.utc)+timedelta(days=7, minutes=1)):
            raise ValueError('Pause for up to seven days')
        return value

    @field_validator('push_enabled','in_app_enabled','quiet_enabled','quiet_start','quiet_end','inventory_alerts','capture_reminders','show_details')
    @classmethod
    def not_null(cls, value):
        if value is None:
            raise ValueError('A value is required')
        return value


from uuid import UUID


class StockRule(BaseModel):
    model_config = ConfigDict(extra='forbid')
    item_id: UUID
    threshold: int | None = Field(ge=0, le=2147483647, strict=True)


class StockRulesChange(BaseModel):
    model_config = ConfigDict(extra='forbid')
    rules: list[StockRule] = Field(max_length=500)
    import_only: StrictBool = False
