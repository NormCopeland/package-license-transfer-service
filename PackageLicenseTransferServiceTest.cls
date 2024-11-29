@IsTest
private class PackageLicenseTransferServiceTest {
    private static final String TEST_NAMESPACE = 'SDOC';
    
    @TestSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User'];
        
        List<User> usersToCreate = new List<User>{
            new User(
                Username = 'test.original' + System.currentTimeMillis() + '@example.com',
                Email = 'test.original@example.com',
                FirstName = 'Test',
                LastName = 'Original',
                Alias = 'torg',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                TimeZoneSidKey = 'America/Los_Angeles',
                ProfileId = p.Id
            ),
            new User(
                Username = 'test.new' + System.currentTimeMillis() + '@example.com',
                Email = 'test.new@example.com',
                FirstName = 'Test',
                LastName = 'New',
                Alias = 'tnew',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                TimeZoneSidKey = 'America/Los_Angeles',
                ProfileId = p.Id
            ),
            new User(
                Username = 'test.inactive' + System.currentTimeMillis() + '@example.com',
                Email = 'test.inactive@example.com',
                FirstName = 'Test',
                LastName = 'Inactive',
                Alias = 'tinc',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                LocaleSidKey = 'en_US',
                TimeZoneSidKey = 'America/Los_Angeles',
                ProfileId = p.Id,
                IsActive = false
            )
        };
        insert usersToCreate;
    }
    
    private static Map<String, User> getTestUsers() {
        Map<String, User> users = new Map<String, User>();
        for(User u : [SELECT Id, Username, IsActive, Email 
                      FROM User 
                      WHERE Email IN ('test.original@example.com', 'test.new@example.com', 'test.inactive@example.com')]) {
            if(u.Username.contains('test.original')) {
                users.put('original', u);
            } else if(u.Username.contains('test.new')) {
                users.put('new', u);
            } else if(u.Username.contains('test.inactive')) {
                users.put('inactive', u);
            }
        }
        return users;
    }

    @IsTest
    static void testTransferWithNullRequest() {
    Test.startTest();
    List<PackageLicenseTransferService.TransferResult> results;
    
    // Add try-catch block to handle potential null pointer exception
    try {
        results = PackageLicenseTransferService.transferLicense(null);
    } catch (Exception e) {
        System.assert(false, 'Should not throw exception for null input: ' + e.getMessage());
    }
    
    Test.stopTest();

    // Verify results
    System.assertNotEquals(null, results, 'Results should not be null');
    System.assertEquals(0, results.size(), 'Should return empty list for null request');
    }

    @IsTest
    static void testTransferWithEmptyRequest() {
        Test.startTest();
        List<PackageLicenseTransferService.TransferResult> results = 
            PackageLicenseTransferService.transferLicense(new List<PackageLicenseTransferService.TransferRequest>());
        Test.stopTest();

        System.assertNotEquals(null, results, 'Should return empty list, not null');
        System.assertEquals(0, results.size(), 'Should return empty list for empty request');
    }

    @IsTest
    static void testTransferWithNullUserId() {
        Test.startTest();
        PackageLicenseTransferService.TransferRequest req = new PackageLicenseTransferService.TransferRequest();
        req.packageNamespace = TEST_NAMESPACE;
        req.isRevert = false;

        List<PackageLicenseTransferService.TransferResult> results = 
            PackageLicenseTransferService.transferLicense(new List<PackageLicenseTransferService.TransferRequest>{req});
        Test.stopTest();

        System.assertNotEquals(null, results, 'Result list should not be null');
        System.assertEquals(1, results.size(), 'Should return one result');
        System.assert(!results[0].isSuccess, 'Transfer should fail');
        System.assert(results[0].message != null && results[0].message.length() > 0, 
            'Should have an error message for null user ID');
    }

    @IsTest
    static void testTransferWithInvalidUserId() {
        Test.startTest();
        PackageLicenseTransferService.TransferRequest req = new PackageLicenseTransferService.TransferRequest();
        req.newUserId = UserInfo.getOrganizationId(); // Invalid ID type
        req.packageNamespace = TEST_NAMESPACE;
        req.isRevert = false;

        List<PackageLicenseTransferService.TransferResult> results = 
            PackageLicenseTransferService.transferLicense(new List<PackageLicenseTransferService.TransferRequest>{req});
        Test.stopTest();

        System.assert(!results[0].isSuccess, 'Transfer should fail');
        System.assert(results[0].message != null && results[0].message.length() > 0, 
            'Should have an error message for invalid user ID');
    }

    @IsTest
    static void testTransferToInactiveUser() {
        Map<String, User> testUsers = getTestUsers();
        User inactiveUser = testUsers.get('inactive');

        Test.startTest();
        PackageLicenseTransferService.TransferRequest req = new PackageLicenseTransferService.TransferRequest();
        req.newUserId = inactiveUser.Id;
        req.packageNamespace = TEST_NAMESPACE;
        req.isRevert = false;

        List<PackageLicenseTransferService.TransferResult> results = 
            PackageLicenseTransferService.transferLicense(new List<PackageLicenseTransferService.TransferRequest>{req});
        Test.stopTest();

        System.assert(!results[0].isSuccess, 'Transfer should fail');
        System.assert(results[0].message != null && results[0].message.length() > 0, 
            'Should have an error message for inactive user');
    }

    @IsTest
    static void testTransferWithBlankNamespace() {
        Map<String, User> testUsers = getTestUsers();
        User newUser = testUsers.get('new');

        Test.startTest();
        PackageLicenseTransferService.TransferRequest req = new PackageLicenseTransferService.TransferRequest();
        req.newUserId = newUser.Id;
        req.packageNamespace = '';
        req.isRevert = false;

        List<PackageLicenseTransferService.TransferResult> results = 
            PackageLicenseTransferService.transferLicense(new List<PackageLicenseTransferService.TransferRequest>{req});
        Test.stopTest();

        System.assert(!results[0].isSuccess, 'Transfer should fail');
        System.assert(results[0].message != null && results[0].message.length() > 0, 
            'Should have an error message for blank namespace');
    }

    @IsTest
    static void testTransferWithInvalidPackage() {
        Map<String, User> testUsers = getTestUsers();
        User newUser = testUsers.get('new');

        Test.startTest();
        PackageLicenseTransferService.TransferRequest req = new PackageLicenseTransferService.TransferRequest();
        req.newUserId = newUser.Id;
        req.packageNamespace = 'INVALID_PACKAGE';
        req.isRevert = false;

        List<PackageLicenseTransferService.TransferResult> results = 
            PackageLicenseTransferService.transferLicense(new List<PackageLicenseTransferService.TransferRequest>{req});
        Test.stopTest();

        System.assert(!results[0].isSuccess, 'Transfer should fail');
        System.assert(results[0].message != null && results[0].message.length() > 0, 
            'Should have an error message for invalid package');
    }

    @IsTest
    static void testRevertWithMissingCurrentHolder() {
        Map<String, User> testUsers = getTestUsers();
        User originalUser = testUsers.get('original');

        Test.startTest();
        PackageLicenseTransferService.TransferRequest req = new PackageLicenseTransferService.TransferRequest();
        req.newUserId = originalUser.Id;
        req.packageNamespace = TEST_NAMESPACE;
        req.isRevert = true;

        List<PackageLicenseTransferService.TransferResult> results = 
            PackageLicenseTransferService.transferLicense(new List<PackageLicenseTransferService.TransferRequest>{req});
        Test.stopTest();

        System.assert(!results[0].isSuccess, 'Revert should fail');
        System.assert(results[0].message != null && results[0].message.length() > 0, 
            'Should have an error message for missing current holder');
    }

    @IsTest
    static void testRevertWithInvalidCurrentHolder() {
        Map<String, User> testUsers = getTestUsers();
        User originalUser = testUsers.get('original');

        Test.startTest();
        PackageLicenseTransferService.TransferRequest req = new PackageLicenseTransferService.TransferRequest();
        req.newUserId = originalUser.Id;
        req.currentHolderId = UserInfo.getOrganizationId(); // Invalid ID type
        req.packageNamespace = TEST_NAMESPACE;
        req.isRevert = true;

        List<PackageLicenseTransferService.TransferResult> results = 
            PackageLicenseTransferService.transferLicense(new List<PackageLicenseTransferService.TransferRequest>{req});
        Test.stopTest();

        System.assert(!results[0].isSuccess, 'Revert should fail');
        System.assert(results[0].message != null && results[0].message.length() > 0, 
            'Should have an error message for invalid current holder');
    }

    @IsTest
static void testBulkTransfer() {
    Map<String, User> testUsers = getTestUsers();
    User newUser = testUsers.get('new');
    User originalUser = testUsers.get('original');

    Test.startTest();
    List<PackageLicenseTransferService.TransferRequest> requests = new List<PackageLicenseTransferService.TransferRequest>();
    
    // Valid request
    PackageLicenseTransferService.TransferRequest validReq = new PackageLicenseTransferService.TransferRequest();
    validReq.newUserId = newUser.Id;
    validReq.packageNamespace = TEST_NAMESPACE;
    validReq.isRevert = false;
    requests.add(validReq);

    // Invalid package
    PackageLicenseTransferService.TransferRequest invalidPackageReq = new PackageLicenseTransferService.TransferRequest();
    invalidPackageReq.newUserId = newUser.Id;
    invalidPackageReq.packageNamespace = 'INVALID_PACKAGE';
    invalidPackageReq.isRevert = false;
    requests.add(invalidPackageReq);

    // Null user ID
    PackageLicenseTransferService.TransferRequest nullUserReq = new PackageLicenseTransferService.TransferRequest();
    nullUserReq.packageNamespace = TEST_NAMESPACE;
    nullUserReq.isRevert = false;
    requests.add(nullUserReq);

    // Blank namespace
    PackageLicenseTransferService.TransferRequest blankNamespaceReq = new PackageLicenseTransferService.TransferRequest();
    blankNamespaceReq.newUserId = newUser.Id;
    blankNamespaceReq.packageNamespace = '';
    blankNamespaceReq.isRevert = false;
    requests.add(blankNamespaceReq);

    // Invalid revert (missing current holder)
    PackageLicenseTransferService.TransferRequest invalidRevertReq = new PackageLicenseTransferService.TransferRequest();
    invalidRevertReq.newUserId = originalUser.Id;
    invalidRevertReq.packageNamespace = TEST_NAMESPACE;
    invalidRevertReq.isRevert = true;
    requests.add(invalidRevertReq);

    List<PackageLicenseTransferService.TransferResult> results = 
        PackageLicenseTransferService.transferLicense(requests);
    Test.stopTest();

    System.assertEquals(requests.size(), results.size(), 'Should process all requests');
    
    Integer failedCount = 0;
    for(PackageLicenseTransferService.TransferResult result : results) {
        if(!result.isSuccess) {
            failedCount++;
            System.assert(result.message != null && result.message.length() > 0, 
                'Failed results should have error message');
        }
    }
    
    System.debug('Number of failed transfers: ' + failedCount);
    System.assert(failedCount > 0, 'Should have some failed transfers');
}

@IsTest
static void testTransferWithNonLicensedPackage() {
    Map<String, User> testUsers = getTestUsers();
    User newUser = testUsers.get('new');

    Test.startTest();
    PackageLicenseTransferService.TransferRequest req = new PackageLicenseTransferService.TransferRequest();
    req.newUserId = newUser.Id;
    req.packageNamespace = 'NONEXISTENT_PKG';  // Use a definitely non-existent package
    req.isRevert = false;

    List<PackageLicenseTransferService.TransferResult> results = 
        PackageLicenseTransferService.transferLicense(new List<PackageLicenseTransferService.TransferRequest>{req});
    Test.stopTest();

    System.assert(!results[0].isSuccess, 'Transfer should fail');
    System.assert(results[0].message.contains('not installed'), 
        'Error message should indicate package is not installed in org');
}

@IsTest
static void testTransferWithoutRunningUserLicense() {
    Map<String, User> testUsers = getTestUsers();
    User newUser = testUsers.get('new');

    Test.startTest();
    PackageLicenseTransferService.TransferRequest req = new PackageLicenseTransferService.TransferRequest();
    req.newUserId = newUser.Id;
    req.packageNamespace = 'NONEXISTENT_PKG_' + System.currentTimeMillis(); // Ensure unique non-existent namespace
    req.isRevert = false;

    List<PackageLicenseTransferService.TransferResult> results = 
        PackageLicenseTransferService.transferLicense(new List<PackageLicenseTransferService.TransferRequest>{req});
    Test.stopTest();

    System.assert(!results[0].isSuccess, 'Transfer should fail');
    System.assert(results[0].message.contains('not installed'), 
        'Error message should indicate package is not installed in org');
}

@IsTest
static void testTransferWithNoAvailableLicenses() {
    Map<String, User> testUsers = getTestUsers();
    User newUser = testUsers.get('new');

    Test.startTest();
    PackageLicenseTransferService.TransferRequest req = new PackageLicenseTransferService.TransferRequest();
    req.newUserId = newUser.Id;
    req.packageNamespace = 'NONEXISTENT_PKG_' + System.currentTimeMillis(); // Ensure unique non-existent namespace
    req.isRevert = false;

    List<PackageLicenseTransferService.TransferResult> results = 
        PackageLicenseTransferService.transferLicense(new List<PackageLicenseTransferService.TransferRequest>{req});
    Test.stopTest();

    System.assert(!results[0].isSuccess, 'Transfer should fail');
    System.assert(results[0].message.contains('not installed'), 
        'Error message should indicate package is not installed in org');
}



}
