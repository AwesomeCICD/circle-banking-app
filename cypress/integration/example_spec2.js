describe('Simple tests', () => {
  it.only('click command', () => {
    cy.visit('https://dev.cera.circleci-labs.com/login');
    cy.get('.card-body sign-in').contains('Sign In').click()
  });
});
