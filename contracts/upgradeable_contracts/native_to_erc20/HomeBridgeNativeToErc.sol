pragma solidity 0.4.24;
import "../../libraries/SafeMath.sol";
import "../../libraries/Message.sol";
import "../BasicBridge.sol";
import "../../upgradeability/EternalStorage.sol";
import "../BasicHomeBridge.sol";
import "../../external/TicketVendorInterface.sol";

contract Sacrifice {
    constructor(address _recipient) public payable {
        selfdestruct(_recipient);
    }
}

contract HomeBridgeNativeToErc is EternalStorage, BasicBridge, BasicHomeBridge {

    function initialize (
        address _validatorContract,
        uint256 _dailyLimit,
        uint256 _maxPerTx,
        uint256 _minPerTx,
        uint256 _homeGasPrice,
        uint256 _requiredBlockConfirmations,
        address _ticketVendor
    ) public
      returns(bool)
    {
        require(!isInitialized());
        require(_validatorContract != address(0));
        require(_homeGasPrice > 0);
        require(_requiredBlockConfirmations > 0);
        require(_minPerTx > 0 && _maxPerTx > _minPerTx && _dailyLimit > _maxPerTx);
        require(_ticketVendor != address(0));
        addressStorage[keccak256(abi.encodePacked("validatorContract"))] = _validatorContract;
        uintStorage[keccak256(abi.encodePacked("deployedAtBlock"))] = block.number;
        uintStorage[keccak256(abi.encodePacked("dailyLimit"))] = _dailyLimit;
        uintStorage[keccak256(abi.encodePacked("maxPerTx"))] = _maxPerTx;
        uintStorage[keccak256(abi.encodePacked("minPerTx"))] = _minPerTx;
        uintStorage[keccak256(abi.encodePacked("gasPrice"))] = _homeGasPrice;
        uintStorage[keccak256(abi.encodePacked("requiredBlockConfirmations"))] = _requiredBlockConfirmations;
        addressStorage[keccak256(abi.encodePacked("ticketVendor"))] = _ticketVendor;
        setInitialize(true);
        return isInitialized();
    }

    function () public payable {
        // replaced with transferFunds, that requires a valid ticketId in ticket vendor contract
        throw;
    }

    function transferFunds(uint256 ticketId) public payable {
        require(msg.value > 0);
        require(withinLimit(msg.value));
        setTotalSpentPerDay(getCurrentDay(), totalSpentPerDay(getCurrentDay()).add(msg.value));
        TicketVendorInterface tv = TicketVendorInterface(addressStorage[keccak256(abi.encodePacked("ticketVendor"))]);
        // address owner, uint256 price, uint256 issued, uint256 value
        var ( ticketOwner, ticketPrice, , ticketValue ) = tv.getTicketInfo(ticketId);
        require(msg.sender == ticketOwner);
        require(msg.value == ticketValue);
        // TODO: more ticket valid checks, like being new enough, etc.
        uint256 foreignFunds = ticketValue * ticketPrice / (1 ether);
        bytes32 transferKey = keccak256(abi.encodePacked(bytes32(msg.sender), bytes32(foreignFunds)));
        uintStorage[keccak256(abi.encodePacked("ticketTransferKeyToId", transferKey))] = ticketId;
        emit UserRequestForSignature(msg.sender, foreignFunds);
    }

    function setTicketVendor(address ticketVendor) public onlyOwner returns(uint256) {
        addressStorage[keccak256(abi.encodePacked("ticketVendor"))] = ticketVendor;
    }

    function getBridgeMode() public pure returns(bytes4 _data) {
        return bytes4(keccak256(abi.encodePacked("native-to-erc-core")));
    }

    function getTicketId(address sender, uint256 value) public view returns(uint256) {
        bytes32 transferKey = keccak256(abi.encodePacked(bytes32(sender), bytes32(value)));
        return uintStorage[keccak256(abi.encodePacked("ticketTransferKeyToId", transferKey))];
    }

    function getTicketVendor() public view returns(address) {
        return addressStorage[keccak256(abi.encodePacked("ticketVendor"))];
    }

    function onExecuteAffirmation(address _recipient, uint256 _value) internal returns(bool) {
        if (!_recipient.send(_value)) {
            (new Sacrifice).value(_value)(_recipient);
        }
        return true;
    }
}
