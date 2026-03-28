# Users Module

Authentication and user management system with email-based identification and UUID for external APIs.

## Contents

1. [Schema](schema.md) - USERS table structure, indexes, triggers
2. [Functions](functions.md) - 8 functions for user operations
3. [Error Codes](errors.md) - Error handling and codes
4. [Migration History](migrations.md) - Changes to this module

## Overview

The Users module provides:

- **Registration** - Create users with email and password
- **Authentication** - Login with email verification
- **Email Management** - Change email with automatic verification reset
- **Password Management** - Secure password changes
- **User Lookup** - Find users by UUID or email
- **Verification** - Email verification status management

## Quick Examples

### Register User

```sql
SELECT * FROM CREATE_USER('user@example.com', '$2a$10$hashed_password');
```

### Login

```sql
SELECT * FROM LOGIN_USER('user@example.com', '$2a$10$hashed_password');
```

### Find User

```sql
SELECT * FROM FIND_USER_BY_UUID('550e8400-e29b-41d4-a716-446655440000');
```

## Key Features

- ✅ UUID-based external identification
- ✅ Email uniqueness enforcement
- ✅ Automatic timestamp tracking
- ✅ Email verification status
- ✅ Indexed for fast lookups
- ✅ Error codes for application layer
