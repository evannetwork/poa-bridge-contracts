# poa-bridge-contracts (with evan.network native-to-native adjustments)

## Next Version
### Features
- update `TicketVendorInterface`
  + remove responsibilities for ticket validity
    * remove `consumeTicket`
    * remove `setMinValue`, `getMinValue`
  + use `eveWeiPerEther` for price related info (read as "EVE Wei" per "(mainnet) Ether")

### Fixes
### Deprecations

