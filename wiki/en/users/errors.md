# Error Codes - Users Module

Error handling for user operations using PostgreSQL's EXCEPTION mechanism with HINT codes.

## EMAIL_EXISTS

**Description:** Email address already registered in the system.

### Details

- **SQL State:** `23505` (UNIQUE_VIOLATION)
- **Hint Code:** `EMAIL_EXISTS`
- **Message:** "Email conflict"
- **Functions:** `CREATE_USER`, `CHANGE_EMAIL`

### When It Occurs

- Attempting to register with existing email
- Changing email to one already in use

### Example

```sql
-- This will throw EMAIL_EXISTS if email exists
SELECT * FROM CREATE_USER('existing@example.com', '$2a$10$...');
```

---

## Handling in Application Layer

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
            "message": "Email already registered",
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
            message: "Email already registered",
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
                Message: "Email already registered",
                Status:  409,
            }
        }
    }
    return err
}
```

---

## HTTP Status Codes

| Error Code            | HTTP Status      | Description            |
| --------------------- | ---------------- | ---------------------- |
| EMAIL_EXISTS          | 409 Conflict     | Email already in use   |
| (Invalid credentials) | 401 Unauthorized | Login failed           |
| (User not found)      | 404 Not Found    | Resource doesn't exist |

---

## Best Practices

### 1. Always Check Hints

```python
# Bad
if e.pgcode == '23505':
    return "Duplicate entry"

# Good
if e.pgcode == '23505' and 'EMAIL_EXISTS' in str(e):
    return "Email already registered"
```

### 2. User-Friendly Messages

```python
ERROR_MESSAGES = {
    'EMAIL_EXISTS': {
        'en': 'This email is already registered',
        'ru': 'Этот email уже зарегистрирован'
    }
}
```

### 3. Don't Expose Database Details

```python
# Bad
return str(e)  # Exposes table/column names

# Good
return {"error": "EMAIL_EXISTS", "message": "Email already registered"}
```
