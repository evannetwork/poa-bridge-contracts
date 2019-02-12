pragma solidity 0.4.24;
import "../../libraries/SafeMath.sol";
import "../BasicBridge.sol";
import "../BasicForeignBridge.sol";
import "../../external/TicketVendorInterface.sol";

contract ForeignBridgeNativeToNative is  BasicBridge, BasicForeignBridge {

    /// Event created on money withdraw.
    event UserRequestForAffirmation(address recipient, uint256 value);

    function initialize(
        address _validatorContract,
        uint256 _dailyLimit,
        uint256 _maxPerTx,
        uint256 _minPerTx,
        uint256 _foreignGasPrice,
        uint256 _requiredBlockConfirmations,
        address _ticketVendor,
        uint256 _ticketMaxAge,
        address _fundStorage
    ) public returns(bool) {
        require(!isInitialized());
        require(_validatorContract != address(0) && isContract(_validatorContract));
        require(_minPerTx > 0 && _maxPerTx > _minPerTx && _dailyLimit > _maxPerTx);
        require(_foreignGasPrice > 0);
        addressStorage[keccak256(abi.encodePacked("validatorContract"))] = _validatorContract;
        uintStorage[keccak256(abi.encodePacked("dailyLimit"))] = _dailyLimit;
        uintStorage[keccak256(abi.encodePacked("deployedAtBlock"))] = block.number;
        uintStorage[keccak256(abi.encodePacked("maxPerTx"))] = _maxPerTx;
        uintStorage[keccak256(abi.encodePacked("minPerTx"))] = _minPerTx;
        uintStorage[keccak256(abi.encodePacked("gasPrice"))] = _foreignGasPrice;
        uintStorage[keccak256(abi.encodePacked("requiredBlockConfirmations"))] = _requiredBlockConfirmations;
        addressStorage[keccak256(abi.encodePacked("ticketVendor"))] = _ticketVendor;
        uintStorage[keccak256(abi.encodePacked("ticketMaxAge"))] = _ticketMaxAge;
        addressStorage[keccak256(abi.encodePacked("fundStorage"))] = _fundStorage;
        setInitialize(true);
        return isInitialized();
    }

    function () public payable {
        // replaced with transferFunds, that requires a valid ticketId in ticket vendor contract
        throw;
    }

    function transferFunds(uint256 ticketId, address targetAccount) public payable {
        require(address(targetAccount) != address(0));
        require(msg.value > 0);
        require(withinLimit(msg.value));
        setTotalSpentPerDay(getCurrentDay(), totalSpentPerDay(getCurrentDay()).add(msg.value));
        TicketVendorInterface tv = TicketVendorInterface(addressStorage[keccak256(abi.encodePacked("ticketVendor"))]);
        var ( ticketOwner, ticketPrice, ticketIssued, ticketValue ) = tv.getTicketInfo(ticketId);
        require(msg.sender == ticketOwner);
        require(msg.value == ticketValue);
        require(ticketIssued + getTicketMaxAge() >= now);
        uint256 foreignFunds = ticketValue * ticketPrice / (1 ether);
        setTicketProcessed(ticketId);
        // send to target account
        address to = fundStorage();
        if (to != address(0)) {
            to.transfer(msg.value);
        }
        emit UserRequestForAffirmation(targetAccount, foreignFunds);
    }

    function setTicketMaxAge(uint ticketMaxAge) public onlyOwner {
        uintStorage[keccak256(abi.encodePacked("ticketMaxAge"))] = ticketMaxAge;
    }

    function setTicketVendor(address ticketVendor) public onlyOwner {
        addressStorage[keccak256(abi.encodePacked("ticketVendor"))] = ticketVendor;
    }

    function getBridgeMode() public pure returns(bytes4 _data) {
        return bytes4(keccak256(abi.encodePacked("native-to-native-core")));
    }

    function getTicketMaxAge() public view returns(uint256) {
        return uintStorage[keccak256(abi.encodePacked("ticketMaxAge"))];
    }

    function getTicketProcessed(uint256 ticketId) public view returns(bool) {
        bytes32 key = keccak256(abi.encodePacked("ticketProcessed", getTicketVendor(), ticketId));
        return boolStorage[key];
    }

    function getTicketVendor() public view returns(address) {
        return addressStorage[keccak256(abi.encodePacked("ticketVendor"))];
    }

    function setTicketProcessed(uint256 ticketId) internal {
        bytes32 key = keccak256(abi.encodePacked("ticketProcessed", getTicketVendor(), ticketId));
        boolStorage[key] = true;
    }

}
