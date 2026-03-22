/**
 * DD_ProposalService
 * @description Handles proposal creation and PDF storage in Salesforce Files.
 */
public with sharing class DD_ProposalService {

    /**
     * @description Generates a PDF from the VF page, creates a Proposal record,
     *              stores the PDF as a ContentVersion, and links it to both the
     *              Proposal and the Quote.
     */
    public static Id createProposalFromQuote(Id quoteId) {
        DD_Quote__c quote = [
            SELECT Employer__c, Name
            FROM DD_Quote__c
            WHERE Id = :quoteId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        // Generate PDF bytes via Visualforce page
        PageReference pdfPage = Page.DD_ProposalPDF;
        pdfPage.getParameters().put('quoteId', quoteId);
        Blob pdfBlob;
        if (Test.isRunningTest()) {
            pdfBlob = Blob.valueOf('TestPDF');
        } else {
            pdfBlob = pdfPage.getContent();
        }

        String filename = 'Proposal_' + quote.Name + '_' + Date.today().format().replace('/', '-');

        // Create ContentVersion (the PDF file)
        ContentVersion cv = new ContentVersion(
            Title       = filename,
            PathOnClient = filename + '.pdf',
            VersionData  = pdfBlob,
            IsMajorVersion = true
        );
        insert cv;

        // Get ContentDocumentId
        Id contentDocId = [
            SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1
        ].ContentDocumentId;

        // Create Proposal record
        DD_Proposal__c proposal = new DD_Proposal__c(
            Quote__c              = quoteId,
            Employer__c           = quote.Employer__c,
            Status__c             = 'Draft',
            PDF_Content_Version__c = cv.Id
        );
        insert proposal;

        // Link PDF to Quote (so it shows in Quote Files related list)
        ContentDocumentLink quoteLink = new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId    = quoteId,
            ShareType         = 'V'
        );
        insert quoteLink;

        // Link PDF to Proposal record as well
        ContentDocumentLink proposalLink = new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId    = proposal.Id,
            ShareType         = 'V'
        );
        insert proposalLink;

        // Mark quote as PDF generated and move to Presented status
        update new DD_Quote__c(
            Id = quoteId,
            PDF_Generated__c = true,
            Status__c = 'Presented'
        );

        return proposal.Id;
    }

    public static String getPDFDownloadUrl(Id proposalId) {
        DD_Proposal__c proposal = [
            SELECT PDF_Content_Version__c
            FROM DD_Proposal__c
            WHERE Id = :proposalId
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];
        if (proposal.PDF_Content_Version__c == null) return null;
        return '/sfc/servlet.shepherd/version/download/' + proposal.PDF_Content_Version__c;
    }
}
