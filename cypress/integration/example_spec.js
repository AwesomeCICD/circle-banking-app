describe('Simple tests', () => {
  it.only('click command', () => {
    cy.visit('https://dev.cera.circleci-labs.com/login');
    cy.get('div.input-group mt-2 mb-5>button').click()
  });
});
