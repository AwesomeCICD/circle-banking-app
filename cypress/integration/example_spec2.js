describe('Simple tests', () => {
  it.only('click command', () => {
    cy.visit('https://dev.cera.circleci-labs.com/login');
    cy.get('.mb-4').eq(1).click();
  });
});
