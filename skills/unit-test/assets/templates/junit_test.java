import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

class SubjectTest {

    @Test
    void shouldReturnResultWhenConditionIsMet() {
        Subject subject = new Subject(new FakeDependency("value", null));

        String result = subject.execute("input");

        assertEquals("value", result);
    }

    @Test
    void shouldThrowWhenConditionIsNotMet() {
        Subject subject = new Subject(new FakeDependency(null, new IllegalStateException("failed")));

        IllegalStateException error = assertThrows(IllegalStateException.class, () -> subject.execute("input"));

        assertEquals("failed", error.getMessage());
    }
}

class FakeDependency implements Dependency {
    private final String result;
    private final RuntimeException error;

    FakeDependency(String result, RuntimeException error) {
        this.result = result;
        this.error = error;
    }

    @Override
    public String method(String input) {
        if (error != null) {
            throw error;
        }
        return result;
    }
}
