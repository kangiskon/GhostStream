import pytest

from ghoststream_api.db import Base, engine
from ghoststream_api import models  # noqa: F401


@pytest.fixture(autouse=True)
def clean_database():
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    yield
    Base.metadata.drop_all(engine)
