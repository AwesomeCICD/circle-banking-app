// This ensures cypress is testing canary even as rollout is partially underway.
// See config in frontend.yaml for canary service

beforeEach(() => {
    cy.intercept(`${Cypress.config('baseUrl')}**`, req => {
        req.headers['x-demo-version'] = "canary"
    })
})
