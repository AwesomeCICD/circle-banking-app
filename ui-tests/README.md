# UI Tests

This directory contains Cypress end-to-end tests for the banking application.

## Environment Configuration

The tests are configured to run against different environments:

- **Default**: `https://dev.emea.circleci-fieldeng.com`
- **Custom**: Set `CYPRESS_BASE_URL` environment variable

### Running Against Local Environment

```bash
export CYPRESS_BASE_URL=http://localhost:8080
npm run cypress:run
```

## Test Configuration

The tests include:

- **Account Creation Tests** (`create.cy.js`)
- **Deposit Tests** (`deposit.cy.js`) 
- **Login Tests** (`login.cy.js`)
- **Transfer Tests** (`transfer.cy.js`)
- **Home Page Tests** (`home_page.cy.js`)

## Troubleshooting

### Common Issues

1. **"Element not found" errors**: 
   - Tests now include proper wait conditions and visibility checks
   - Increased timeout settings for better reliability

2. **Authentication failures**:
   - Check that the target environment is accessible
   - Verify default user credentials are valid for the target environment

3. **Account creation redirects to login**:
   - This typically indicates the signup endpoint is not working correctly
   - Check backend services are running and accessible

### Test Improvements Made

- Added proper wait conditions for page elements
- Increased timeout settings for better reliability  
- Added environment variable support for flexible deployment testing
- Improved error handling in custom commands

## Default Test User

The tests use a default test user with the following credentials:
- Username: `testuser`
- Password: `circleci`
- Account Number: `1011226111`

Make sure this user exists in your test environment or update the configuration in `cypress.config.js`.