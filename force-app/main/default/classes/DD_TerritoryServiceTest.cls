/**
 * DD_TerritoryServiceTest
 * @description Tests for DD_TerritoryService — ZIP to territory mapping.
 */
@isTest
private class DD_TerritoryServiceTest {

    @isTest
    static void testKnownZIP_ReturnsTerritory() {
        // Custom Metadata records are available in tests automatically
        Test.startTest();
        String territory = DD_TerritoryService.getTerritoryForZIP('94105');
        Test.stopTest();
        System.assertNotEquals(null, territory, 'Territory should not be null');
        System.assert(territory.length() > 0, 'Territory should not be empty');
    }

    @isTest
    static void testUnknownZIP_ReturnsDefault() {
        Test.startTest();
        String territory = DD_TerritoryService.getTerritoryForZIP('00000');
        Test.stopTest();
        System.assertEquals('DEFAULT', territory, 'Unknown ZIP should return DEFAULT territory');
    }

    @isTest
    static void testBlankZIP_ReturnsDefault() {
        Test.startTest();
        String territory = DD_TerritoryService.getTerritoryForZIP('');
        Test.stopTest();
        System.assertEquals('DEFAULT', territory, 'Blank ZIP should return DEFAULT');
    }

    @isTest
    static void testNullZIP_ReturnsDefault() {
        Test.startTest();
        String territory = DD_TerritoryService.getTerritoryForZIP(null);
        Test.stopTest();
        System.assertEquals('DEFAULT', territory, 'Null ZIP should return DEFAULT');
    }

    @isTest
    static void testCaching_ReturnsSameResult() {
        Test.startTest();
        String first  = DD_TerritoryService.getTerritoryForZIP('94105');
        String second = DD_TerritoryService.getTerritoryForZIP('94105');
        Test.stopTest();
        System.assertEquals(first, second, 'Cached result should match first call');
    }

    @isTest
    static void testBulkZIPLookups_200Records() {
        Test.startTest();
        for (Integer i = 0; i < 200; i++) {
            DD_TerritoryService.getTerritoryForZIP('94105');
        }
        Test.stopTest();
        // If governor limits were hit, the test would fail automatically
        System.assert(true, 'Bulk lookups completed without governor limit errors');
    }
}
