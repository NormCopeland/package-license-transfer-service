public without sharing class PackageLicenseTransferService {
    
    public class TransferResult {
        @InvocableVariable(label='Previous License Holder ID' description='ID of the user who previously held the license' required=true)
        public Id previousUserId;
        
        @InvocableVariable(label='Success' description='Indicates if the transfer was successful' required=true)
        public Boolean isSuccess;
        
        @InvocableVariable(label='Message' description='Result message' required=true)
        public String message;
        
        @InvocableVariable(label='Package Namespace' description='Namespace of the package involved in the transfer' required=true)
        public String packageNamespace;
    }
    
    public class TransferRequest {
        @InvocableVariable(label='New User ID' description='ID of the user who should receive the license' required=true)
        public Id newUserId;
        
        @InvocableVariable(label='Current Holder ID' description='ID of the current license holder (only needed for revert operations)' required=false)
        public Id currentHolderId;
        
        @InvocableVariable(label='Is Revert Operation' description='Indicates if this is a revert operation' required=false)
        public Boolean isRevert;
        
        @InvocableVariable(label='Package Namespace' description='Namespace of the package (e.g., SDOC, CONGA, etc.)' required=true)
        public String packageNamespace;
    }
    
    @InvocableMethod(label='Transfer Package License' description='Transfers a package license between users or reverts a previous transfer')
    public static List<TransferResult> transferLicense(List<TransferRequest> requests) {
        List<TransferResult> results = new List<TransferResult>();
        
        if (requests == null) {
            return results;
        }
        
        for (TransferRequest req : requests) {
            TransferResult result = new TransferResult();
            result.isSuccess = false;
            result.packageNamespace = req.packageNamespace;
            
            try {
                // Existing validation for blank namespace
                if (String.isBlank(req.packageNamespace)) {
                    result.message = 'Package namespace is required';
                    results.add(result);
                    continue;
                }
                
                // Check if package exists and requires license management
                List<PackageLicense> packageLicenses = [
                    SELECT Id, AllowedLicenses, UsedLicenses 
                    FROM PackageLicense 
                    WHERE NamespacePrefix = :req.packageNamespace 
                    LIMIT 1
                ];
                
                if (packageLicenses.isEmpty()) {
                    result.message = 'Package with namespace ' + req.packageNamespace + ' is not installed in this org';
                    results.add(result);
                    continue;
                }
                
                // Check if package requires license management
                PackageLicense pkg = packageLicenses[0];
                if (pkg.AllowedLicenses == null || pkg.AllowedLicenses == 0) {
                    result.message = 'Package ' + req.packageNamespace + ' does not require license management';
                    results.add(result);
                    continue;
                }
                
                // Check if running user has the license
                List<UserPackageLicense> runningUserLicense = [
                    SELECT Id 
                    FROM UserPackageLicense 
                    WHERE PackageLicense.NamespacePrefix = :req.packageNamespace
                    AND UserId = :UserInfo.getUserId()
                    LIMIT 1
                ];
                
                if (runningUserLicense.isEmpty()) {
                    result.message = 'Running user does not have permission to manage ' + req.packageNamespace + ' licenses';
                    results.add(result);
                    continue;
                }
                
                // Existing validation for new user
                List<User> newUser = [
                    SELECT Id, IsActive 
                    FROM User 
                    WHERE Id = :req.newUserId 
                    LIMIT 1
                ];
                
                if (newUser.isEmpty()) {
                    result.message = 'New user does not exist';
                    results.add(result);
                    continue;
                }
                
                if (!newUser[0].IsActive) {
                    result.message = 'New user is not active';
                    results.add(result);
                    continue;
                }
                
                // Check if new user already has the license
                List<UserPackageLicense> existingNewUserLicense = [
                    SELECT Id 
                    FROM UserPackageLicense 
                    WHERE PackageLicense.NamespacePrefix = :req.packageNamespace
                    AND UserId = :req.newUserId
                    LIMIT 1
                ];
                
                if (!existingNewUserLicense.isEmpty()) {
                    result.message = 'New user already has the license for package ' + req.packageNamespace;
                    results.add(result);
                    continue;
                }
                
                // Check if all licenses are used
                if (pkg.UsedLicenses >= pkg.AllowedLicenses) {
                    result.message = 'All available licenses for ' + req.packageNamespace + ' are currently in use';
                    results.add(result);
                    continue;
                }
    
                // Rest of the existing code for handling revert or new transfer...
                if (req.isRevert != null && req.isRevert) {
                    if (req.currentHolderId == null) {
                        result.message = 'Current holder ID is required for revert operations';
                        results.add(result);
                        continue;
                    }
                    result = handleRevertTransfer(req.currentHolderId, req.newUserId, req.packageNamespace);
                } else {
                    result = handleNewTransfer(req.newUserId, req.packageNamespace);
                }
                
            } catch (DmlException e) {
                result.isSuccess = false;
                result.message = 'Database error: ' + e.getDmlMessage(0);
            } catch (Exception e) {
                result.isSuccess = false;
                result.message = 'Unexpected error: ' + e.getMessage();
            }
            
            results.add(result);
        }
        
        return results;
    }
    
    
    private static TransferResult handleNewTransfer(Id newUserId, String packageNamespace) {
        TransferResult result = new TransferResult();
        result.packageNamespace = packageNamespace;
        
        // Find total number of licenses
        AggregateResult[] totalLicenses = [
            SELECT COUNT(Id) licenseCount
            FROM UserPackageLicense 
            WHERE PackageLicense.NamespacePrefix = :packageNamespace
        ];
        
        Integer licenseCount = (Integer)totalLicenses[0].get('licenseCount');
        
        if (licenseCount == 0) {
            result.isSuccess = false;
            result.message = 'No licenses found for package ' + packageNamespace;
            return result;
        }
        
        // Find user with oldest last login who has the license
        List<User> usersWithLicense = [
            SELECT Id, LastLoginDate, Username
            FROM User
            WHERE Id IN (
                SELECT UserId 
                FROM UserPackageLicense 
                WHERE PackageLicense.NamespacePrefix = :packageNamespace
            )
            AND IsActive = true
            AND Id != :newUserId
            ORDER BY LastLoginDate ASC NULLS FIRST
            LIMIT 1
        ];
        
        if (usersWithLicense.isEmpty()) {
            result.isSuccess = false;
            result.message = 'No eligible users found with the ' + packageNamespace + ' license. All licenses may be assigned to inactive users or the target user.';
            return result;
        }
        
        Id sourceUserId = usersWithLicense[0].Id;
        
        // Get the package license record
        List<UserPackageLicense> existingLicenses = [
            SELECT Id, PackageLicenseId 
            FROM UserPackageLicense 
            WHERE PackageLicense.NamespacePrefix = :packageNamespace
            AND UserId = :sourceUserId
            LIMIT 1
        ];
        
        if (existingLicenses.isEmpty()) {
            result.isSuccess = false;
            result.message = 'No package license found for transfer from user: ' + usersWithLicense[0].Username;
            return result;
        }
        
        Savepoint sp = Database.setSavepoint();
        
        try {
            // Perform the transfer
            UserPackageLicense existingLicense = existingLicenses[0];
            Id packageLicenseId = existingLicense.PackageLicenseId;
            
            delete existingLicense;
            
            UserPackageLicense newLicense = new UserPackageLicense(
                UserId = newUserId,
                PackageLicenseId = packageLicenseId
            );
            insert newLicense;
            
            result.isSuccess = true;
            result.previousUserId = sourceUserId;
            result.message = packageNamespace + ' license successfully transferred from user: ' + usersWithLicense[0].Username;
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
        
        return result;
    }
    
    private static TransferResult handleRevertTransfer(Id currentHolderId, Id originalUserId, String packageNamespace) {
        TransferResult result = new TransferResult();
        result.packageNamespace = packageNamespace;
        
        // Get the current license assignment
        List<UserPackageLicense> currentLicenses = [
            SELECT Id, PackageLicenseId, UserId, User.Username 
            FROM UserPackageLicense 
            WHERE PackageLicense.NamespacePrefix = :packageNamespace
            AND UserId = :currentHolderId
            LIMIT 1
        ];
        
        if (currentLicenses.isEmpty()) {
            result.isSuccess = false;
            result.message = 'No ' + packageNamespace + ' license found for current holder. They may not have the license anymore.';
            return result;
        }
        
        Savepoint sp = Database.setSavepoint();
        
        try {
            UserPackageLicense currentLicense = currentLicenses[0];
            Id packageLicenseId = currentLicense.PackageLicenseId;
            
            // Perform the revert
            delete currentLicense;
            
            UserPackageLicense revertedLicense = new UserPackageLicense(
                UserId = originalUserId,
                PackageLicenseId = packageLicenseId
            );
            insert revertedLicense;
            
            result.isSuccess = true;
            result.previousUserId = currentHolderId;
            result.message = packageNamespace + ' license successfully reverted from ' + currentLicense.User.Username;
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
        
        return result;
    }
}
