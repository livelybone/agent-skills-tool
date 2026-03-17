
# Jest / Vitest 标准与模式

## 基础结构

- `describe` 表达被测单元
- `it` 或 `test` 使用命名规范
- 每个 `it` 仅覆盖一个行为

## Mock 与隔离

- 模块级依赖使用 `jest.mock` / `vi.mock`
- 实例依赖使用 `jest.fn` / `vi.fn`
- 使用 `beforeEach` 重置 mock 状态
- 如使用 `spyOn`，测试后需 `restoreAllMocks`

示例：

```ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { fetchUser } from './fetchUser';
import { httpClient } from './httpClient';

vi.mock('./httpClient', () => ({
  httpClient: {
    get: vi.fn(),
  },
}));

describe('fetchUser', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('should return user when api succeeds', async () => {
    httpClient.get.mockResolvedValue({ id: '1' });

    const result = await fetchUser('1');

    expect(result).toEqual({ id: '1' });
  });
});
```

## 时间与随机性

- 使用 `jest.useFakeTimers` / `vi.useFakeTimers`
- 仅在需要时启用 fake timers，测试后恢复
- 避免真实 `Date.now` 与 `Math.random`

## 异步测试

- 对 Promise 使用 `await` 与 `resolves/rejects`
- 避免使用 `done` 回调

示例：

```ts
it('should throw when api fails', async () => {
  httpClient.get.mockRejectedValue(new Error('failed'));

  await expect(fetchUser('1')).rejects.toThrow('failed');
});
```

## 断言与快照

- 优先使用明确断言
- 快照用于稳定、低频变化的结构
- 避免对大对象或高频变更结构做快照

## 清理与恢复

- 使用 `afterEach` 清理 mock 与计时器
- 如使用环境变量，测试后恢复原值
