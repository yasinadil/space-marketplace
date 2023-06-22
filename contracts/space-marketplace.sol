// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

contract SpaceMarketPlace {
    address public owner;
    address public receiver;
    uint256 public receiverBal;
    uint256 public constant NUM_SPACES = 100;
    uint256 public constant MIN_SUBSCRIBE = 0; // minimum balance as percent of highest offer required to defend a space
    uint256 public constant SUBSCRIBE_RATE = 10; // percent of highest offer from each space sent to receiver each per year

    IERC20 public immutable weth;

    struct Space {
        uint256 spaceNo;
        bool exists;
        address owner;
        uint256 balance;
        uint256 highestOffer;
        address highestOfferer;
        string spaceUri;
        uint256 subscTime;
        uint256 subscBurn;
        uint256 subscOffer;
    }

    mapping(uint256 => Space) public spaces;

    event NewOffer(
        uint256 indexed spaceId,
        address indexed offerer,
        uint256 amount
    );

    // WETH address on Goerli = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6
    constructor(IERC20 _weth) {
        owner = msg.sender;
        receiver = owner;
        weth = _weth;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    modifier spaceExists(uint256 spaceId) {
        require(spaces[spaceId].exists, "This space does not exist");
        _;
    }

    modifier canDeposit(uint256 spaceId) {
        require(
            spaces[spaceId].exists && spaces[spaceId].owner == msg.sender,
            "You cannot deposit against this space"
        );
        _;
    }

    modifier canOffer(uint256 spaceId) {
        require(
            spaces[spaceId].exists && spaces[spaceId].owner != msg.sender,
            "You cannot offer on this space"
        );
        _;
    }

    function setReceiver(address _receiver) public onlyOwner {
        receiver = _receiver;
    }

    function transferContractOwner(address newContractOwner) public onlyOwner {
        owner = newContractOwner;
    }

    function deposit(uint256 spaceId, uint256 amount)
        public
        canDeposit(spaceId)
    {
        require(weth.balanceOf(msg.sender) >= amount, "Insufficient balance");
        uint256 allowance = weth.allowance(msg.sender, address(this));
        require(allowance >= amount, "Check the token allowance");
        require(amount >= 10 gwei, "min balance is 10 GWEI");

        spaces[spaceId].balance += amount;
        updateSubscriptionFlows(spaceId);

        weth.transferFrom(msg.sender, address(this), amount);
    }

    //create timestamp for static balance amount and update flowrate in spaces[_spaceId]
    function updateSubscriptionFlows(uint256 spaceId) internal {
        if (
            spaces[spaceId].balance <=
            spaces[spaceId].subscBurn *
                (block.timestamp - spaces[spaceId].subscTime)
        ) {
            receiverBal += spaces[spaceId].balance;
        } else {
            receiverBal +=
                spaces[spaceId].subscBurn *
                (block.timestamp - spaces[spaceId].subscTime);
        }
        uint256 flowRate = (spaces[spaceId].highestOffer * SUBSCRIBE_RATE) /
            (100 * 365 days);
        spaces[spaceId].balance = getRemainingBalance(spaceId);
        spaces[spaceId].subscTime = block.timestamp;
        spaces[spaceId].subscBurn = flowRate;
    }

    //function that calculates remaining balance in a given space
    function getRemainingBalance(uint256 spaceId)
        public
        view
        returns (uint256 remainingCommit)
    {
        if (
            spaces[spaceId].balance <=
            spaces[spaceId].subscBurn *
                (block.timestamp - spaces[spaceId].subscTime)
        ) {
            remainingCommit = 0;
        } else {
            remainingCommit =
                spaces[spaceId].balance -
                spaces[spaceId].subscBurn *
                (block.timestamp - spaces[spaceId].subscTime);
        }
        return remainingCommit;
    }

    function withdraw(uint256 spaceId, uint256 amount) public {
        require(
            spaces[spaceId].owner == msg.sender,
            "you are not the current space owner"
        );
        require(
            amount <= getRemainingBalance(spaceId),
            "not enough depositted weth left"
        );
        spaces[spaceId].balance = getRemainingBalance(spaceId) - amount;

        updateSubscriptionFlows(spaceId);
        weth.transfer(spaces[spaceId].owner, amount);
    }

    function claimSpace(uint256 spaceId, uint256 amount) public {
        require(spaceId > 0 && spaceId <= NUM_SPACES, "Invalid SpaceId");
        require(
            !spaces[spaceId].exists && spaces[spaceId].owner == address(0),
            "space has already been claimed"
        );
        require(weth.balanceOf(msg.sender) >= amount, "Insufficient balance");
        uint256 allowance = weth.allowance(msg.sender, address(this));
        require(allowance >= amount, "Check the token allowance");

        spaces[spaceId].exists = true;
        spaces[spaceId].spaceNo = spaceId;
        spaces[spaceId].balance += amount;
        spaces[spaceId].owner = msg.sender;
        updateSubscriptionFlows(spaceId);

        weth.transferFrom(msg.sender, address(this), amount);
    }

    function offer(
        uint256 spaceId,
        uint256 amount,
        uint256 subscOffer
    ) external spaceExists(spaceId) {
        Space storage space = spaces[spaceId];
        uint256 refund = 0;
        uint256 allowance = weth.allowance(msg.sender, address(this));
        require(allowance >= amount + subscOffer, "Check the token allowance");
        require(
            space.owner != msg.sender,
            "Owner cannot offer on their own space"
        );
        require(
            amount > space.highestOffer,
            "Offer must be greater than current highest offer"
        );

        // Refund previous highest offerer
        if (space.highestOfferer != address(0)) {
            refund = space.highestOffer + space.subscOffer;
        }

        // Update offering state
        space.highestOfferer = msg.sender;
        space.highestOffer = amount;
        space.subscOffer = subscOffer;

        updateSubscriptionFlows(spaceId);
        if (refund > 0) {
            weth.transfer(space.highestOfferer, refund);
        }
        require(
            weth.balanceOf(msg.sender) >= amount + subscOffer,
            "Insufficient balance"
        );
        require(
            weth.transferFrom(msg.sender, address(this), amount + subscOffer),
            "Transfer failed"
        );

        emit NewOffer(spaceId, msg.sender, amount);
    }

    function acceptOffer(uint256 spaceId) public spaceExists(spaceId) {
        if (
            getRemainingBalance(spaceId) <=
            (spaces[spaceId].highestOffer * MIN_SUBSCRIBE) / 100
        ) {
            _acceptOffer(spaceId, spaces[spaceId].subscOffer);
        } else {
            require(
                msg.sender == spaces[spaceId].owner,
                "The owner has successfully defended ownership with sufficient balance"
            );
            _acceptOffer(spaceId, spaces[spaceId].subscOffer);
        }
    }

    function _acceptOffer(uint256 spaceId, uint256 newDepositAmount) internal {
        Space storage space = spaces[spaceId];
        require(space.highestOfferer != address(0), "No offer to accept");
        //send offer to previous owner
        uint256 allowance = weth.allowance(msg.sender, address(this));
        require(allowance >= newDepositAmount, "Check the token allowance");
        require(
            weth.transfer(space.owner, space.highestOffer),
            "Offer refund transfer failed"
        );
        // refund balance to the previous owner
        weth.transfer(space.owner, space.balance);
        // change ownership to highest offerer
        space.owner = space.highestOfferer;
        // reset highest offer to 0
        space.highestOfferer = address(0);
        space.highestOffer = 0;
        space.balance = newDepositAmount;
        // transfer new balance amount to contract
        weth.transferFrom(msg.sender, address(this), newDepositAmount);
        updateSubscriptionFlows(spaceId);
    }

    function retractOffer(uint256 spaceId) public {
        require(
            spaces[spaceId].highestOfferer == msg.sender,
            "you are not the current highest offerer"
        );
        weth.transfer(
            spaces[spaceId].highestOfferer,
            spaces[spaceId].highestOffer + spaces[spaceId].subscOffer
        );
        spaces[spaceId].highestOfferer = address(0);
        spaces[spaceId].highestOffer = 0;
        spaces[spaceId].subscOffer = 0;
        updateSubscriptionFlows(spaceId);
    }

    function transferSpace(uint256 spaceId, address newOwner) public {
        require(spaces[spaceId].owner == msg.sender, "you are not the owner!");
        spaces[spaceId].owner = newOwner;
        if (spaces[spaceId].highestOfferer == msg.sender) {
            retractOffer(spaceId);
        }
    }

    function setSpaceUri(
        uint256 spaceId,
        uint256 nftTokenId,
        address nftContractAddress
    ) public canDeposit(spaceId) {
        IERC721 nftContract = IERC721(nftContractAddress);
        IERC721Metadata uNftContract = IERC721Metadata(nftContractAddress);
        require(
            nftContract.ownerOf(nftTokenId) == msg.sender,
            "Caller does not own this NFT"
        );
        spaces[spaceId].spaceUri = uNftContract.tokenURI(nftTokenId);
    }

    function getNftUri(uint256 _spaceId) public view returns (string memory) {
        return spaces[_spaceId].spaceUri;
    }

    function updateRevenue() public {
        for (uint256 i = 1; i <= NUM_SPACES; i++) {
            updateSubscriptionFlows(i);
        }
    }

    function claimRevenue() public onlyOwner {
        weth.transfer(receiver, receiverBal);
    }

    function getSubscriptionRevenue()
        public
        view
        returns (uint256 subscriptionRevenue)
    {
        subscriptionRevenue = receiverBal;
        return subscriptionRevenue;
    }

    //off-chain function - not to be called onchain
    function getAllClaimedSpaces() public view returns (Space[] memory) {
        Space[] memory _spaces = new Space[](NUM_SPACES);
        uint256 index = 0;
        for (uint256 i = 1; i <= NUM_SPACES; i++) {
            if (spaces[i].exists) {
                _spaces[index] = spaces[i];
                index++;
            }
        }
        return _spaces;
    }

    //off-chain function - not to be called onchain
    function getCurrentRemainingBalances()
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory _balances = new uint256[](NUM_SPACES);
        uint256 index = 0;
        for (uint256 i = 1; i <= NUM_SPACES; i++) {

            uint256 remainingCommit = 0;
            if (
                spaces[i].balance <=
                spaces[i].subscBurn *
                    (block.timestamp - spaces[i].subscTime)
            ) {
                remainingCommit = 0;
            } else {
                remainingCommit =
                    spaces[i].balance -
                    spaces[i].subscBurn *
                    (block.timestamp - spaces[i].subscTime);
            }
            _balances[index] = remainingCommit;
            index++;
        }
        return _balances;
    }
}