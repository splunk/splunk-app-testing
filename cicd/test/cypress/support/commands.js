// ***********************************************
// This example commands.js shows you how to
// create various custom commands and overwrite
// existing commands.
//
// For more comprehensive examples of custom
// commands please read more here:
// https://on.cypress.io/custom-commands
// ***********************************************
//
//
// -- This is a parent command --
// Cypress.Commands.add("login", (email, password) => { ... })
//
//
// -- This is a child command --
// Cypress.Commands.add("drag", { prevSubject: 'element'}, (subject, options) => { ... })
//
//
// -- This is a dual command --
// Cypress.Commands.add("dismiss", { prevSubject: 'optional'}, (subject, options) => { ... })
//
//
// -- This will overwrite an existing command --
// Cypress.Commands.overwrite("visit", (originalFn, url, options) => { ... })

Cypress.Commands.add('splunkLogin', () => {
  const logoutPath = '/en-US/account/logout';

    cy.clearCookies()

    cy.visit(logoutPath);

    cy.get('#username')
        .type(Cypress.env('splunk_user'));

    cy.get('#password')
        .type(Cypress.env('splunk_password'));

    cy.get('input').contains('Sign')
        .click();

})

Cypress.Commands.add('visitWithLogin', (destination) => {
  const timeout = Cypress.env('cookie_timeout');
  cy.log('timeout: ' + timeout)

    Cypress.Cookies.defaults({
      preserve: ['session_id',
        'splunkweb_csrf_token_9000',
        'splunkd_8000',
        'splunkweb_csrf_token_8000',
        'session_id_8000',
        'cypress-login'
      ]
    })

    cy.getCookie('cypress-login')
      .then((val) => {
        if (val == null || val.value != 'true' || val.expiry < Date.now()) {
          if (val == null) {
            cy.log('Cookie is null')
          } else {
            cy.log('value: ' + val.value)
            cy.log('expiry: ' + val.expiry)
            cy.log('now: ' + Date.now())
          }
          cy.splunkLogin()
          cy.setCookie('cypress-login', 'true', {expiry: Date.now()+timeout})
        }
      })
  cy.visit(destination);

})

Cypress.Commands.add("formatUrl", (url, params) =>
  `${url}?${Object.entries(params)
    .reduce((urlParams, entry) => {
      urlParams.set(...entry)
      return urlParams
    }, new URLSearchParams())
    .toString()}`);


