# Коды Ошибок - Модуль Пользователей

Обработка ошибок для операций с пользователями через механизм EXCEPTION PostgreSQL с HINT кодами.

## EMAIL_EXISTS

**Описание:** Email уже зарегистрирован в системе.

### Детали

- **SQL State:** `23505` (UNIQUE_VIOLATION)
- **Код Hint:** `EMAIL_EXISTS`
- **Сообщение:** "Email conflict"
- **Функции:** `CREATE_USER`, `CHANGE_EMAIL`

### Когда возникает

- Попытка регистрации с существующим email
- Смена email на уже используемый

### Пример

```sql
-- Выбросит EMAIL_EXISTS если email существует
SELECT * FROM CREATE_USER('existing@example.com', '$2a$10$...');
```

---

## Обработка в приложении

### Python (psycopg2)

```python
from psycopg2 import errors

try:
    cursor.execute(
        "SELECT * FROM CREATE_USER(%s, %s)",
        (email, hashed_password)
    )
    result = cursor.fetchone()

except errors.UniqueViolation as e:
    if 'EMAIL_EXISTS' in str(e):
        return {
            "error": "EMAIL_EXISTS",
            "message": "Email уже зарегистрирован",
            "status": 409
        }
```

### Node.js (pg)

```javascript
try {
    const result = await pool.query("SELECT * FROM CREATE_USER($1, $2)", [
        email,
        hashedPassword,
    ]);
    return { success: true, user: result.rows[0] };
} catch (error) {
    if (error.code === "23505" && error.hint === "EMAIL_EXISTS") {
        return {
            error: "EMAIL_EXISTS",
            message: "Email уже зарегистрирован",
            statusCode: 409,
        };
    }
    throw error;
}
```

### Go (pq)

```go
import "github.com/lib/pq"

err := db.QueryRow(
    "SELECT * FROM CREATE_USER($1, $2)",
    email, hashedPassword,
).Scan(&user.ID, &user.UUID, &user.Email, &user.CreatedAt)

if err != nil {
    if pqErr, ok := err.(*pq.Error); ok {
        if pqErr.Code == "23505" && pqErr.Hint == "EMAIL_EXISTS" {
            return &AppError{
                Code:    "EMAIL_EXISTS",
                Message: "Email уже зарегистрирован",
                Status:  409,
            }
        }
    }
    return err
}
```

---

## HTTP коды состояния

| Код ошибки                | HTTP статус      | Описание               |
| ------------------------- | ---------------- | ---------------------- |
| EMAIL_EXISTS              | 409 Conflict     | Email уже используется |
| (Неверные учетные данные) | 401 Unauthorized | Вход не удался         |
| (Пользователь не найден)  | 404 Not Found    | Ресурс не существует   |

---

## Лучшие практики

### 1. Всегда проверяйте Hints

```python
# Плохо
if e.pgcode == '23505':
    return "Дубликат"

# Хорошо
if e.pgcode == '23505' and 'EMAIL_EXISTS' in str(e):
    return "Email уже зарегистрирован"
```

### 2. Понятные сообщения

```python
ERROR_MESSAGES = {
    'EMAIL_EXISTS': {
        'en': 'This email is already registered',
        'ru': 'Этот email уже зарегистрирован'
    }
}
```

### 3. Не раскрывайте детали БД

```python
# Плохо
return str(e)  # Раскрывает имена таблиц/колонок

# Хорошо
return {"error": "EMAIL_EXISTS", "message": "Email уже зарегистрирован"}
```
