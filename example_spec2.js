describe('Simple tests', () => {
  it('Visit Test website', () => {
    cy.visit('https://dev.cera.circleci-labs.com/');
    cy.get('.btn').click() // Click on button
    cy.focused().click() // Click on el with focus
    cy.contains('Welcome').click() // Click on first el containing 'Welcome'
  });
});
