describe('Simple tests', () => {
  it.only('click command', () => {
    cy.visit('https://dev.cera.circleci-labs.com/login');
    cy.get('button[class*="btn-sign-in"]').should(verifyText =>
    {
     expect(verifyText).have.text('Sign In')
    }.click()
  });
});
