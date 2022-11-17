describe('Simple tests', () => {
  it.only('click command', () => {
    cy.visit('https://dev.cera.circleci-labs.com/login');
    cy.get('.btn.btn-sign-in.btn-block.mb-4').click()
  });
});
