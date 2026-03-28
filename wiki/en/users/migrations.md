# Migration History - Users Module

History of all migrations affecting the Users module.

## Migration 001: add_auth

**Created:** 2026-01-28  
**Status:** Applied  
**File:** [migrations/up/001_add_auth.sql](../../../migrations/up/001_add_auth.sql)

### Changes

#### Extension

- ✅ Added `uuid-ossp` extension

#### Table: USERS

- ✅ Created USERS table
- Columns: ID, UUID, EMAIL, HASH_PASSWORD, CREATED_AT, UPDATED_AT, IS_VERIFIED

#### Indexes

- ✅ `IDX_USERS_UUID` - Fast lookup by UUID
- ✅ `IDX_USERS_EMAIL` - Fast lookup by email

#### Triggers

- ✅ `UPDATE_USERS_UPDATED_AT` - Auto-update updated_at column
- ✅ `UPDATE_UPDATED_AT_COLUMN()` - Trigger function

#### Functions

1. ✅ `CREATE_USER` - Register new user
2. ✅ `CHANGE_PASSWORD` - Update password
3. ✅ `CHANGE_EMAIL` - Update email with verification reset
4. ✅ `VERIFY_USER` - Mark user as verified
5. ✅ `UNVERIFY_USER` - Mark user as unverified
6. ✅ `FIND_USER_BY_UUID` - Get user by UUID
7. ✅ `FIND_USER_BY_EMAIL` - Get user by email
8. ✅ `LOGIN_USER` - Authenticate user

#### Error Codes

- ✅ `EMAIL_EXISTS` - Added to CREATE_USER
- ✅ `EMAIL_EXISTS` - Added to CHANGE_EMAIL

### Seed Data

**File:** [migrations/seed/001_example_users.sql](../../../migrations/seed/001_example_users.sql)

3 test users created:

- admin@example.com
- user@example.com
- test@example.com

---

## Future Migrations

Future changes to the Users module will be documented here.

Planned features:

- Password reset tokens
- Two-factor authentication
- User roles and permissions
- Login attempt tracking
- Account suspension
