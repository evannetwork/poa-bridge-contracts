# poa-bridge-contracts (with evan.network native-to-native adjustments)

## Next Version
### Features
- update `TicketVendorInterface`
  + remove responsibilities for ticket validity
    * remove `consumeTicket`
    * remove `setMinValue`, `getMinValue`
  + use `eveWeiPerEther` for price related info (read as "EVE Wei" per "(mainnet) Ether")
- add max age for tickets in foreign bridge
- update balance handling functions
  + move functions for handling balance to `BasicBridge`
  + rename `charge()` to `chargeFunds()` to keep names consistent
- add ticket processing for home bridge
  + tickets are processed by ticket vendor and ticket id
  + the same ticket id from the same ticket vendor contract cannot be used a second time
- add `targetAccount` argument to `transferFunds` in home bridge to allow sending funds to a specific account in the foreign chain

### Fixes
### Deprecations

