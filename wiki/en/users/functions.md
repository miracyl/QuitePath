# User Functions

Complete reference for all user management functions with parameters, returns, errors, and examples.

**Note:** All Python examples use **asyncpg==0.30.0** for async PostgreSQL operations.

## Table of Contents

1. [CREATE_USER](#create_user) - Register new user
2. [CHANGE_PASSWORD](#change_password) - Update password
3. [CHANGE_EMAIL](#change_email) - Update email
4. [VERIFY_USER](#verify_user) - Mark as verified
5. [UNVERIFY_USER](#unverify_user) - Mark as unverified
6. [FIND_USER_BY_UUID](#find_user_by_uuid) - Get user by UUID
7. [FIND_USER_BY_EMAIL](#find_user_by_email) - Get user by email
8. [LOGIN_USER](#login_user) - Authenticate user

---

## CREATE_USER

Creates a new user with email and password hash.

### Signature

```sql
CREATE_USER(
    P_EMAIL VARCHAR(255),
    P_HASH_PASSWORD VARCHAR(255)
) RETURNS TABLE (
    ID BIGINT,
    UUID UUID,
    EMAIL VARCHAR(255),
    CREATED_AT TIMESTAMPTZ
)
```

### Parameters

- `P_EMAIL` - User email address
- `P_HASH_PASSWORD` - Password hash (bcrypt/argon2)

### Returns

Table with user data (ID, UUID, EMAIL, CREATED_AT)

### Errors

- **EMAIL_EXISTS** (23505) - Email already registered

### SQL Example

```sql
SELECT * FROM CREATE_USER('user@example.com', '$2a$10$hash...');
```

### Python Example (asyncpg==0.30.0)

```python
import asyncpg
from typing import Optional

class UserRepository:
    def __init__(self, pool: asyncpg.Pool):
        self.pool = pool

    async def create_user(self, email: str, password_hash: str) -> Optional[dict]:
        """
        Create a new user.

        Args:
            email: User email address
            password_hash: Bcrypt/Argon2 password hash

        Returns:
            Dict with user data (id, uuid, email, created_at) or None if error

        Raises:
            EmailExistsError: If email already registered
        """
        async with self.pool.acquire() as conn:
            try:
                row = await conn.fetchrow(
                    "SELECT * FROM CREATE_USER($1, $2)",
                    email,
                    password_hash
                )

                if row:
                    return {
                        'id': row['id'],
                        'uuid': str(row['uuid']),
                        'email': row['email'],
                        'created_at': row['created_at']
                    }

            except asyncpg.UniqueViolationError as e:
                # Check hint for EMAIL_EXISTS
                if 'EMAIL_EXISTS' in str(e):
                    raise EmailExistsError(f"Email {email} already registered")
                raise
            except asyncpg.PostgresError as e:
                # Log and re-raise
                logger.error(f"Database error in create_user: {e}")
                raise

# Usage example
async def register_user_handler(email: str, password: str):
    """Registration handler with password hashing."""
    import bcrypt

    # Hash password
    password_hash = bcrypt.hashpw(
        password.encode('utf-8'),
        bcrypt.gensalt(rounds=12)
    ).decode('utf-8')

    # Create user
    try:
        user = await user_repo.create_user(email, password_hash)
        return {
            'success': True,
            'user': user
        }
    except EmailExistsError:
        return {
            'success': False,
            'error': 'EMAIL_EXISTS',
            'message': 'Email already registered'
        }
```

---

## CHANGE_PASSWORD

Updates user's password hash.

### Signature

```sql
CHANGE_PASSWORD(
    P_UUID UUID,
    P_NEW_HASH_PASSWORD VARCHAR(255)
) RETURNS BOOLEAN
```

### Parameters

- `P_UUID` - User's UUID
- `P_NEW_HASH_PASSWORD` - New password hash

### Returns

- `TRUE` - Password updated
- `FALSE` - User not found

### SQL Example

```sql
SELECT CHANGE_PASSWORD('550e8400-e29b-41d4-a716-446655440000', '$2a$10$new...');
```

### Python Example (asyncpg==0.30.0)

```python
async def change_password(self, user_uuid: str, new_password_hash: str) -> bool:
    """
    Change user's password.

    Args:
        user_uuid: User's UUID
        new_password_hash: New password hash

    Returns:
        True if password changed, False if user not found
    """
    async with self.pool.acquire() as conn:
        result = await conn.fetchval(
            "SELECT CHANGE_PASSWORD($1, $2)",
            user_uuid,
            new_password_hash
        )
        return result

# Usage example
async def change_password_handler(user_uuid: str, old_password: str, new_password: str):
    """Handler with old password verification."""
    import bcrypt

    # 1. Verify old password
    user = await user_repo.find_user_by_uuid(user_uuid)
    if not user:
        return {'error': 'User not found'}

    if not bcrypt.checkpw(old_password.encode(), user['hash_password'].encode()):
        return {'error': 'Invalid old password'}

    # 2. Hash new password
    new_hash = bcrypt.hashpw(new_password.encode(), bcrypt.gensalt(12)).decode()

    # 3. Update
    success = await user_repo.change_password(user_uuid, new_hash)
    return {'success': success}
```

---

## CHANGE_EMAIL

Updates user's email address and resets verification.

### Signature

```sql
CHANGE_EMAIL(
    P_UUID UUID,
    P_NEW_EMAIL VARCHAR(255)
) RETURNS BOOLEAN
```

### Parameters

- `P_UUID` - User's UUID
- `P_NEW_EMAIL` - New email address

### Returns

- `TRUE` - Email updated
- `FALSE` - User not found

### Errors

- **EMAIL_EXISTS** (23505) - Email already in use

### Side Effects

- Sets `IS_VERIFIED = FALSE`
- Updates `UPDATED_AT`

### Python Example (asyncpg==0.30.0)

```python
async def change_email(self, user_uuid: str, new_email: str) -> bool:
    """
    Change user's email and reset verification.

    Args:
        user_uuid: User's UUID
        new_email: New email address

    Returns:
        True if email changed, False if user not found

    Raises:
        EmailExistsError: If email already in use
    """
    async with self.pool.acquire() as conn:
        try:
            result = await conn.fetchval(
                "SELECT CHANGE_EMAIL($1, $2)",
                user_uuid,
                new_email
            )
            return result

        except asyncpg.UniqueViolationError as e:
            if 'EMAIL_EXISTS' in str(e):
                raise EmailExistsError(f"Email {new_email} already in use")
            raise

# Usage with email verification
async def change_email_handler(user_uuid: str, new_email: str):
    """Handler that triggers verification email."""
    try:
        success = await user_repo.change_email(user_uuid, new_email)

        if success:
            # Send verification email
            await email_service.send_verification(new_email)
            return {'success': True, 'message': 'Verification email sent'}
        else:
            return {'error': 'User not found'}

    except EmailExistsError:
        return {'error': 'EMAIL_EXISTS', 'message': 'Email already in use'}
```

---

## VERIFY_USER

Marks user as email-verified.

### Signature

```sql
VERIFY_USER(P_UUID UUID) RETURNS BOOLEAN
```

### Parameters

- `P_UUID` - User's UUID

### Returns

- `TRUE` - User verified
- `FALSE` - User not found

### Python Example (asyncpg==0.30.0)

```python
async def verify_user(self, user_uuid: str) -> bool:
    """Mark user as verified."""
    async with self.pool.acquire() as conn:
        return await conn.fetchval(
            "SELECT VERIFY_USER($1)",
            user_uuid
        )

# Usage in email verification handler
async def verify_email_handler(token: str):
    """Verify email from token."""
    # 1. Decode JWT token
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
        user_uuid = payload['uuid']
    except jwt.InvalidTokenError:
        return {'error': 'Invalid token'}

    # 2. Verify user
    success = await user_repo.verify_user(user_uuid)

    if success:
        return {'success': True, 'message': 'Email verified'}
    else:
        return {'error': 'User not found'}
```

---

## UNVERIFY_USER

Marks user as unverified.

### Signature

```sql
UNVERIFY_USER(P_UUID UUID) RETURNS BOOLEAN
```

### Parameters

- `P_UUID` - User's UUID

### Returns

- `TRUE` - User unverified
- `FALSE` - User not found

### Python Example (asyncpg==0.30.0)

```python
async def unverify_user(self, user_uuid: str) -> bool:
    """Mark user as unverified."""
    async with self.pool.acquire() as conn:
        return await conn.fetchval(
            "SELECT UNVERIFY_USER($1)",
            user_uuid
        )
```

---

## FIND_USER_BY_UUID

Retrieves complete user record by UUID.

### Signature

```sql
FIND_USER_BY_UUID(P_UUID UUID) RETURNS TABLE (
    ID BIGINT,
    UUID UUID,
    EMAIL VARCHAR(255),
    HASH_PASSWORD VARCHAR(255),
    CREATED_AT TIMESTAMPTZ,
    UPDATED_AT TIMESTAMPTZ,
    IS_VERIFIED BOOLEAN
)
```

### Parameters

- `P_UUID` - User's UUID

### Returns

Table with full user record (empty if not found)

### Python Example (asyncpg==0.30.0)

```python
async def find_user_by_uuid(self, user_uuid: str) -> Optional[dict]:
    """
    Find user by UUID.

    Args:
        user_uuid: User's UUID

    Returns:
        Dict with user data or None if not found
    """
    async with self.pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT * FROM FIND_USER_BY_UUID($1)",
            user_uuid
        )

        if row:
            return {
                'id': row['id'],
                'uuid': str(row['uuid']),
                'email': row['email'],
                'hash_password': row['hash_password'],
                'created_at': row['created_at'],
                'updated_at': row['updated_at'],
                'is_verified': row['is_verified']
            }
        return None

# Usage in middleware
async def get_current_user(user_uuid: str):
    """Get current user from UUID in JWT token."""
    user = await user_repo.find_user_by_uuid(user_uuid)

    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    # Don't expose password hash
    user.pop('hash_password')
    return user
```

---

## FIND_USER_BY_EMAIL

Retrieves complete user record by email.

### Signature

```sql
FIND_USER_BY_EMAIL(P_EMAIL VARCHAR(255)) RETURNS TABLE (
    ID BIGINT,
    UUID UUID,
    EMAIL VARCHAR(255),
    HASH_PASSWORD VARCHAR(255),
    CREATED_AT TIMESTAMPTZ,
    UPDATED_AT TIMESTAMPTZ,
    IS_VERIFIED BOOLEAN
)
```

### Python Example (asyncpg==0.30.0)

```python
async def find_user_by_email(self, email: str) -> Optional[dict]:
    """Find user by email."""
    async with self.pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT * FROM FIND_USER_BY_EMAIL($1)",
            email
        )

        if row:
            return dict(row)
        return None
```

---

## LOGIN_USER

Authenticates user with email and password.

### Signature

```sql
LOGIN_USER(
    P_EMAIL VARCHAR(255),
    P_HASH_PASSWORD VARCHAR(255)
) RETURNS TABLE (
    ID BIGINT,
    UUID UUID,
    EMAIL VARCHAR(255),
    IS_VERIFIED BOOLEAN,
    CREATED_AT TIMESTAMPTZ
)
```

### Parameters

- `P_EMAIL` - User's email
- `P_HASH_PASSWORD` - Password hash to verify

### Returns

Table with user data (empty if invalid credentials)

### Python Example (asyncpg==0.30.0)

```python
async def login_user(self, email: str, password: str) -> Optional[dict]:
    """
    Authenticate user with email and password.

    Args:
        email: User email
        password: Plain text password

    Returns:
        Dict with user data if authenticated, None otherwise
    """
    import bcrypt

    async with self.pool.acquire() as conn:
        # Get user with password hash
        user = await conn.fetchrow(
            "SELECT * FROM FIND_USER_BY_EMAIL($1)",
            email
        )

        if not user:
            return None

        # Verify password
        if not bcrypt.checkpw(password.encode(), user['hash_password'].encode()):
            return None

        # Return user data (without password)
        return {
            'id': user['id'],
            'uuid': str(user['uuid']),
            'email': user['email'],
            'is_verified': user['is_verified'],
            'created_at': user['created_at']
        }

# Complete login handler
async def login_handler(email: str, password: str):
    """
    Login handler with JWT generation.

    Returns access token and refresh token.
    """
    user = await user_repo.login_user(email, password)

    if not user:
        return {
            'success': False,
            'error': 'INVALID_CREDENTIALS',
            'message': 'Invalid email or password'
        }

    if not user['is_verified']:
        return {
            'success': False,
            'error': 'EMAIL_NOT_VERIFIED',
            'message': 'Please verify your email first'
        }

    # Generate JWT tokens
    access_token = create_access_token(user['uuid'])
    refresh_token = create_refresh_token(user['uuid'])

    return {
        'success': True,
        'user': user,
        'access_token': access_token,
        'refresh_token': refresh_token
    }
```

---

## Complete Repository Example

Full repository class with connection pooling:

```python
import asyncpg
from typing import Optional, List
import bcrypt
from datetime import datetime

class UserRepository:
    """Repository for user database operations using asyncpg==0.30.0."""

    def __init__(self, pool: asyncpg.Pool):
        self.pool = pool

    async def create_user(self, email: str, password_hash: str) -> Optional[dict]:
        """Create new user."""
        async with self.pool.acquire() as conn:
            try:
                row = await conn.fetchrow(
                    "SELECT * FROM CREATE_USER($1, $2)",
                    email, password_hash
                )
                return dict(row) if row else None
            except asyncpg.UniqueViolationError as e:
                if 'EMAIL_EXISTS' in str(e):
                    raise EmailExistsError(f"Email {email} already registered")
                raise

    async def change_password(self, user_uuid: str, new_hash: str) -> bool:
        """Change user password."""
        async with self.pool.acquire() as conn:
            return await conn.fetchval(
                "SELECT CHANGE_PASSWORD($1, $2)",
                user_uuid, new_hash
            )

    async def change_email(self, user_uuid: str, new_email: str) -> bool:
        """Change user email."""
        async with self.pool.acquire() as conn:
            try:
                return await conn.fetchval(
                    "SELECT CHANGE_EMAIL($1, $2)",
                    user_uuid, new_email
                )
            except asyncpg.UniqueViolationError as e:
                if 'EMAIL_EXISTS' in str(e):
                    raise EmailExistsError(f"Email {new_email} already in use")
                raise

    async def verify_user(self, user_uuid: str) -> bool:
        """Mark user as verified."""
        async with self.pool.acquire() as conn:
            return await conn.fetchval(
                "SELECT VERIFY_USER($1)",
                user_uuid
            )

    async def find_user_by_uuid(self, user_uuid: str) -> Optional[dict]:
        """Find user by UUID."""
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM FIND_USER_BY_UUID($1)",
                user_uuid
            )
            return dict(row) if row else None

    async def find_user_by_email(self, email: str) -> Optional[dict]:
        """Find user by email."""
        async with self.pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM FIND_USER_BY_EMAIL($1)",
                email
            )
            return dict(row) if row else None

    async def login_user(self, email: str, password: str) -> Optional[dict]:
        """Authenticate user."""
        user = await self.find_user_by_email(email)

        if not user:
            return None

        if not bcrypt.checkpw(password.encode(), user['hash_password'].encode()):
            return None

        # Remove password from result
        user.pop('hash_password')
        return user


# Connection setup
async def create_pool() -> asyncpg.Pool:
    """Create database connection pool for asyncpg==0.30.0."""
    return await asyncpg.create_pool(
        host='localhost',
        port=5432,
        user='postgres',
        password='postgres',
        database='mydb',
        min_size=10,
        max_size=20,
        command_timeout=60
    )

# Usage
pool = await create_pool()
user_repo = UserRepository(pool)
```

---

## Summary Table

| Function           | Can Fail        | Returns Data | Modifies DB |
| ------------------ | --------------- | ------------ | ----------- |
| CREATE_USER        | ✅ EMAIL_EXISTS | ✅           | ✅          |
| CHANGE_PASSWORD    | ❌              | Boolean      | ✅          |
| CHANGE_EMAIL       | ✅ EMAIL_EXISTS | Boolean      | ✅          |
| VERIFY_USER        | ❌              | Boolean      | ✅          |
| UNVERIFY_USER      | ❌              | Boolean      | ✅          |
| FIND_USER_BY_UUID  | ❌              | ✅           | ❌          |
| FIND_USER_BY_EMAIL | ❌              | ✅           | ❌          |
| LOGIN_USER         | ❌              | ✅           | ❌          |
