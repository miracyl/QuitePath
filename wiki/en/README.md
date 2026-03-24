# Database API Documentation

Complete reference for all database modules, schemas, functions, and procedures.

## 📦 Modules

### 1. [Users](users/README.md)

User authentication and management system.

- User registration and login
- Email verification
- Password management
- 8 functions for user operations

---

## Quick Reference

- **PostgreSQL Version:** 16 Alpine
- **Extensions:** uuid-ossp
- **Migration System:** Bash-based with automatic registration
- **Error Handling:** HINT-based error codes for application layer

## Getting Started

```bash
# Start database
make local

# Check migration status
make migrate-status

# Generate schema docs
make schema-generate
```

### Users Table

Authentication table storing user credentials and verification status.

| Column        | Type         | Description                   |
| ------------- | ------------ | ----------------------------- |
| ID            | BIGSERIAL    | Primary key, auto-increment   |
| UUID          | UUID         | Unique user identifier (v4)   |
| EMAIL         | VARCHAR(255) | Unique user email             |
| HASH_PASSWORD | VARCHAR(255) | Password hash (bcrypt/argon2) |
| CREATED_AT    | TIMESTAMPTZ  | User registration timestamp   |
| UPDATED_AT    | TIMESTAMPTZ  | Last update timestamp         |
| IS_VERIFIED   | BOOLEAN      | Email verification status     |

**Indexes:**

- `IDX_USERS_UUID` - Fast lookup by UUID
- `IDX_USERS_EMAIL` - Fast lookup by email

**Triggers:**

- `UPDATE_USERS_UPDATED_AT` - Auto-updates `updated_at` on row modification

## Functions

### CREATE_USER

Creates a new user with email and password hash.

**Parameters:**

- `P_EMAIL` (VARCHAR) - User email
- `P_HASH_PASSWORD` (VARCHAR) - Password hash

**Returns:**

```sql
TABLE (
    ID BIGINT,
    UUID UUID,
    EMAIL VARCHAR(255),
    CREATED_AT TIMESTAMPTZ
)
```

**Errors:**

- `EMAIL_EXISTS` (SQLSTATE 23505) - Email already registered

**Example:**

```sql
SELECT * FROM CREATE_USER('user@example.com', '$2a$10$...');
```

---

### CHANGE_PASSWORD

Changes user password by UUID.

**Parameters:**

- `P_UUID` (UUID) - User UUID
- `P_NEW_HASH_PASSWORD` (VARCHAR) - New password hash

**Returns:** `BOOLEAN` - `true` if successful, `false` if user not found

**Example:**

```sql
SELECT CHANGE_PASSWORD('550e8400-e29b-41d4-a716-446655440000', '$2a$10$...');
```

---

### CHANGE_EMAIL

Changes user email and resets verification status.

**Parameters:**

- `P_UUID` (UUID) - User UUID
- `P_NEW_EMAIL` (VARCHAR) - New email

**Returns:** `BOOLEAN` - `true` if successful, `false` if user not found

**Errors:**

- `EMAIL_EXISTS` (SQLSTATE 23505) - Email already in use

**Example:**

```sql
SELECT CHANGE_EMAIL('550e8400-e29b-41d4-a716-446655440000', 'newemail@example.com');
```

---

### VERIFY_USER

Marks user as verified.

**Parameters:**

- `P_UUID` (UUID) - User UUID

**Returns:** `BOOLEAN` - `true` if successful, `false` if user not found

**Example:**

```sql
SELECT VERIFY_USER('550e8400-e29b-41d4-a716-446655440000');
```

---

### UNVERIFY_USER

Marks user as unverified.

**Parameters:**

- `P_UUID` (UUID) - User UUID

**Returns:** `BOOLEAN` - `true` if successful, `false` if user not found

**Example:**

```sql
SELECT UNVERIFY_USER('550e8400-e29b-41d4-a716-446655440000');
```

---

### FIND_USER_BY_UUID

Retrieves user by UUID.

**Parameters:**

- `P_UUID` (UUID) - User UUID

**Returns:**

```sql
TABLE (
    ID BIGINT,
    UUID UUID,
    EMAIL VARCHAR(255),
    HASH_PASSWORD VARCHAR(255),
    CREATED_AT TIMESTAMPTZ,
    UPDATED_AT TIMESTAMPTZ,
    IS_VERIFIED BOOLEAN
)
```

**Example:**

```sql
SELECT * FROM FIND_USER_BY_UUID('550e8400-e29b-41d4-a716-446655440000');
```

---

### FIND_USER_BY_EMAIL

Retrieves user by email.

**Parameters:**

- `P_EMAIL` (VARCHAR) - User email

**Returns:**

```sql
TABLE (
    ID BIGINT,
    UUID UUID,
    EMAIL VARCHAR(255),
    HASH_PASSWORD VARCHAR(255),
    CREATED_AT TIMESTAMPTZ,
    UPDATED_AT TIMESTAMPTZ,
    IS_VERIFIED BOOLEAN
)
```

**Example:**

```sql
SELECT * FROM FIND_USER_BY_EMAIL('user@example.com');
```

---

### LOGIN_USER

Authenticates user with email and password.

**Parameters:**

- `P_EMAIL` (VARCHAR) - User email
- `P_HASH_PASSWORD` (VARCHAR) - Password hash

**Returns:**

```sql
TABLE (
    ID BIGINT,
    UUID UUID,
    EMAIL VARCHAR(255),
    IS_VERIFIED BOOLEAN,
    CREATED_AT TIMESTAMPTZ
)
```

**Returns empty result if credentials invalid.**

**Example:**

```sql
SELECT * FROM LOGIN_USER('user@example.com', '$2a$10$...');
```

## Error Codes

All database errors use PostgreSQL's EXCEPTION mechanism with HINT field for application-level codes.

### EMAIL_EXISTS

- **SQL State:** 23505 (UNIQUE_VIOLATION)
- **Hint Code:** `EMAIL_EXISTS`
- **Message:** "Email conflict"
- **Functions:** `CREATE_USER`, `CHANGE_EMAIL`
- **Reason:** Email already registered in the system

**Application Handling:**

```python
try:
    result = execute("SELECT * FROM CREATE_USER(%s, %s)", email, hash_pwd)
except psycopg2.Error as e:
    if e.pgcode == '23505' and 'EMAIL_EXISTS' in str(e):
        return {"error": "Email already registered"}
```

## Migration System

### Structure

```
migrations/
├── up/          # Forward migrations
├── down/        # Rollback migrations
└── seed/        # Test data (tied to versions)
```

### Creating Migrations

```bash
make migrate name=add_profiles
# Creates:
# - migrations/up/002_add_profiles.sql
# - migrations/down/002_add_profiles.sql
```

**Migration Template:**

```sql
BEGIN;

-- Your SQL code here

INSERT INTO SCHEMA_MIGRATIONS (VERSION, NAME)
VALUES ('002', 'add_profiles');

COMMIT;
```

### Rules

1. Migrations are **immutable** - never edit applied migrations
2. Each migration auto-registers in `schema_migrations` table
3. Version format: 3-digit number (001, 002, 003...)
4. Down migrations must fully revert up migration
5. Always wrap in BEGIN/COMMIT transaction

## Seed Data

Test data tied to specific migration versions.

### Creating Seed Files

```bash
# Create migrations/seed/002_example_profiles.sql
```

**Example:**

```sql
-- Seed data for migration 002
INSERT INTO profiles (user_id, bio) VALUES
(1, 'Test user bio'),
(2, 'Another test bio');
```

### Rules

1. Seed files named `{VERSION}_description.sql`
2. Applied automatically after corresponding migration
3. Used only in development (`make local`)
4. Not applied in production environments
5. Keep data minimal and realistic

### Application

Seed data applies automatically when running:

```bash
make local  # Applies migrations + seed files
```
