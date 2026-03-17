
# Pytest 标准与模式

## 基础结构

- 测试文件 `test_*.py`，函数 `test_*`
- 命名使用 `should_<expected>_when_<condition>`
- 每个测试函数覆盖一个行为

## Fixture 与隔离

- 使用 `@pytest.fixture` 管理依赖
- 外部依赖使用 `monkeypatch` 或 mock
- 避免真实网络与 IO

示例：

```python
import pytest
from my_module import fetch_user

class DummyClient:
    def __init__(self, result=None, error=None):
        self._result = result
        self._error = error

    def get(self, _):
        if self._error:
            raise self._error
        return self._result

@pytest.fixture
def client():
    return DummyClient(result={"id": "1"})


def test_should_return_user_when_api_succeeds(client, monkeypatch):
    monkeypatch.setattr("my_module.http_client", client)

    result = fetch_user("1")

    assert result == {"id": "1"}
```

## 参数化

- 使用 `@pytest.mark.parametrize` 覆盖边界条件
- 保持参数表简洁并标注意图
- 需要时补充 `ids` 提升可读性

## 异常断言

- 使用 `with pytest.raises(ExpectedError)`
- 避免捕获过宽异常类型

## 清理与恢复

- `monkeypatch` 自动恢复
- 使用 fixture 作用域控制资源生命周期
- 时间相关逻辑使用可控替身或 monkeypatch
