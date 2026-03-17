
# JUnit5 标准与模式

## 基础结构

- 类名使用 `*Test`
- 方法名使用 `should<Expected>When<Condition>`
- 使用 `@DisplayName` 补充可读描述（可选）

## 断言与组织

- 使用 `org.junit.jupiter.api.Assertions`
- 断言聚焦，避免过度组合
- 复杂断言拆成局部变量
- 使用 `@BeforeEach` 管理最小初始化

示例：

```java
import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

class UserServiceTest {

    @Test
    void shouldReturnUserWhenIdExists() {
        UserService service = new UserService(new FakeUserRepository());

        User user = service.getUser("1");

        assertEquals("1", user.id());
    }
}
```

## Mock 与隔离

- 优先通过构造函数注入依赖
- 如需 mock，使用 Mockito 并限制范围
- 不依赖真实网络或数据库

## 参数化测试

- 使用 `@ParameterizedTest` 与 `@ValueSource` 或 `@MethodSource`
- 每个参数化用例仍需清晰表达意图

## 异常断言

- 使用 `assertThrows` 验证异常类型与信息
