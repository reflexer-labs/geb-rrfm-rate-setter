pragma solidity 0.6.7;

abstract contract OracleRelayerLike {
    function redemptionPrice() virtual external returns (uint256);
    function modifyParameters(bytes32,uint256) virtual external;
}

contract SetterRelayer {
    // --- Auth ---
    mapping (address => uint) public authorizedAccounts;
    function addAuthorization(address account) virtual external isAuthorized {
        authorizedAccounts[account] = 1;
        emit AddAuthorization(account);
    }
    function removeAuthorization(address account) virtual external isAuthorized {
        authorizedAccounts[account] = 0;
        emit RemoveAuthorization(account);
    }
    modifier isAuthorized {
        require(authorizedAccounts[msg.sender] == 1, "SetterRelayer/account-not-authorized");
        _;
    }

    // --- Events ---
    event AddAuthorization(address account);
    event RemoveAuthorization(address account);
    event ModifyParameters(
      bytes32 parameter,
      address addr
    );
    event RelayRate(address setter, uint256 redemptionRate);

    // --- Variables ---
    address           public setter;

    OracleRelayerLike public oracleRelayer;

    constructor(address setter_, address oracleRelayer_) public {
        require(setter_ != address(0), "SetterRelayer/null-setter");
        setter        = setter_;
        oracleRelayer = OracleRelayer(oracleRelayer_);
        emit ModifyParameters(
          "setter",
          setter
        );
    }

    // --- Administration ---
    /*
    * @notice Change the setter address
    * @param parameter Must be "setter"
    * @param addr The new setter address
    */
    function modifyParameters(bytes32 parameter, address addr) external isAuthorized {
        require(addr != address(0), "SetterRelayer/null-addr");
        if (parameter == "setter") {
            setter = addr;
        }
        else revert("SetterRelayer/modify-unrecognized-param");
    }

    // --- Core Logic ---
    /*
    * @notice Relay a new redemption rate to the OracleRelayer
    * @param redemptionRate The new redemption rate to relay
    */
    function relayRate(uint256 redemptionRate) external {
        require(setter == msg.sender, "SetterRelayer/invalid-caller");
        oracleRelayer.redemptionPrice();
        oracleRelayer.modifyParameters("redemptionRate", redemptionRate);
        emit RelayRate(setter, redemptionRate);
    }
}
