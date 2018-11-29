pragma solidity 0.4.24;
import "../../libraries/SafeMath.sol";
import "../../libraries/Message.sol";
import "../BasicBridge.sol";
import "../../upgradeability/EternalStorage.sol";
import "../../IBlockReward.sol";
import "../BasicHomeBridge.sol";


contract HomeBridgeNativeToNative is EternalStorage, BasicBridge, BasicHomeBridge {

    function initialize (
        address _validatorContract,
        uint256 _dailyLimit,
        uint256 _maxPerTx,
        uint256 _minPerTx,
        uint256 _homeGasPrice,
        uint256 _requiredBlockConfirmations,
        address _blockReward

    ) public returns(bool)
    {
        require(!isInitialized());
        require(_validatorContract != address(0) && isContract(_validatorContract));
        require(_requiredBlockConfirmations > 0);
        require(_minPerTx > 0 && _maxPerTx > _minPerTx && _dailyLimit > _maxPerTx);
        require(_blockReward == address(0) || isContract(_blockReward));
        addressStorage[keccak256(abi.encodePacked("validatorContract"))] = _validatorContract;
        uintStorage[keccak256(abi.encodePacked("deployedAtBlock"))] = block.number;
        uintStorage[keccak256(abi.encodePacked("dailyLimit"))] = _dailyLimit;
        uintStorage[keccak256(abi.encodePacked("maxPerTx"))] = _maxPerTx;
        uintStorage[keccak256(abi.encodePacked("minPerTx"))] = _minPerTx;
        uintStorage[keccak256(abi.encodePacked("gasPrice"))] = _homeGasPrice;
        uintStorage[keccak256(abi.encodePacked("requiredBlockConfirmations"))] = _requiredBlockConfirmations;
        addressStorage[keccak256(abi.encodePacked("blockRewardContract"))] = _blockReward;
        setInitialize(true);

        return isInitialized();
    }

    function getBridgeMode() public pure returns(bytes4 _data) {
        return bytes4(keccak256(abi.encodePacked("native-to-native-core")));
    }

    function blockRewardContract() public view returns(IBlockReward) {
        return IBlockReward(addressStorage[keccak256(abi.encodePacked("blockRewardContract"))]);
    }

    function totalBurntCoins() public view returns(uint256) {
        return uintStorage[keccak256(abi.encodePacked("totalBurntCoins"))];
    }

    function setBlockRewardContract(address _blockReward) public onlyOwner {
        require(_blockReward != address(0) && isContract(_blockReward));
        addressStorage[keccak256(abi.encodePacked("blockRewardContract"))] = _blockReward;
    }

    function onExecuteAffirmation(address _recipient, uint256 _value) internal returns(bool) {
        IBlockReward blockReward = blockRewardContract();
        if (blockReward != address(0)) {
            blockReward.addExtraReceiver(_value, _recipient);
        } else {
            _recipient.transfer(_value);
        }
        return true;
    }

    function setTotalBurntCoins(uint256 _amount) internal {
        uintStorage[keccak256(abi.encodePacked("totalBurntCoins"))] = _amount;
    }
}
