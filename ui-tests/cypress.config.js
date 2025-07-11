module.exports = {
  CI: true,
  retries: 1,
  video: true,
  fixturesFolder: false,
  defaultCommandTimeout: 10000, // Increase default timeout to 10 seconds
  pageLoadTimeout: 30000, // Increase page load timeout to 30 seconds
  requestTimeout: 10000, // Increase request timeout to 10 seconds
  env: {
    messages: {
      transaction: {
        empty: 'No Transactions Found',
        error: 'Error: Could Not Load Transactions',
      },
      deposit: {
        success: 'Deposit successful',
        error: 'Deposit failed',
        errRoutingNum: 'invalid routing number',
      },
      transfer: {
        success: 'Payment successful',
        error: 'Payment failed',
        errSelf: 'may not add yourself to contacts',
      },
      invalidFeedback: {
        accountNum: 'Please enter a valid 10 digit account number',
        routingNum: 'Please enter a valid 9 digit routing number',
        payment: 'Please enter a valid amount',
        username:
          'Please enter a valid username. Username must be 2 to 15 characters in length and contain only alphanumeric or underscore characters.',
      },
    },
    defaultUser: {
      username: 'testuser',
      password: 'circleci',
      name: 'Test',
      accountNum: '1011226111',
      externalAccounts: [
        {
          accountNum: '9099791699',
          routingNum: '808889588',
        },
      ],
      recipients: [
        {
          accountNum: '1033623433',
          name: 'Alice',
        },
        {
          accountNum: '1055757655',
          name: 'Bob',
        },
        {
          accountNum: '1077441377',
          name: 'Eve',
        },
      ],
      localRoutingNum: '883745000',
    },
  },
  e2e: {
    setupNodeEvents(on, config) {},
    // Allow environment variable override for baseUrl
    baseUrl: process.env.CYPRESS_BASE_URL || "https://dev.emea.circleci-fieldeng.com",
  },
}
