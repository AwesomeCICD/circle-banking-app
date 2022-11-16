describe('Simple tests', () => {
  it('Visit Test website', () => {
    cy.visit('https://dev.cera.circleci-labs.com/login');
    cy.get('.btn-sign-in'). click() // Click on 'Sign In' button
  });
});
