import { subject } from './subject';
import { dependency } from './dependency';

jest.mock('./dependency', () => ({
  dependency: {
    method: jest.fn(),
  },
}));

describe('subject', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('should return result when condition is met', () => {
    dependency.method.mockReturnValue('value');

    const result = subject('input');

    expect(result).toBe('value');
  });

  it('should throw when condition is not met', () => {
    dependency.method.mockImplementation(() => {
      throw new Error('failed');
    });

    expect(() => subject('input')).toThrow('failed');
  });
});
