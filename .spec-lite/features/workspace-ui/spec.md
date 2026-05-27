# Spec: Workspace UI

## Business Goal

Allow new users to register and immediately access their workspace without extra steps.

## User Need

A new user needs a single form to create their account and land in their workspace.

## Requirements

### REQ-001: Registration form submission

WHEN a user submits the registration form with a valid name and email
THE SYSTEM SHALL create the user and workspace atomically and redirect to the workspace home page

**Acceptance Criteria**:

1. GIVEN a valid name and email WHEN the form is submitted THEN the user and workspace are created and the browser navigates to `/workspace`

---

### REQ-002: Registration form validation

IF the registration form is submitted with a missing name, missing email, or malformed email address
THEN THE SYSTEM SHALL display inline validation errors on the relevant fields and not submit the request

**Acceptance Criteria**:

1. GIVEN an empty name field WHEN the form is submitted THEN "Name is required" appears near the name field
2. GIVEN a missing email WHEN the form is submitted THEN "Email is required" appears near the email field
3. GIVEN a malformed email WHEN the form is submitted THEN "Enter a valid email address" appears near the email field

---

### REQ-003: Duplicate email error

IF the registration API returns 409 (email already registered)
THEN THE SYSTEM SHALL display "An account with this email already exists" on the form without clearing it

**Acceptance Criteria**:

1. GIVEN a duplicate email WHEN the form is submitted THEN the form shows "An account with this email already exists" and the user stays on `/register`
2. GIVEN the existing `POST /api/v1/auth/register` endpoint WHEN a duplicate email is inserted THEN the API returns 409 (not 500)

---

### REQ-004: Unauthenticated access guard on workspace home

IF an unauthenticated user navigates to the workspace home page
THEN THE SYSTEM SHALL redirect them to `/register`

**Acceptance Criteria**:

1. GIVEN no active session WHEN a user navigates to `/workspace` THEN the browser redirects to `/register`

---

### REQ-005: Workspace home page

WHILE the user has an active session
WHEN they navigate to the workspace home page
THE SYSTEM SHALL display the workspace name

**Acceptance Criteria**:

1. GIVEN an authenticated session WHEN the workspace home page loads THEN the workspace name is visible in the page heading
2. GIVEN a workspace named "Alice's Workspace" WHEN the page loads THEN "Alice's Workspace" appears as the heading

---

## Assumptions

| #   | Assumption                                                                                     | Risk   | Status   |
| --- | ---------------------------------------------------------------------------------------------- | ------ | -------- |
| A1  | The registration API will return 409 (not 500) for duplicate emails — scoped into this feature | high   | resolved |
| A2  | Workspace home shows workspace name only at this stage — lists are a future feature            | medium | open     |
| A3  | Auth session is established by a future `auth` feature — this feature wires the UI only        | medium | open     |
| A4  | Client-side redirect (Next.js router) after successful registration                            | low    | open     |
