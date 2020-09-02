describe("Website Activity", () => {
  it("Validates data on the Dashboard", () => {
    cy.formatUrl(Cypress.env("cmc_uri") + "/website_activity", {}).then(
      (url) => {
        cy.visitWithLogin(url);
      }
    );

    // Check the uncompressed raw data size is displayed in a panel
    cy.get("#purchases_today .single-result").should("have.text", "269");

    cy.get(`#purchases_by_host table tbody`).should("be.visible");
    cy.get(`#purchases_by_host table tbody tr:nth-child(1)>td`).should((el) => {
      expect(el.eq(0)).to.contain("sh-i-abc.example.splunkcloud.com");
      const runTime = Number.parseFloat(el.eq(1).text());
      expect(Number.isNaN(runTime)).to.be.false;
      expect(el.eq(1)).to.contain("269");
    });
  });
});
