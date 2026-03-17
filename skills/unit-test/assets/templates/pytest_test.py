
import pytest
from subject import subject


class DummyDependency:
    def __init__(self, result=None, error=None):
        self._result = result
        self._error = error

    def method(self, _):
        if self._error:
            raise self._error
        return self._result


@pytest.fixture
def dependency():
    return DummyDependency(result="value")


def test_should_return_result_when_condition_is_met(dependency, monkeypatch):
    monkeypatch.setattr("subject.dependency", dependency)

    result = subject("input")

    assert result == "value"


def test_should_throw_when_condition_is_not_met(monkeypatch):
    monkeypatch.setattr("subject.dependency", DummyDependency(error=ValueError("failed")))

    with pytest.raises(ValueError, match="failed"):
        subject("input")
