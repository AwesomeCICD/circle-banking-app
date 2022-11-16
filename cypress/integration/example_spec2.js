describe('Simple tests', () => {
    before(() => {
        // cy.visit('/')
    }}

  it.only('click command', () => {
    cy.visit('https://dev.cera.circleci-labs.com/login');
    cy.get('input[id=create-account-btn]').click() // Click on 'Create an Account' button
  });
});
