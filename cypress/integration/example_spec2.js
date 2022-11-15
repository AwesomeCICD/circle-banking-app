describe('Simple tests', () => {
  it('Visit Test website', () => {
    cy.visit('https://dev.cera.circleci-labs.com/');
    cy.contains('button', 'Sign').click() // Click on 'Sign In' button
  });
});
