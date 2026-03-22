/**
 * DD_ProposalServiceTest
 * @description Tests for DD_ProposalService — proposal creation and PDF storage.
 */
@isTest
private class DD_ProposalServiceTest {

    @TestSetup
    static void setupTestData() {
        DD_Employer__c emp = new DD_Employer__c(
            Name = 'Proposal Test Employer',
            Billing_ZIP__c = '90001',
            Total_Employees__c = 10,
            Segment__c = 'Small Business',
            Status__c = 'Prospect'
        );
        insert emp;

        DD_Quote__c quote = new DD_Quote__c(
            Employer__c = emp.Id,
            Effective_Date__c = Date.today().addMonths(1).toStartOfMonth(),
            Status__c = 'Draft'
        );
        insert quote;
    }

    @isTest
    static void testCreateProposalFromQuote() {
        DD_Quote__c quote = [SELECT Id FROM DD_Quote__c LIMIT 1];
        String fakePdfBase64 = EncodingUtil.base64Encode(Blob.valueOf('fake pdf content'));

        Test.startTest();
        Id proposalId = DD_ProposalService.createProposalFromQuote(
            quote.Id, fakePdfBase64, 'Test_Proposal'
        );
        Test.stopTest();

        System.assertNotEquals(null, proposalId, 'Proposal ID should be returned');

        DD_Proposal__c proposal = [
            SELECT Id, Status__c, Quote__c, PDF_Content_Version__c
            FROM DD_Proposal__c WHERE Id = :proposalId
        ];
        System.assertEquals('Draft', proposal.Status__c);
        System.assertEquals(quote.Id, proposal.Quote__c);
        System.assertNotEquals(null, proposal.PDF_Content_Version__c, 'PDF should be stored');
    }

    @isTest
    static void testCreateProposal_SetsQuoteStatusToPresented() {
        DD_Quote__c quote = [SELECT Id FROM DD_Quote__c LIMIT 1];
        String fakePdfBase64 = EncodingUtil.base64Encode(Blob.valueOf('pdf content'));

        Test.startTest();
        DD_ProposalService.createProposalFromQuote(quote.Id, fakePdfBase64, 'Proposal');
        Test.stopTest();

        DD_Quote__c updated = [SELECT Status__c, PDF_Generated__c FROM DD_Quote__c WHERE Id = :quote.Id];
        System.assertEquals('Presented', updated.Status__c, 'Quote should be Presented');
        System.assertEquals(true, updated.PDF_Generated__c, 'PDF Generated flag should be set');
    }

    @isTest
    static void testCreateProposal_FileLinkedToProposal() {
        DD_Quote__c quote = [SELECT Id FROM DD_Quote__c LIMIT 1];
        String fakePdfBase64 = EncodingUtil.base64Encode(Blob.valueOf('pdf content'));

        Test.startTest();
        Id proposalId = DD_ProposalService.createProposalFromQuote(
            quote.Id, fakePdfBase64, 'Linked_Proposal'
        );
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId FROM ContentDocumentLink
            WHERE LinkedEntityId = :proposalId
        ];
        System.assertEquals(1, links.size(), 'PDF file should be linked to proposal');
    }

    @isTest
    static void testGetPDFDownloadUrl() {
        DD_Quote__c quote = [SELECT Id FROM DD_Quote__c LIMIT 1];
        String fakePdfBase64 = EncodingUtil.base64Encode(Blob.valueOf('pdf'));

        Id proposalId = DD_ProposalService.createProposalFromQuote(
            quote.Id, fakePdfBase64, 'URL_Test'
        );

        Test.startTest();
        String url = DD_ProposalService.getPDFDownloadUrl(proposalId);
        Test.stopTest();

        System.assertNotEquals(null, url, 'URL should not be null');
        System.assert(url.contains('/sfc/servlet.shepherd/version/download/'), 'URL format should be correct');
    }

    @isTest
    static void testGetPDFDownloadUrl_NoPDF() {
        DD_Employer__c emp = [SELECT Id FROM DD_Employer__c LIMIT 1];
        DD_Quote__c quote = [SELECT Id FROM DD_Quote__c LIMIT 1];

        DD_Proposal__c proposal = new DD_Proposal__c(
            Quote__c = quote.Id,
            Employer__c = emp.Id,
            Status__c = 'Draft'
        );
        insert proposal;

        Test.startTest();
        String url = DD_ProposalService.getPDFDownloadUrl(proposal.Id);
        Test.stopTest();

        System.assertEquals(null, url, 'URL should be null when no PDF is stored');
    }
}
