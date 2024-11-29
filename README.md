# Package License Transfer Service for Salesforce

## Overview
The PackageLicenseTransferService is a Salesforce Apex class that helps manage and transfer installed package licenses between users. It's particularly useful when you need to:
- Automatically reassign licenses from inactive or infrequent users
- Transfer licenses to new team members
- Revert license assignments to previous holders
- Manage licenses for packages like SDOC, CONGA, or other installed packages

## Features
- 🔄 Automatic transfer of package licenses
- 👤 Smart selection of source users based on last login date
- ↩️ Revert capability to restore previous license assignments
- ⚡ Invocable from Flow Builder
- 🛡️ Built-in validation and error handling
- 📦 Support for any installed package

## How It Works

### Basic License Transfer
The service finds the user with the oldest last login date who currently has the specified package license and transfers it to the designated new user.

### Revert Operation
You can revert a previous transfer by specifying the current license holder and the user who should get their license back.

## Usage in Flow Builder

### New Transfer
1. Add an Action element to your flow
2. Select "Transfer Package License"
3. Configure the following required fields:
   - New User ID
   - Package Namespace (e.g., "SDOC")
   - Is Revert Operation (set to false)

### Revert Transfer
1. Add an Action element to your flow
2. Select "Transfer Package License"
3. Configure the following fields:
   - New User ID (the user getting their license back)
   - Current Holder ID (the user who currently has the license)
   - Package Namespace
   - Is Revert Operation (set to true)

## Input Parameters

### TransferRequest Class
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| newUserId | Id | Yes | ID of the user who should receive the license |
| currentHolderId | Id | No* | ID of the current license holder (required for revert operations) |
| isRevert | Boolean | No | Indicates if this is a revert operation |
| packageNamespace | String | Yes | Namespace of the package (e.g., "SDOC") |

*Required only for revert operations

## Return Values

### TransferResult Class
| Parameter | Type | Description |
|-----------|------|-------------|
| previousUserId | Id | ID of the user who previously held the license |
| isSuccess | Boolean | Indicates if the transfer was successful |
| message | String | Detailed result or error message |
| packageNamespace | String | Namespace of the package involved |

## Error Handling
The service includes comprehensive error handling for common scenarios:
- Invalid package namespace
- Inactive users
- Missing required parameters
- Users already having licenses
- Database operation failures

## Installation
Deploy the following components to your Salesforce org:
1. PackageLicenseTransferService.cls
2. PackageLicenseTransferServiceTest.cls

## Best Practices
- Always test the service with a small subset of users first
- Keep track of license transfers for audit purposes
- Consider implementing additional security measures in your flow
- Monitor debug logs for detailed operation information

## Limitations
- Cannot create new licenses, only transfer existing ones
- Requires appropriate system permissions
- Package must be installed in the org
- Users must be active to receive licenses

## Contributing
Feel free to submit issues and enhancement requests!

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)