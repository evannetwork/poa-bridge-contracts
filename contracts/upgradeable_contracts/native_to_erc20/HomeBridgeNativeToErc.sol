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
        address _ticketVendor,
        uint256 ticketMaxAge
    ) public
      returns(bool)
    {
        require(!isInitialized());
        require(_validatorContract != address(0) && isContract(_validatorContract));
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
        uintStorage[keccak256(abi.encodePacked("ticketMaxAge"))] = ticketMaxAge;
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
        var ( ticketOwner, ticketPrice, ticketIssued, ticketValue ) = tv.getTicketInfo(ticketId);
        require(msg.sender == ticketOwner);
        require(msg.value == ticketValue);
        require(ticketIssued + getTicketMaxAge() >= now);
        uint256 foreignFunds = ticketValue * ticketPrice / (1 ether);
        setTicketProcessed(ticketId);
        emit UserRequestForSignature(msg.sender, foreignFunds);
    }

    function setTicketMaxAge(uint ticketMaxAge) public onlyOwner {
        uintStorage[keccak256(abi.encodePacked("ticketMaxAge"))] = ticketMaxAge;
    }

    function setTicketVendor(address ticketVendor) public onlyOwner {
        addressStorage[keccak256(abi.encodePacked("ticketVendor"))] = ticketVendor;
    }

    function getBridgeMode() public pure returns(bytes4 _data) {
        return bytes4(keccak256(abi.encodePacked("native-to-erc-core")));
    }

    function getTicketMaxAge() public view returns(uint256) {
        return uintStorage[keccak256(abi.encodePacked("ticketMaxAge"))];
    }

    function getTicketProcessed(uint256 ticketId) public view returns(bool) {
        return boolStorage[keccak256(abi.encodePacked("ticketProcessed", ticketId))];
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

    function setTicketProcessed(uint256 ticketId) internal {
        boolStorage[keccak256(abi.encodePacked("ticketProcessed", ticketId))] = true;
    }
}
