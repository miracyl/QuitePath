# Users Schema

## Table: USERS

Authentication table storing user credentials and verification status.

### Columns

| Column        | Type         | Constraints      | Default            | Description                   |
| ------------- | ------------ | ---------------- | ------------------ | ----------------------------- |
| ID            | BIGSERIAL    | PRIMARY KEY      | auto               | Internal auto-increment ID    |
| UUID          | UUID         | UNIQUE, NOT NULL | uuid_generate_v4() | External user identifier      |
| EMAIL         | VARCHAR(255) | UNIQUE, NOT NULL | -                  | User email address            |
| HASH_PASSWORD | VARCHAR(255) | NOT NULL         | -                  | Password hash (bcrypt/argon2) |
| CREATED_AT    | TIMESTAMPTZ  | NOT NULL         | NOW()              | Registration timestamp        |
| UPDATED_AT    | TIMESTAMPTZ  | NOT NULL         | NOW()              | Last modification timestamp   |
| IS_VERIFIED   | BOOLEAN      | NOT NULL         | FALSE              | Email verification status     |

### SQL Definition

```sql
CREATE TABLE USERS (
    ID BIGSERIAL PRIMARY KEY,
    UUID UUID NOT NULL DEFAULT UUID_GENERATE_V4() UNIQUE,
    EMAIL VARCHAR(255) NOT NULL UNIQUE,
    HASH_PASSWORD VARCHAR(255) NOT NULL,
    CREATED_AT TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UPDATED_AT TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    IS_VERIFIED BOOLEAN NOT NULL DEFAULT FALSE
);
```

---

## Indexes

### IDX_USERS_UUID

Fast lookup by UUID for API operations.

```sql
CREATE INDEX IDX_USERS_UUID ON USERS(UUID);
```

**Usage:** Used by `FIND_USER_BY_UUID`, all UUID-based operations.

### IDX_USERS_EMAIL

Fast lookup by email for login and registration checks.

```sql
CREATE INDEX IDX_USERS_EMAIL ON USERS(EMAIL);
```

**Usage:** Used by `FIND_USER_BY_EMAIL`, `LOGIN_USER`, uniqueness checks.

---

## Triggers

### UPDATE_USERS_UPDATED_AT

Automatically updates `UPDATED_AT` timestamp on any row modification.

```sql
CREATE TRIGGER UPDATE_USERS_UPDATED_AT
BEFORE UPDATE ON USERS
FOR EACH ROW
EXECUTE FUNCTION UPDATE_UPDATED_AT_COLUMN();
```

**Trigger Function:**

```sql
CREATE OR REPLACE FUNCTION UPDATE_UPDATED_AT_COLUMN()
RETURNS TRIGGER AS $$
BEGIN
    NEW.UPDATED_AT = NOW();
    RETURN NEW;
END;
$$ LANGUAGE PLPGSQL;
```

**Behavior:** Fires before any UPDATE on USERS table, sets UPDATED_AT to current timestamp.

---

## Constraints

### Primary Key

- `ID` - BIGSERIAL PRIMARY KEY

### Unique Constraints

- `UUID` - Must be unique across all users
- `EMAIL` - Must be unique across all users

### Not Null Constraints

- `UUID`, `EMAIL`, `HASH_PASSWORD`, `CREATED_AT`, `UPDATED_AT`, `IS_VERIFIED`

---

## Sample Data

```sql
-- Example user record
 id |                 uuid                 |       email          | hash_password | created_at          | updated_at          | is_verified
----+--------------------------------------+----------------------+---------------+---------------------+---------------------+-------------
  1 | 550e8400-e29b-41d4-a716-446655440000 | john.doe@example.com | $2a$10$...   | 2026-01-28 10:00:00 | 2026-01-28 10:00:00 | t
  2 | 6ba7b810-9dad-11d1-80b4-00c04fd430c8 | jane@example.com     | $2a$10$...   | 2026-01-28 10:15:00 | 2026-01-28 10:15:00 | f
```

---

## Storage Considerations

- **UUID:** 16 bytes per row
- **EMAIL:** Variable, max 255 bytes
- **HASH_PASSWORD:** ~60 bytes (bcrypt) or ~100 bytes (argon2)
- **Indexes:** Additional ~32 bytes per row for both indexes combined

**Estimated row size:** ~350-400 bytes per user

---

## Related

- [Functions](functions.md) - All user operations
- [Error Codes](errors.md) - EMAIL_EXISTS error handling
