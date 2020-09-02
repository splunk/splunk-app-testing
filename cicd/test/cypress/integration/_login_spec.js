describe('Login and Cookie Preservation', () => {

  it('checks that we can successfully login to Splunk', () => {
    Cypress.Cookies.defaults({
      preserve: ['session_id',
        'splunkweb_csrf_token_9000',
        'splunkd_8000',
        'splunkweb_csrf_token_8000',
        'session_id_8000']
    })
    cy.splunkLogin()
    cy.visit('/en-US/app/testing_app')
    cy.get(`.dashboard-header-title`).should('have.text', 'Website Activity')
  })
})
