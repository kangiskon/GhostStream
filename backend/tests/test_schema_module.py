import py_compile
from pathlib import Path


def test_schema_module_compiles_and_is_not_duplicated():
    path = Path('ghoststream_api/schemas.py')
    py_compile.compile(str(path), doraise=True)
    text = path.read_text()
    assert text.count('class SourceProfileUpsert') == 1
    assert text.count('class DeleteAccountRequest') == 1
    assert "pattern=r'^[0-9a-fA-F]{64}$'" in text
