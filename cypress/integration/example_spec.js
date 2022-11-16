describe('Simple tests', () => {
  it.only('click command', () => {
    cy.visit('https://dev.cera.circleci-labs.com/login');
    cy.get('form').submit()
  });
});
