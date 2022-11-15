describe('Simple tests', () => {
  it('Visit Test website', () => {
    cy.visit('https://dev.cera.circleci-labs.com/');
    cy.contains('Sign In').click() // Click on first el containing 'Sign In'
  });
});
