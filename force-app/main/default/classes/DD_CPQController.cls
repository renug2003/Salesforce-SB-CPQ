/**
 * DD_CPQController
 * @description Primary Apex controller for the Delta Dental CPQ LWC components.
 *              Provides @AuraEnabled methods for all wizard steps.
 * @author Delta Dental of California – Enterprise Architecture
 */
public with sharing class DD_CPQController {

    // ─── Guided Selling / Plan Selection ───────────────────────────────────────

    /**
     * @description Returns active plans filtered by segment, product line, and effective date.
     *              Used in the plan selector step of the guided selling wizard.
     */
    @AuraEnabled(cacheable=true)
    public static List<PlanWrapper> getAvailablePlans(
        String productLine,
        String groupSize,
        Date effectiveDate
    ) {
        try {
            Integer grpSize = Integer.valueOf(groupSize);
            List<DD_Plan__c> plans = [
                SELECT Id, Name, Plan_Code__c, Plan_Type__c, Product_Line__c,
                       Network__c, Deductible_Individual__c, Deductible_Family__c,
                       Annual_Maximum__c, Ortho_Lifetime_Max__c, Ortho_Covered__c,
                       Waiting_Period__c, Coinsurance_Preventive__c, Coinsurance_Basic__c,
                       Coinsurance_Major__c, Coinsurance_Ortho__c,
                       Highlights__c, Sort_Order__c, Segment_Eligibility__c
                FROM DD_Plan__c
                WHERE Is_Active__c = true
                  AND (Effective_End__c = null OR Effective_End__c >= :effectiveDate)
                  AND (Effective_Start__c = null OR Effective_Start__c <= :effectiveDate)
                WITH SECURITY_ENFORCED
                ORDER BY Sort_Order__c ASC NULLS LAST, Name ASC
            ];

            List<PlanWrapper> result = new List<PlanWrapper>();
            for (DD_Plan__c p : plans) {
                // Filter by product line and segment eligibility in Apex
                Boolean lineMatch = (productLine == 'All' || p.Product_Line__c == productLine);
                Boolean segmentMatch = (p.Segment_Eligibility__c != null
                    && p.Segment_Eligibility__c.contains('Small Business'));
                if (lineMatch && segmentMatch) {
                    result.add(new PlanWrapper(p));
                }
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving plans: ' + e.getMessage());
        }
    }

    /**
     * @description Returns rate for a given plan, ZIP code, group size, and effective date.
     */
    @AuraEnabled(cacheable=true)
    public static RateWrapper getRatesForPlan(
        Id planId,
        String zipCode,
        Integer groupSize,
        Date effectiveDate
    ) {
        try {
            String territory = DD_TerritoryService.getTerritoryForZIP(zipCode);
            return DD_RateService.getRateWrapper(planId, territory, groupSize, effectiveDate);
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving rates: ' + e.getMessage());
        }
    }

    /**
     * @description Returns plan benefits grid for a specific plan.
     */
    @AuraEnabled(cacheable=true)
    public static List<DD_PlanBenefit__c> getPlanBenefits(Id planId) {
        try {
            return [
                SELECT Id, Name, Benefit_Category__c,
                       In_Network_Coinsurance__c, Out_Network_Coinsurance__c,
                       Frequency__c, Notes__c, Sort_Order__c
                FROM DD_PlanBenefit__c
                WHERE Plan__c = :planId
                WITH SECURITY_ENFORCED
                ORDER BY Benefit_Category__c, Sort_Order__c ASC NULLS LAST
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving benefits: ' + e.getMessage());
        }
    }

    // ─── Employer ──────────────────────────────────────────────────────────────

    /**
     * @description Creates or updates an employer record.
     */
    @AuraEnabled
    public static Id saveEmployer(String employerJSON) {
        try {
            DD_Employer__c emp = (DD_Employer__c) JSON.deserialize(
                employerJSON, DD_Employer__c.class
            );

            // Validate group size for Small Business segment
            if (emp.Total_Employees__c != null) {
                if (emp.Total_Employees__c < 2 || emp.Total_Employees__c > 99) {
                    throw new DD_CPQException(
                        'Small Business segment requires 2–99 employees. ' +
                        'Current count: ' + (Integer)emp.Total_Employees__c
                    );
                }
            }

            if (emp.Segment__c == null) {
                emp.Segment__c = 'Small Business';
            }

            upsert emp;
            return emp.Id;
        } catch (DD_CPQException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Error saving employer: ' + e.getMessage());
        }
    }

    /**
     * @description Returns territory for a given ZIP code.
     */
    @AuraEnabled(cacheable=true)
    public static String getTerritoryForZIP(String zipCode) {
        try {
            return DD_TerritoryService.getTerritoryForZIP(zipCode);
        } catch (Exception e) {
            throw new AuraHandledException('Error looking up territory: ' + e.getMessage());
        }
    }

    // ─── Quote ─────────────────────────────────────────────────────────────────

    /**
     * @description Creates a new quote and associated line items.
     */
    @AuraEnabled
    public static Id createQuote(String quoteJSON, String lineItemsJSON) {
        try {
            DD_Quote__c quote = (DD_Quote__c) JSON.deserialize(
                quoteJSON, DD_Quote__c.class
            );

            // Auto-set territory from ZIP
            if (String.isNotBlank(quote.ZIP_Code__c)) {
                quote.Rate_Territory__c = DD_TerritoryService.getTerritoryForZIP(quote.ZIP_Code__c);
            }

            // Auto-set expiration date to 30 days
            quote.Quote_Expiration_Date__c = Date.today().addDays(30);
            quote.Status__c = 'Draft';

            insert quote;

            // Insert line items
            if (String.isNotBlank(lineItemsJSON)) {
                List<DD_QuoteLineItem__c> lineItems =
                    (List<DD_QuoteLineItem__c>) JSON.deserialize(
                        lineItemsJSON, List<DD_QuoteLineItem__c>.class
                    );
                for (DD_QuoteLineItem__c li : lineItems) {
                    li.Quote__c = quote.Id;
                }
                insert lineItems;
            }

            // Recalculate totals
            DD_QuoteService.recalculateTotals(quote.Id);

            return quote.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating quote: ' + e.getMessage());
        }
    }

    /**
     * @description Returns a quote with all line items and plan details.
     */
    @AuraEnabled(cacheable=true)
    public static QuoteDetailWrapper getQuoteDetail(Id quoteId) {
        try {
            return DD_QuoteService.getQuoteDetail(quoteId);
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving quote: ' + e.getMessage());
        }
    }

    /**
     * @description Updates quote status.
     */
    @AuraEnabled
    public static void updateQuoteStatus(Id quoteId, String newStatus) {
        try {
            DD_Quote__c quote = new DD_Quote__c(
                Id = quoteId,
                Status__c = newStatus
            );
            update quote;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating quote status: ' + e.getMessage());
        }
    }

    // ─── Proposal ──────────────────────────────────────────────────────────────

    /**
     * @description Generates a proposal PDF server-side (via Visualforce renderAs=pdf),
     *              creates a Proposal record, and attaches the PDF to both the Proposal
     *              and the Quote record as a Salesforce File (ContentVersion).
     */
    @AuraEnabled
    public static Id generateProposalPDF(Id quoteId) {
        try {
            return DD_ProposalService.createProposalFromQuote(quoteId);
        } catch (Exception e) {
            throw new AuraHandledException('Error generating proposal: ' + e.getMessage());
        }
    }

    /**
     * @description Returns the ContentVersion download URL for a proposal PDF.
     */
    @AuraEnabled(cacheable=true)
    public static String getProposalPDFUrl(Id proposalId) {
        try {
            return DD_ProposalService.getPDFDownloadUrl(proposalId);
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving proposal PDF: ' + e.getMessage());
        }
    }

    // ─── Group ─────────────────────────────────────────────────────────────────

    /**
     * @description Returns Group records linked to the given Quote.
     */
    @AuraEnabled(cacheable=true)
    public static List<DD_Group__c> getGroupsForQuote(Id quoteId) {
        try {
            return [
                SELECT Id, Name, Employer__c, Employer__r.Name,
                       Status__c, Effective_Date__c, Renewal_Date__c, Total_Enrolled__c
                FROM DD_Group__c
                WHERE Source_Quote__c = :quoteId
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching groups: ' + e.getMessage());
        }
    }

    /**
     * @description Converts an accepted quote to a Group record.
     */
    @AuraEnabled
    public static Id createGroupFromQuote(Id quoteId) {
        try {
            return DD_QuoteService.convertQuoteToGroup(quoteId);
        } catch (Exception e) {
            throw new AuraHandledException('Error creating group: ' + e.getMessage());
        }
    }

    // ─── Contract ──────────────────────────────────────────────────────────────

    /**
     * @description Creates a contract from a group record and generates a contract PDF,
     *              attaching it as a Salesforce File to the new contract.
     */
    @AuraEnabled
    public static Id createContractFromGroup(Id groupId) {
        try {
            // Step 1: Generate PDF from the Group BEFORE creating the contract.
            // PageReference.getContent() renders the VF page via a separate HTTP request,
            // so it can only see records already committed to the database. By passing
            // groupId (an existing committed record), we avoid the "List has no rows"
            // error that would occur if we passed a newly-inserted contractId.
            PageReference pdfPage = Page.DD_ContractPDF;
            pdfPage.getParameters().put('groupId', groupId);
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('TestContractPDF');
            } else {
                pdfBlob = pdfPage.getContent();
            }

            // Step 2: Create the contract record
            Id contractId = DD_ContractService.createFromGroup(groupId);

            // Step 3: Query group name for the PDF filename
            DD_Group__c grp = [SELECT Name FROM DD_Group__c WHERE Id = :groupId LIMIT 1];
            String filename = 'Contract_' + grp.Name + '_' + Date.today().format().replace('/', '-');

            // Step 4: Create ContentVersion (the PDF file)
            ContentVersion cv = new ContentVersion(
                Title        = filename,
                PathOnClient = filename + '.pdf',
                VersionData  = pdfBlob,
                IsMajorVersion = true
            );
            insert cv;

            // Step 5: Get ContentDocumentId and link PDF to the Contract record
            Id contentDocId = [
                SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1
            ].ContentDocumentId;

            insert new ContentDocumentLink(
                ContentDocumentId = contentDocId,
                LinkedEntityId    = contractId,
                ShareType         = 'V'
            );

            return contractId;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating contract: ' + e.getMessage());
        }
    }

    /**
     * @description Creates a contract from a group record.
     */
    @AuraEnabled
    public static Id createContract(String contractJSON) {
        try {
            DD_Contract__c contract = (DD_Contract__c) JSON.deserialize(
                contractJSON, DD_Contract__c.class
            );
            contract.Status__c = 'Draft';
            insert contract;
            return contract.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error creating contract: ' + e.getMessage());
        }
    }

    /**
     * @description Marks a contract as signed (Phase 1 signature).
     */
    @AuraEnabled
    public static void signContract(Id contractId, Date signedDate, String signerName, String signerTitle) {
        try {
            DD_Contract__c contract = new DD_Contract__c(
                Id = contractId,
                Is_Signed__c = true,
                Signed_Date__c = signedDate,
                Signed_By_Name__c = signerName,
                Signed_By_Title__c = signerTitle
            );
            update contract;
            // Flow will auto-set status to Approved
        } catch (Exception e) {
            throw new AuraHandledException('Error signing contract: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<BrokerWrapper> searchBrokerAccounts(String searchTerm) {
        List<BrokerWrapper> results = new List<BrokerWrapper>();
        if (String.isBlank(searchTerm) || searchTerm.trim().length() < 2) return results;
        String query = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
        for (Account a : [
            SELECT Id, Name, Type, Phone
            FROM Account
            WHERE Name LIKE :query AND Type = 'Producer'
            WITH SECURITY_ENFORCED
            ORDER BY Name
            LIMIT 10
        ]) {
            BrokerWrapper w = new BrokerWrapper();
            w.id    = a.Id;
            w.name  = a.Name;
            w.type  = a.Type;
            w.phone = a.Phone;
            results.add(w);
        }
        return results;
    }

    // ─── Inner Wrapper Classes ──────────────────────────────────────────────────

    public class BrokerWrapper {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String type { get; set; }
        @AuraEnabled public String phone { get; set; }
    }



    public class PlanWrapper {
        @AuraEnabled public Id planId { get; set; }
        @AuraEnabled public String planName { get; set; }
        @AuraEnabled public String planCode { get; set; }
        @AuraEnabled public String planType { get; set; }
        @AuraEnabled public String productLine { get; set; }
        @AuraEnabled public String network { get; set; }
        @AuraEnabled public Decimal deductibleIndividual { get; set; }
        @AuraEnabled public Decimal deductibleFamily { get; set; }
        @AuraEnabled public Decimal annualMaximum { get; set; }
        @AuraEnabled public Decimal orthoLifetimeMax { get; set; }
        @AuraEnabled public Boolean orthoLCovered { get; set; }
        @AuraEnabled public String waitingPeriod { get; set; }
        @AuraEnabled public Decimal coinsurancePreventive { get; set; }
        @AuraEnabled public Decimal coinsuranceBasic { get; set; }
        @AuraEnabled public Decimal coinsuranceMajor { get; set; }
        @AuraEnabled public String highlights { get; set; }
        @AuraEnabled public Integer sortOrder { get; set; }

        public PlanWrapper(DD_Plan__c p) {
            this.planId = p.Id;
            this.planName = p.Name;
            this.planCode = p.Plan_Code__c;
            this.planType = p.Plan_Type__c;
            this.productLine = p.Product_Line__c;
            this.network = p.Network__c;
            this.deductibleIndividual = p.Deductible_Individual__c;
            this.deductibleFamily = p.Deductible_Family__c;
            this.annualMaximum = p.Annual_Maximum__c;
            this.orthoLifetimeMax = p.Ortho_Lifetime_Max__c;
            this.orthoLCovered = p.Ortho_Covered__c;
            this.waitingPeriod = p.Waiting_Period__c;
            this.coinsurancePreventive = p.Coinsurance_Preventive__c;
            this.coinsuranceBasic = p.Coinsurance_Basic__c;
            this.coinsuranceMajor = p.Coinsurance_Major__c;
            this.highlights = p.Highlights__c;
            this.sortOrder = p.Sort_Order__c != null ? (Integer)p.Sort_Order__c : 999;
        }
    }

    public class RateWrapper {
        @AuraEnabled public Decimal rateEO { get; set; }
        @AuraEnabled public Decimal rateES { get; set; }
        @AuraEnabled public Decimal rateEC { get; set; }
        @AuraEnabled public Decimal rateEF { get; set; }
        @AuraEnabled public String territory { get; set; }
        @AuraEnabled public Boolean rateFound { get; set; }
    }

    public class QuoteDetailWrapper {
        @AuraEnabled public DD_Quote__c quote { get; set; }
        @AuraEnabled public DD_Employer__c employer { get; set; }
        @AuraEnabled public List<DD_QuoteLineItem__c> lineItems { get; set; }
        @AuraEnabled public Decimal totalMonthlyPremium { get; set; }
        @AuraEnabled public Decimal totalAnnualPremium { get; set; }
        @AuraEnabled public Decimal employerMonthlyTotal { get; set; }
        @AuraEnabled public Decimal employeeMonthlyTotal { get; set; }
    }
}