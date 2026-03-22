/**
 * DD_TerritoryService
 * @description Maps ZIP codes to rate territories using Custom Metadata.
 */
public with sharing class DD_TerritoryService {

    private static Map<String, String> territoryCache = new Map<String, String>();

    @AuraEnabled(cacheable=true)
    public static String getTerritoryForZIP(String zipCode) {
        if (String.isBlank(zipCode)) return 'DEFAULT';
        if (territoryCache.containsKey(zipCode)) return territoryCache.get(zipCode);

        List<DD_ZIP_Territory__mdt> records = [
            SELECT Rate_Territory__c
            FROM DD_ZIP_Territory__mdt
            WHERE ZIP_Code__c = :zipCode
            LIMIT 1
        ];

        String territory = records.isEmpty() ? 'DEFAULT' : records[0].Rate_Territory__c;
        territoryCache.put(zipCode, territory);
        return territory;
    }
}
