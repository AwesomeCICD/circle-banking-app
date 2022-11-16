describe('Simple tests', () => {
  it('Visit Test website', () => {
    cy.visit('https://dev.cera.circleci-labs.com/');
    cy.get('button').click({ position: 'bottom' }) // Click on 'Sign In' 
button
  });
});
